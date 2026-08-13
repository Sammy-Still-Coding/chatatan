import 'package:flutter/material.dart';

import 'db_helper.dart';

class LibraryAttachment {
  const LibraryAttachment({
    required this.title,
    required this.storagePath,
    required this.mimeType,
    required this.contentType,
  });

  final String title;
  final String storagePath;
  final String mimeType;
  final String contentType;

  String get locator => 'library://$storagePath';
  bool get isImage => mimeType.startsWith('image/') || contentType == 'IMAGE';
}

Future<LibraryAttachment?> pickLibraryAttachment(BuildContext context) =>
    showModalBottomSheet<LibraryAttachment>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _LibraryAttachmentPicker(),
    );

class _LibraryAttachmentPicker extends StatefulWidget {
  const _LibraryAttachmentPicker();

  @override
  State<_LibraryAttachmentPicker> createState() =>
      _LibraryAttachmentPickerState();
}

class _LibraryAttachmentPickerState extends State<_LibraryAttachmentPicker> {
  final _db = DbHelper();
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _items = _db.getLibraryItems();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() =>
      setState(() => _items = _db.getLibraryItems(search: _search.text));

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .68,
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.folder_copy_outlined, color: Color(0xFF6C63FF)),
            title: Text(
              'Pilih dari Library',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('File tidak diunggah ulang'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              onChanged: (_) => _reload(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari file Library',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _items,
              builder: (_, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty)
                  return const Center(
                    child: Text('Belum ada file di Library.'),
                  );
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final item = items[index];
                    final rawFile = item['files'];
                    final file = rawFile is Map
                        ? Map<String, dynamic>.from(rawFile)
                        : <String, dynamic>{};
                    final path = file['storage_path']?.toString() ?? '';
                    final title =
                        file['original_name']?.toString() ??
                        item['title']?.toString() ??
                        'File';
                    if (path.isEmpty) return const SizedBox.shrink();
                    final mime = file['mime_type']?.toString() ?? '';
                    final contentType = item['content_type']?.toString() ?? '';
                    return ListTile(
                      leading: Icon(
                        mime.startsWith('image/')
                            ? Icons.image_outlined
                            : Icons.description_outlined,
                      ),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        contentType.isEmpty ? 'File Library' : contentType,
                      ),
                      onTap: () => Navigator.pop(
                        context,
                        LibraryAttachment(
                          title: title,
                          storagePath: path,
                          mimeType: mime,
                          contentType: contentType,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
