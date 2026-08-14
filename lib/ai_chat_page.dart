import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'attachment_preview.dart';
import 'library_attachment_picker.dart';
import 'db_helper.dart';
import 'chatatan_theme.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _client = Supabase.instance.client;
  final _db = DbHelper();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  LibraryAttachment? _attachment;
  Map<String, dynamic>? _tokenStatus;
  String _model = 'standard';
  int? _conversationId;
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _refreshTokenStatus();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final conversationId = await _db.getOrCreateLatestAiConversation();
      final saved = await _db.getAiMessages(conversationId);
      if (!mounted) return;
      setState(() {
        _conversationId = conversationId;
        _messages
          ..clear()
          ..addAll(
            saved.map(
              (message) => {
                'role': message['sender_type']?.toString() == 'AI'
                    ? 'assistant'
                    : 'user',
                'content': message['content']?.toString() ?? '',
                'file': message['attachment_name']?.toString() ?? '',
                'url': message['attachment_locator']?.toString() ?? '',
              },
            ),
          );
      });
      // A reopened chat should land on the newest message, just like a chat
      // that has remained open.  Wait until ListView has received its items.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } catch (_) {
      // The AI can still be used if the history SQL/RLS migration is pending.
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
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
      if (_conversationId != null) {
        await _db.saveAiMessage(
          conversationId: _conversationId!,
          senderType: 'USER',
          content: sent['content'].toString(),
          messageType: attachment == null ? 'TEXT' : 'FILE',
          attachmentName: fileName,
          attachmentLocator: attachment?.locator,
        );
      }
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
      final answer = data['answer']?.toString() ?? 'AI tidak memberi jawaban.';
      setState(() => _messages.add({'role': 'assistant', 'content': answer}));
      if (_conversationId != null) {
        await _db.saveAiMessage(
          conversationId: _conversationId!,
          senderType: 'AI',
          content: answer,
        );
      }
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
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(title: const Text('ChaTatan AI')),
    body: ChatatanAmbientBackground(
      child: Column(
        children: [
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
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
                            maxWidth:
                                MediaQuery.sizeOf(context).width *
                                (mine ? .78 : .92),
                          ),
                          decoration: BoxDecoration(
                            gradient: mine
                                ? const LinearGradient(
                                    colors: [
                                      ChatatanColors.primary,
                                      ChatatanColors.secondary,
                                    ],
                                  )
                                : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? [
                                            const Color(0xFF202842),
                                            const Color(0xFF151B30),
                                          ]
                                        : [
                                            Colors.white.withValues(alpha: .84),
                                            const Color(
                                              0xFFDDE7FF,
                                            ).withValues(alpha: .52),
                                          ],
                                  ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(
                                      0xFF9CA9D8,
                                    ).withValues(alpha: .22)
                                  : Colors.white.withValues(alpha: .84),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF6678BE,
                                ).withValues(alpha: .09),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (url.isNotEmpty) ...[
                                AttachmentPreviewTile(
                                  url: url,
                                  name: file,
                                  dark:
                                      mine ||
                                      Theme.of(context).brightness ==
                                          Brightness.dark,
                                ),
                                const SizedBox(height: 8),
                              ],
                              mine
                                  ? Text(
                                      message['content']?.toString() ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    )
                                  : MarkdownBody(
                                      data:
                                          message['content']?.toString() ?? '',
                                      selectable: true,
                                      styleSheet:
                                          MarkdownStyleSheet.fromTheme(
                                            Theme.of(context),
                                          ).copyWith(
                                            p: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
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
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: ChatatanGlass(
                radius: 24,
                opacity: .76,
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTokenBar(),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Pilih dari Library',
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
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Kirim',
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Color(0xFF6C63FF),
                          ),
                          onPressed: _send,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildTokenBar() {
    final balance = _tokenStatus?['balance']?.toString() ?? '--';
    final capacity = _tokenStatus?['weekly_capacity']?.toString() ?? '100';
    final streak = _tokenStatus?['streak']?.toString() ?? '0';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          const Icon(Icons.token_rounded, color: Color(0xFF6C63FF), size: 19),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$balance / $capacity token · isi ulang mingguan',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF202842)
                    : const Color(0xFFECE9FF).withValues(alpha: .82),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF9CA9D8).withValues(alpha: .22)
                      : Colors.white.withValues(alpha: .8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _model == 'advanced' ? 'Pro' : 'Standard',
                    style: const TextStyle(
                      color: ChatatanColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.expand_more_rounded,
                    color: ChatatanColors.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          if (int.tryParse(streak) != null && int.parse(streak) < 100)
            const SizedBox(width: 2),
        ],
      ),
    );
  }
}
