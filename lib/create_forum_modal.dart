import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'db_helper.dart';
import 'chatatan_theme.dart';

class CreateForumModal extends StatefulWidget {
  // BENAR
  const CreateForumModal({super.key});

  @override
  State<CreateForumModal> createState() => _CreateForumModalState();
}

class _CreateForumModalState extends State<CreateForumModal> {
  final _supabase = Supabase.instance.client;
  final _dbHelper = DbHelper();

  // Controller hanya untuk Kategori (Free Text) dan Isi Postingan
  final _categoryController = TextEditingController();
  final _contentController = TextEditingController();

  List<Map<String, dynamic>> _selectedLibraryItems = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _categoryController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickFromLibrary() async {
    try {
      final items = await _dbHelper.getLibraryItems();
      if (!mounted) return;
      final selectedIds = _selectedLibraryItems
          .map((item) => item['id']?.toString())
          .whereType<String>()
          .toSet();
      final result = await showChatatanGlassSheet<List<Map<String, dynamic>>>(
        context: context,
        builder: (sheetContext) {
          final selected = <String>{...selectedIds};
          return StatefulBuilder(
            builder: (context, setSheetState) => SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .7,
                child: Column(
                  children: [
                    const ChatatanSheetHandle(),
                    const ListTile(
                      title: Text('Pilih file dari Library'),
                      subtitle: Text('File akan masuk antrian kurasi Forum'),
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(
                              child: Text('Library kamu belum memiliki file.'),
                            )
                          : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final id = item['id'].toString();
                                final files = item['files'];
                                final fileName = files is Map
                                    ? files['original_name']?.toString()
                                    : null;
                                return CheckboxListTile(
                                  value: selected.contains(id),
                                  title: Text(
                                    item['title']?.toString() ?? 'Tanpa judul',
                                  ),
                                  subtitle: Text(fileName ?? 'Item tanpa file'),
                                  enabled: fileName != null,
                                  onChanged: fileName == null
                                      ? null
                                      : (checked) => setSheetState(() {
                                          if (checked == true) {
                                            selected.add(id);
                                          } else {
                                            selected.remove(id);
                                          }
                                        }),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(
                            sheetContext,
                            items
                                .where(
                                  (item) =>
                                      selected.contains(item['id'].toString()),
                                )
                                .toList(),
                          ),
                          child: const Text('Gunakan file terpilih'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (result != null && mounted) {
        setState(() => _selectedLibraryItems = result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka Library: ' + e.toString())),
        );
      }
    }
  }

  // Fungsi otomatis untuk mencari/membuat ID kategori dari teks input user
  Future<int?> _getOrCreateCategoryId(String categoryName) async {
    final formattedName = categoryName.replaceAll('#', '').trim();
    final slug = formattedName.toLowerCase().replaceAll(' ', '-');

    if (formattedName.isEmpty) return null;

    try {
      // 1. Cek apakah kategori sudah ada di database
      final existing = await _supabase
          .from('forum_categories')
          .select('id')
          .eq('slug', slug)
          .maybeSingle();

      if (existing != null) {
        return int.parse(existing['id'].toString());
      }

      // 2. Jika belum ada, buat kategori baru secara otomatis
      final newCategory = await _supabase
          .from('forum_categories')
          .insert({'name': formattedName, 'slug': slug, 'is_active': true})
          .select('id')
          .single();

      return int.parse(newCategory['id'].toString());
    } catch (e) {
      debugPrint('Error getOrCreateCategory: $e');
      return null;
    }
  }

  Future<void> _submitPost() async {
    final rawCategory = _categoryController.text.trim();
    final content = _contentController.text.trim();
    final userId = _supabase.auth.currentUser?.id;

    // 1. Validasi Isi Post
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi postingan tidak boleh kosong')),
      );
      return;
    }

    // 2. Validasi Kategori Wajib Diisi (Mencegah error NOT NULL di DB)
    if (rawCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori / Hashtag wajib diisi')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Cari ID kategori yang sudah ada ATAU buat kategori baru
      final categoryId = await _getOrCreateCategoryId(rawCategory);

      if (categoryId == null) {
        throw Exception('Gagal mendapatkan ID Kategori');
      }

      final titleSnippet = content.length > 50
          ? '${content.substring(0, 50)}...'
          : content;

      // Insert ke forum_posts (categoryId dipastikan TIDAK NULL)
      final post = await _supabase
          .from('forum_posts')
          .insert({
            'user_id': userId,
            'category_id': categoryId,
            'title': titleSnippet,
            'content': content,
          })
          .select('id')
          .single();

      final postId = int.parse(post['id'].toString());
      await _dbHelper.attachLibraryItemsToForum(
        postId: postId,
        libraryItemIds: _selectedLibraryItems
            .map((item) => int.tryParse(item['id'].toString()))
            .whereType<int>()
            .toList(),
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membuat postingan: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 0,
        left: 16,
        right: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ChatatanSheetHandle(),
            // Header Modal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Buat Postingan Baru',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Input Kategori / Hashtag Bebas (Text Field)
            TextField(
              controller: _categoryController,
              decoration: InputDecoration(
                hintText: 'Kategori / Hashtag (misal: CS, Math, General)',
                prefixText: '# ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Input Isi Postingan (Twitter Style - Multi Line)
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Apa yang ingin kamu bagikan atau tanyakan?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            // Hanya file yang sudah ada di Library dapat dibagikan ke Forum.
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _pickFromLibrary,
                  icon: const Icon(Icons.library_books_outlined),
                  label: const Text('Pilih dari Library'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (_selectedLibraryItems.isNotEmpty)
                  Text(
                    _selectedLibraryItems.length.toString() + ' file dipilih',
                  ),
              ],
            ),
            if (_selectedLibraryItems.isNotEmpty)
              ..._selectedLibraryItems.asMap().entries.map(
                (entry) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(
                    entry.value['title']?.toString() ?? 'Tanpa judul',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: 'Hapus file',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(
                      () => _selectedLibraryItems.removeAt(entry.key),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Tombol Post
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Post',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
