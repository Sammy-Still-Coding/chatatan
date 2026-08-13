import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'db_helper.dart';

bool isImageAttachment(String value) {
  final clean = value.toLowerCase().split('?').first;
  return clean.endsWith('.jpg') ||
      clean.endsWith('.jpeg') ||
      clean.endsWith('.png') ||
      clean.endsWith('.gif') ||
      clean.endsWith('.webp');
}

bool isPdfAttachment(String value) =>
    value.toLowerCase().split('?').first.endsWith('.pdf');

String attachmentExtension(String value) {
  final clean = value.toLowerCase().split('?').first;
  final dot = clean.lastIndexOf('.');
  return dot == -1 ? '' : clean.substring(dot + 1);
}

bool isTextExtractableAttachment(String value) => const {
  'pdf',
  'docx',
  'xlsx',
  'pptx',
  'txt',
  'md',
  'csv',
  'json',
  'xml',
}.contains(attachmentExtension(value));

String attachmentName(String url, {String? fallback}) {
  if (fallback != null && fallback.trim().isNotEmpty) return fallback.trim();
  final raw = url.split('?').first.split('/').last;
  return Uri.decodeComponent(raw.replaceFirst(RegExp(r'^\d+_'), ''));
}

Future<String> resolveAttachmentUrl(String locator) async {
  if (!locator.startsWith('library://')) return locator;
  return DbHelper().getLibraryFileUrl(locator.substring('library://'.length));
}

/// Membaca format materi kuliah yang umum. DOC/XLS lama tetap dibuka pada
/// aplikasi perangkat karena format biner lamanya tidak dapat diekstrak aman.
Future<String> extractDocumentText(String locator) async {
  final url = await resolveAttachmentUrl(locator);
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
    throw Exception('file tidak dapat diambil (HTTP ${response.statusCode})');
  }
  final ext = attachmentExtension(locator);
  if (const {'txt', 'md', 'csv', 'json', 'xml'}.contains(ext)) {
    return utf8.decode(response.bodyBytes, allowMalformed: true).trim();
  }
  if (ext == 'pdf') {
    final document = PdfDocument(inputBytes: response.bodyBytes);
    final text = PdfTextExtractor(document).extractText().trim();
    document.dispose();
    return text;
  }
  if (!const {'docx', 'xlsx', 'pptx'}.contains(ext)) {
    throw Exception('Format .$ext belum dapat diekstrak');
  }
  final archive = ZipDecoder().decodeBytes(response.bodyBytes);
  String read(String name) {
    final file = archive.findFile(name);
    if (file == null) return '';
    final bytes = file.readBytes();
    return bytes == null ? '' : utf8.decode(bytes, allowMalformed: true);
  }

  if (ext == 'docx') return _xmlToText(read('word/document.xml'));
  if (ext == 'pptx') {
    final slides =
        archive.files
            .where(
              (file) =>
                  RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(file.name),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return slides
        .map(
          (file) => _xmlToText(
            utf8.decode(file.readBytes() ?? [], allowMalformed: true),
          ),
        )
        .join('\n\n');
  }
  final shared = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
      .allMatches(read('xl/sharedStrings.xml'))
      .map((match) => _xmlToText(match.group(1) ?? ''))
      .toList();
  final sheets = archive.files.where(
    (file) => RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(file.name),
  );
  return sheets
      .map((sheet) {
        final xml = utf8.decode(sheet.readBytes() ?? [], allowMalformed: true);
        return RegExp(
              r'<c[^>]*?(?:t="s")?[^>]*>.*?<v>(.*?)</v>.*?</c>',
              dotAll: true,
            )
            .allMatches(xml)
            .map((match) {
              final value = _xmlToText(match.group(1) ?? '');
              final index = int.tryParse(value);
              return index != null && index >= 0 && index < shared.length
                  ? shared[index]
                  : value;
            })
            .join(' · ');
      })
      .join('\n\n');
}

String _xmlToText(String xml) => xml
    .replaceAll(
      RegExp(r'</w:p>|</a:p>|</row>|</p>', caseSensitive: false),
      '\n',
    )
    .replaceAll(RegExp(r'</w:tc>|</c>', caseSensitive: false), '\t')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .trim();

Future<void> openAttachmentPreview(
  BuildContext context, {
  required String url,
  String? name,
}) async {
  if (url.trim().isEmpty) return;
  final title = attachmentName(url, fallback: name);
  try {
    final resolvedUrl = await resolveAttachmentUrl(url);
    if (!context.mounted) return;
    if (isImageAttachment(url)) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ImagePreviewPage(url: resolvedUrl, title: title),
        ),
      );
      return;
    }
    if (isPdfAttachment(url)) {
      final response = await http.get(Uri.parse(resolvedUrl));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty)
        throw Exception('HTTP ${response.statusCode}');
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PdfPreviewPage(
            bytes: response.bodyBytes,
            title: title,
            externalUrl: resolvedUrl,
          ),
        ),
      );
      return;
    }
    if (isTextExtractableAttachment(url)) {
      final text = await extractDocumentText(url);
      if (text.trim().isEmpty)
        throw Exception('Tidak ada teks yang dapat ditampilkan');
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _DocumentTextPreviewPage(
            text: text,
            title: title,
            externalUrl: resolvedUrl,
          ),
        ),
      );
      return;
    }
    final opened = await launchUrl(
      Uri.parse(resolvedUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dokumen tidak dapat dibuka di perangkat ini.'),
        ),
      );
    }
  } catch (error) {
    if (context.mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuka lampiran: $error')));
  }
}

class AttachmentPreviewTile extends StatefulWidget {
  const AttachmentPreviewTile({
    super.key,
    required this.url,
    this.name,
    this.dark = false,
  });
  final String url;
  final String? name;
  final bool dark;

  @override
  State<AttachmentPreviewTile> createState() => _AttachmentPreviewTileState();
}

class _AttachmentPreviewTileState extends State<AttachmentPreviewTile> {
  late Future<String> _resolved = resolveAttachmentUrl(widget.url);

  @override
  void didUpdateWidget(covariant AttachmentPreviewTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url)
      _resolved = resolveAttachmentUrl(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.dark ? Colors.white : const Color(0xFF6C63FF);
    if (isImageAttachment(widget.url)) {
      return InkWell(
        onTap: () =>
            openAttachmentPreview(context, url: widget.url, name: widget.name),
        child: FutureBuilder<String>(
          future: _resolved,
          builder: (_, snapshot) => ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: snapshot.hasData
                ? Image.network(
                    snapshot.data!,
                    width: 210,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _failedImage(color),
                  )
                : const SizedBox(
                    width: 210,
                    height: 90,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: () =>
          openAttachmentPreview(context, url: widget.url, name: widget.name),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPdfAttachment(widget.url)
                ? Icons.picture_as_pdf_outlined
                : Icons.description_outlined,
            color: color,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              attachmentName(widget.url, fallback: widget.name),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.dark ? Colors.white : Colors.black87,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _failedImage(Color color) => SizedBox(
    width: 210,
    height: 90,
    child: Center(child: Icon(Icons.broken_image_outlined, color: color)),
  );
}

class _ImagePreviewPage extends StatelessWidget {
  const _ImagePreviewPage({required this.url, required this.title});
  final String url;
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    backgroundColor: Colors.black,
    body: Center(
      child: InteractiveViewer(
        minScale: .5,
        maxScale: 4,
        child: Image.network(
          url,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, color: Colors.white, size: 48),
        ),
      ),
    ),
  );
}

class _PdfPreviewPage extends StatelessWidget {
  const _PdfPreviewPage({
    required this.bytes,
    required this.title,
    required this.externalUrl,
  });
  final Uint8List bytes;
  final String title;
  final String externalUrl;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Buka untuk edit',
          icon: const Icon(Icons.open_in_new),
          onPressed: () => launchUrl(
            Uri.parse(externalUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    ),
    body: SfPdfViewer.memory(bytes),
  );
}

class _DocumentTextPreviewPage extends StatelessWidget {
  const _DocumentTextPreviewPage({
    required this.text,
    required this.title,
    required this.externalUrl,
  });
  final String text;
  final String title;
  final String externalUrl;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Buka untuk edit',
          icon: const Icon(Icons.open_in_new),
          onPressed: () => launchUrl(
            Uri.parse(externalUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    ),
    body: SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: const TextStyle(fontSize: 15, height: 1.45)),
      ),
    ),
  );
}
