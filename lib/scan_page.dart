import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'db_helper.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _db = DbHelper();
  final _client = Supabase.instance.client;
  XFile? _image;
  String _result = '';
  bool _loading = false;

  Future<void> _pick(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (image != null && mounted)
      setState(() {
        _image = image;
        _result = '';
      });
  }

  Future<void> _scan() async {
    final image = _image;
    if (image == null || _loading) return;
    setState(() => _loading = true);
    try {
      final bytes = await image.readAsBytes();
      final response = await _client.functions.invoke(
        'scan-note',
        body: {'image_url': 'data:image/jpeg;base64,${base64Encode(bytes)}'},
      );
      final data = response.data;
      if (data is! Map || data['error'] != null)
        throw Exception(
          data is Map ? data['error'] : 'Respons scan tidak valid',
        );
      if (!mounted) return;
      setState(
        () => _result = _cleanOcrText(
          data['text']?.toString() ?? 'Tidak ada teks terbaca.',
        ),
      );
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

  String _cleanOcrText(String raw) => raw
      .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
      .replaceAll(RegExp(r'</?think>', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^The user wants[\s\S]*?(?=\n\n|\n[^\s])', caseSensitive: false), '')
      .trim();

  Future<void> _saveToLibrary() async {
    final image = _image;
    if (image == null || _result.isEmpty) return;
    final name = TextEditingController(
      text: 'Scan ${DateTime.now().toLocal().toString().substring(0, 16)}',
    );
    var format = 'TXT';
    final choice = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setModalState) => AlertDialog(
          title: const Text('Simpan hasil scan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nama file'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ['TXT', 'PDF', 'IMAGE']
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item),
                        selected: format == item,
                        onSelected: (_) => setModalState(() => format = item),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'name': name.text.trim(),
                'format': format,
              }),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    if (choice == null || choice['name']!.isEmpty) return;
    try {
      final title = choice['name']!;
      final selected = choice['format']!;
      if (selected == 'IMAGE') {
        await _db.uploadLibraryFile(
          bytes: await image.readAsBytes(),
          fileName: '$title.jpg',
          title: title,
          sourceType: 'AI_SCAN',
          contentType: 'IMAGE',
        );
      } else if (selected == 'PDF') {
        final doc = PdfDocument();
        final page = doc.pages.add();
        page.graphics.drawString(
          _result,
          PdfStandardFont(PdfFontFamily.helvetica, 12),
          bounds: const Rect.fromLTWH(30, 30, 520, 760),
          format: PdfStringFormat(lineAlignment: PdfVerticalAlignment.top),
        );
        final bytes = Uint8List.fromList(await doc.save());
        doc.dispose();
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

  @override
  Widget build(BuildContext context) {
    final preview = _image == null
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
        : Image.network(
            _image!.path,
            height: 270,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(
              height: 120,
              child: Center(child: Icon(Icons.image_outlined)),
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
                  onPressed: _loading ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Kamera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeri'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _image == null || _loading ? null : _scan,
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
            label: const Text('Scan gambar'),
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
            SelectionArea(
              child: Text(_result, style: const TextStyle(height: 1.45)),
            ),
          ],
        ],
      ),
    );
  }
}
