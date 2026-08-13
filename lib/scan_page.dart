import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'db_helper.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _db = DbHelper();
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  final List<String> _ocrPages = [];
  String _result = '';
  bool _loading = false;

  Future<void> _pickCamera() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (image != null && mounted) {
      setState(() {
        _images.add(image);
        _result = '';
        _ocrPages.clear();
      });
    }
  }

  Future<void> _pickGallery() async {
    final images = await _picker.pickMultiImage(
      imageQuality: 75,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (images.isNotEmpty && mounted) {
      setState(() {
        _images.addAll(images);
        _result = '';
        _ocrPages.clear();
      });
    }
  }

  Future<void> _cropImage(int index) async {
    if (_loading || index < 0 || index >= _images.length) return;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: _images[index].path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (cropped == null || !mounted) return;
      setState(() {
        _images[index] = XFile(cropped.path, name: _images[index].name);
        _result = '';
        _ocrPages.clear();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memotong gambar: $error')));
    }
  }

  Future<void> _scan() async {
    if (_images.isEmpty || _loading) return;
    setState(() => _loading = true);
    try {
      if (kIsWeb) {
        throw UnsupportedError(
          'OCR lokal hanya tersedia di aplikasi Android/iOS. Jalankan APK untuk memakai AI Scan.',
        );
      }
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final pages = <String>[];
        for (var index = 0; index < _images.length; index++) {
          final input = InputImage.fromFilePath(_images[index].path);
          final recognized = await recognizer.processImage(input);
          // ML Kit puts visual lines in a block. Joining a block's lines makes
          // normal documents read as paragraphs instead of one word per line.
          final text = recognized.blocks
              .map(
                (block) => block.lines
                    .map((line) => line.text.trim())
                    .where((line) => line.isNotEmpty)
                    .join(' '),
              )
              .where((block) => block.isNotEmpty)
              .join('\n\n')
              .trim();
          pages.add(text);
        }
        if (pages.every((text) => text.isEmpty)) {
          throw Exception('Tidak ada teks yang dapat dibaca dari gambar.');
        }
        if (!mounted) return;
        setState(() {
          _ocrPages
            ..clear()
            ..addAll(pages);
          _result = pages
              .asMap()
              .entries
              .map(
                (entry) => pages.length == 1
                    ? entry.value
                    : '--- Foto ${entry.key + 1} ---\n${entry.value.isEmpty ? '(Tidak ada teks terbaca)' : entry.value}',
              )
              .join('\n\n');
        });
      } finally {
        await recognizer.close();
      }
      if (!mounted) return;
      final streak = await _db.claimLearningStreak();
      if (mounted && streak['claimed'] == true)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Streak ${streak['streak']} hari · +${streak['points']} poin',
            ),
          ),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scan gagal: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveToLibrary() async {
    if (_images.isEmpty || _result.isEmpty) return;
    final choice = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ScanSaveEditor(
          initialName:
              'Scan ${DateTime.now().toLocal().toString().substring(0, 16)}',
        ),
      ),
    );
    if (!mounted || choice == null || choice['name']!.isEmpty) return;
    try {
      final title = choice['name']!;
      final selected = choice['format']!;
      if (selected == 'IMAGE') {
        for (var index = 0; index < _images.length; index++) {
          final image = _images[index];
          final suffix = _images.length == 1 ? '' : ' ${index + 1}';
          final extension = _extension(image);
          await _db.uploadLibraryFile(
            bytes: await image.readAsBytes(),
            fileName: '$title$suffix.$extension',
            title: '$title$suffix',
            sourceType: 'AI_SCAN',
            contentType: 'IMAGE',
          );
        }
      } else if (selected == 'PDF') {
        final bytes = _createOcrPdf(
          _ocrPages.isEmpty ? [_result] : _ocrPages,
          title,
        );
        await _db.uploadLibraryFile(
          bytes: bytes,
          fileName: '$title.pdf',
          title: title,
          sourceType: 'AI_SCAN',
          contentType: 'PDF',
        );
      } else {
        await _db.uploadLibraryFile(
          bytes: Uint8List.fromList(utf8.encode(_result)),
          fileName: '$title.txt',
          title: title,
          sourceType: 'AI_SCAN',
          contentType: 'TEXT',
        );
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hasil scan disimpan ke Library.')),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $error')));
    }
  }

  Uint8List _createOcrPdf(List<String> sourcePages, String documentTitle) {
    final document = PdfDocument();
    final normalFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final titleFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      15,
      style: PdfFontStyle.bold,
    );
    final chunks = <String>[];
    for (var photoIndex = 0; photoIndex < sourcePages.length; photoIndex++) {
      final lines = <String>[];
      for (final rawLine in sourcePages[photoIndex].split('\n')) {
        var remaining = rawLine.trimRight();
        if (remaining.isEmpty) {
          lines.add('');
          continue;
        }
        while (remaining.length > 86) {
          var breakAt = remaining.lastIndexOf(' ', 86);
          if (breakAt < 1) breakAt = 86;
          lines.add(remaining.substring(0, breakAt));
          remaining = remaining.substring(breakAt).trimLeft();
        }
        lines.add(remaining);
      }
      for (var start = 0; start < lines.length; start += 43) {
        final end = (start + 43).clamp(0, lines.length);
        chunks.add(lines.sublist(start, end).join('\n'));
      }
    }
    for (var index = 0; index < chunks.length; index++) {
      final page = document.pages.add();
      final size = page.getClientSize();
      page.graphics.drawString(
        documentTitle,
        titleFont,
        bounds: Rect.fromLTWH(32, 30, size.width - 64, 24),
      );
      page.graphics.drawString(
        chunks[index],
        normalFont,
        bounds: Rect.fromLTWH(32, 66, size.width - 64, size.height - 100),
      );
      page.graphics.drawString(
        'Halaman ${index + 1} dari ${chunks.length}',
        PdfStandardFont(PdfFontFamily.helvetica, 8),
        bounds: Rect.fromLTWH(32, size.height - 24, size.width - 64, 12),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
    }
    final bytes = Uint8List.fromList(document.saveSync());
    document.dispose();
    return bytes;
  }

  String _extension(XFile image) {
    final parts = image.name.split('.');
    final extension = parts.length > 1 ? parts.last.toLowerCase() : 'jpg';
    return ['jpg', 'jpeg', 'png', 'webp'].contains(extension)
        ? extension
        : 'jpg';
  }

  @override
  Widget build(BuildContext context) {
    final preview = _images.isEmpty
        ? Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.document_scanner_outlined,
                  size: 60,
                  color: Colors.deepPurple,
                ),
                SizedBox(height: 12),
                Text('Ambil gambar catatan atau dokumen'),
              ],
            ),
          )
        : SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final image = _images[index];
                return Stack(
                  key: ValueKey(image.path),
                  children: [
                    FutureBuilder<Uint8List>(
                      future: image.readAsBytes(),
                      builder: (_, snapshot) => Container(
                        width: 160,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: snapshot.hasData
                            ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                            : const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Hapus gambar',
                          color: Colors.white,
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: _loading
                              ? null
                              : () => setState(() {
                                  _images.removeAt(index);
                                  _result = '';
                                  _ocrPages.clear();
                                }),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Material(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _loading ? null : () => _cropImage(index),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.crop_outlined,
                                  size: 17,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Crop',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
    return Scaffold(
      appBar: AppBar(title: const Text('AI Scan · Gratis')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: preview),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _pickCamera,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Kamera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _pickGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeri'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _images.isEmpty || _loading ? null : _scan,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text('Scan ${_images.length} gambar'),
          ),
          if (_result.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Teks hasil scan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: _result)).then(
                        (_) => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Teks disalin.')),
                        ),
                      ),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Salin teks'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _saveToLibrary,
                  icon: const Icon(Icons.save_alt_outlined),
                  label: const Text('Simpan ke Library'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_result, style: const TextStyle(height: 1.45)),
          ],
        ],
      ),
    );
  }
}

class ScanSaveEditor extends StatefulWidget {
  const ScanSaveEditor({super.key, required this.initialName});

  final String initialName;

  @override
  State<ScanSaveEditor> createState() => _ScanSaveEditorState();
}

class _ScanSaveEditorState extends State<ScanSaveEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  final FocusNode _focusNode = FocusNode();
  String _format = 'TXT';

  @override
  void dispose() {
    _focusNode.dispose();
    _name.dispose();
    super.dispose();
  }

  void _finish([Map<String, String>? result]) {
    _focusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simpan hasil scan'),
        leading: IconButton(onPressed: _finish, icon: const Icon(Icons.close)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                focusNode: _focusNode,
                decoration: const InputDecoration(
                  labelText: 'Nama file',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Format file'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['TXT', 'PDF', 'IMAGE']
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item),
                        selected: _format == item,
                        onSelected: (_) => setState(() => _format = item),
                      ),
                    )
                    .toList(),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () =>
                    _finish({'name': _name.text.trim(), 'format': _format}),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan ke Library'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
