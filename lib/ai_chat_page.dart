import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'attachment_preview.dart';
import 'library_attachment_picker.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _client = Supabase.instance.client;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  LibraryAttachment? _attachment;
  Map<String, dynamic>? _tokenStatus;
  String _model = 'standard';

  @override
  void initState() {
    super.initState();
    _refreshTokenStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshTokenStatus() async {
    try {
      final result = await _client.rpc('get_ai_token_status');
      if (mounted && result is Map) {
        setState(() => _tokenStatus = Map<String, dynamic>.from(result));
      }
    } catch (_) {
      // Migration mungkin belum dijalankan. Pesan yang jelas akan muncul saat kirim.
    }
  }

  bool get _advancedUnlocked => _tokenStatus?['advanced_unlocked'] == true;
  int get _tokenCost =>
      (_model == 'advanced' ? 10 : 5) * (_attachment == null ? 1 : 2);

  Future<void> _pickAttachment() async {
    final attachment = await pickLibraryAttachment(context);
    if (attachment != null && mounted) setState(() => _attachment = attachment);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _attachment == null) || _loading) return;
    setState(() => _loading = true);
    try {
      final attachment = _attachment;
      final fileName = attachment?.title;
      final fileUrl = attachment == null
          ? null
          : await resolveAttachmentUrl(attachment.locator);
      String? documentText;
      String? pdfImageForAi;
      if (attachment != null && isTextExtractableAttachment(attachment.title)) {
        try {
          documentText = await _extractAttachmentText(attachment.locator);
        } catch (error) {
          if (!isPdfAttachment(attachment.title)) rethrow;
          pdfImageForAi = await _renderPdfFirstPage(fileUrl!);
        }
      }
      final prompt = [
        if (text.isNotEmpty) text,
        if (fileUrl != null) 'Lampiran pengguna: $fileName.',
        if (documentText != null)
          'Teks yang diekstrak dari dokumen (mungkin dipotong):\n$documentText',
        if (pdfImageForAi != null)
          'PDF adalah hasil scan; gambar halaman pertama dikirim untuk dianalisis.',
      ].join('\n\n');
      final sent = <String, dynamic>{
        'role': 'user',
        'content': text.isEmpty ? 'Mengirim lampiran: $fileName' : text,
        'file': fileName ?? '',
        'url': attachment?.locator ?? '',
      };
      setState(() {
        _messages.add(sent);
        _controller.clear();
        _attachment = null;
      });
      final response = await _client.functions.invoke(
        'smart-action',
        body: {
          'message': prompt,
          'model': _model,
          if (fileUrl != null)
            'attachments': [
              {
                'url': pdfImageForAi ?? fileUrl,
                'name': fileName,
                'mime_type': pdfImageForAi == null
                    ? attachment?.mimeType ?? 'application/octet-stream'
                    : 'image/png',
              },
            ],
          'history': _messages
              .map(
                (message) => {
                  'role': message['role'],
                  'content': message['content'],
                },
              )
              .toList(),
        },
      );
      final data = response.data;
      if (data is! Map || data['error'] != null) {
        throw Exception(
          data is Map ? data['error'] : 'Respons AI tidak valid.',
        );
      }
      if (data['token_status'] is Map) {
        _tokenStatus = Map<String, dynamic>.from(data['token_status']);
      }
      setState(
        () => _messages.add({
          'role': 'assistant',
          'content': data['answer']?.toString() ?? 'AI tidak memberi jawaban.',
        }),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('AI gagal menjawab: $e')));
      }
      await _refreshTokenStatus();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
    }
  }

  Future<String> _extractAttachmentText(String locator) async {
    try {
      final text = (await extractDocumentText(locator)).trim();
      if (text.isEmpty) {
        throw Exception(
          'Dokumen tidak memiliki teks yang dapat dibaca. Jika ini hasil scan, kirim screenshot halamannya agar AI dapat membaca.',
        );
      }
      return text.length > 14000 ? text.substring(0, 14000) : text;
    } catch (error) {
      throw Exception('Dokumen belum dapat dibaca: $error');
    }
  }

  Future<String> _renderPdfFirstPage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception('file PDF tidak dapat diambil');
      }
      final document = await pdfx.PdfDocument.openData(response.bodyBytes);
      final page = await document.getPage(1);
      final image = await page.render(
        width: 1200,
        height: (1200 * page.height / page.width),
        format: pdfx.PdfPageImageFormat.png,
      );
      await page.close();
      await document.close();
      if (image == null || image.bytes.isEmpty) {
        throw Exception('halaman pertama tidak dapat dirender');
      }
      return 'data:image/png;base64,${base64Encode(image.bytes)}';
    } catch (error) {
      throw Exception('PDF scan belum dapat dirender untuk AI: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ChaTatan AI')),
    body: Column(
      children: [
        _buildTokenBar(),
        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: Text(
                    'Tanyakan materi, atau kirim gambar/dokumen untuk dibahas.',
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (_, index) {
                    final message = _messages[index];
                    final mine = message['role'] == 'user';
                    final url = message['url']?.toString() ?? '';
                    final file = message['file']?.toString() ?? '';
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .78,
                        ),
                        decoration: BoxDecoration(
                          color: mine ? const Color(0xFF6C63FF) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (url.isNotEmpty) ...[
                              AttachmentPreviewTile(
                                url: url,
                                name: file,
                                dark: mine,
                              ),
                              const SizedBox(height: 8),
                            ],
                            mine
                                ? Text(
                                    message['content']?.toString() ?? '',
                                    style: const TextStyle(color: Colors.white),
                                  )
                                : MarkdownBody(
                                    data: message['content']?.toString() ?? '',
                                    selectable: true,
                                    styleSheet:
                                        MarkdownStyleSheet.fromTheme(
                                          Theme.of(context),
                                        ).copyWith(
                                          p: const TextStyle(
                                            color: Colors.black87,
                                            height: 1.35,
                                          ),
                                          strong: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                  ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_attachment != null)
          ListTile(
            leading: Icon(
              _attachment!.isImage ? Icons.image_outlined : Icons.attach_file,
            ),
            title: Text(_attachment!.title),
            subtitle: Text('Biaya pesan ini: $_tokenCost token'),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _attachment = null),
            ),
          ),
        if (_loading) const LinearProgressIndicator(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _loading ? null : _pickAttachment,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Tanyakan sesuatu...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF6C63FF)),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildTokenBar() {
    final balance = _tokenStatus?['balance']?.toString() ?? '--';
    final capacity = _tokenStatus?['weekly_capacity']?.toString() ?? '100';
    final streak = _tokenStatus?['streak']?.toString() ?? '0';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEAFE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.token_rounded, color: Color(0xFF6C63FF)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$balance / $capacity token · isi ulang mingguan',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Pilih model AI',
            initialValue: _model,
            onSelected: (value) => setState(() => _model = value),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'standard',
                child: Text('Standard · 5 token'),
              ),
              PopupMenuItem(
                value: 'advanced',
                enabled: _advancedUnlocked,
                child: Text(
                  _advancedUnlocked
                      ? 'Pro · 10 token'
                      : 'Pro · streak 100 hari',
                ),
              ),
            ],
            child: Chip(label: Text(_model == 'advanced' ? 'Pro' : 'Standard')),
          ),
          if (int.tryParse(streak) != null && int.parse(streak) < 100)
            const SizedBox(width: 2),
        ],
      ),
    );
  }
}
