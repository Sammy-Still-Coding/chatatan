import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _client = Supabase.instance.client;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _loading = false;
  PlatformFile? _attachment;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    setState(() => _attachment = result.files.single);
  }

  Future<String?> _uploadAttachment() async {
    final file = _attachment;
    if (file?.bytes == null) return null;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Sesi login tidak ditemukan.');
    final path =
        'ai/$userId/${DateTime.now().millisecondsSinceEpoch}_${file!.name}';
    await _client.storage.from('chat-files').uploadBinary(path, file.bytes!);
    return _client.storage.from('chat-files').createSignedUrl(path, 600);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _attachment == null) || _loading) return;
    setState(() => _loading = true);
    try {
      final fileUrl = await _uploadAttachment();
      final fileName = _attachment?.name;
      final extension = _attachment?.extension?.toLowerCase();
      final prompt = [
        if (text.isNotEmpty) text,
        if (fileUrl != null)
          'Lampiran pengguna: $fileName ($fileUrl). Analisis lampiran ini bila formatnya dapat diakses; bila tidak, jelaskan batasannya dan bantu berdasarkan pertanyaan pengguna.',
      ].join('\n\n');
      setState(() {
        _messages.add({
          'role': 'user',
          'content': text.isEmpty ? 'Mengirim lampiran: $fileName' : text,
          'file': fileName ?? '',
        });
        _controller.clear();
        _attachment = null;
      });
      final response = await _client.functions.invoke(
        'smart-action',
        body: {
          'message': prompt,
          if (fileUrl != null)
            'attachments': [
              {
                'url': fileUrl,
                'name': fileName,
                'mime_type':
                    ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)
                    ? 'image/$extension'
                    : 'application/octet-stream',
              },
            ],
          'history': _messages
              .where((message) => message['file']?.isEmpty != false)
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
      setState(
        () => _messages.add({
          'role': 'assistant',
          'content': data['answer']?.toString() ?? 'AI tidak memberi jawaban.',
          'file': '',
        }),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('AI gagal menjawab: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (_scrollController.hasClients)
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ChaTatan AI')),
    body: Column(
      children: [
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
                            if (message['file']?.isNotEmpty == true)
                              const Icon(
                                Icons.attach_file,
                                color: Colors.white,
                              ),
                            Text(
                              message['content'] ?? '',
                              style: TextStyle(
                                color: mine ? Colors.white : Colors.black87,
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
            leading: const Icon(Icons.attach_file),
            title: Text(_attachment!.name),
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
}
