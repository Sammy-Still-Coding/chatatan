import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;
import 'package:file_saver/file_saver.dart';
import 'package:url_launcher/url_launcher.dart';

import 'db_helper.dart';
import 'chatatan_theme.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => LibraryPageState();
}

/// A dedicated route is used instead of an AlertDialog so the text field's
/// Focus scope is disposed by a complete page transition. This avoids the
/// Flutter `_dependents.isEmpty` framework assertion seen on some devices
/// when a folder dialog is closed while the keyboard is active.
class _FolderNamePage extends StatefulWidget {
  const _FolderNamePage({required this.title});

  final String title;

  @override
  State<_FolderNamePage> createState() => _FolderNamePageState();
}

class _FolderNamePageState extends State<_FolderNamePage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama folder',
                  hintText: 'Contoh: Materi Semester 1',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Buat folder'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LibraryPageState extends State<LibraryPage> {
  final DbHelper _dbHelper = DbHelper();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _folders = [];
  String _searchQuery = '';
  int? _selectedFolderId;
  bool _favoritesOnly = false;

  bool _isLoading = true;
  bool _isUploading = false;

  String? _errorMessage;

  final Map<int, String> _imageUrls = {};
  final Map<int, String> _pdfUrls = {};

  @override
  void initState() {
    super.initState();

    _loadLibrary();
  }

  /// Dipanggil oleh navigasi utama saat tab Library kembali dibuka.
  void refreshLibrary() {
    _loadLibrary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredItems {
    final query = _searchQuery.trim().toLowerCase();

    return _items.where((item) {
      final title = item['title']?.toString().toLowerCase() ?? '';
      final description = item['description']?.toString().toLowerCase() ?? '';
      final originalName = _getOriginalFileName(item).toLowerCase();

      final matchesSearch =
          query.isEmpty ||
          title.contains(query) ||
          description.contains(query) ||
          originalName.contains(query);
      // Root Library only contains loose files. Files that have been moved
      // belong in their folder page, rather than appearing as a duplicate in
      // the root list.
      final matchesFolder = _selectedFolderId == null
          ? item['folder_id'] == null
          : item['folder_id'] == _selectedFolderId;
      final matchesFavorite = !_favoritesOnly || item['is_favorite'] == true;

      return matchesSearch && matchesFolder && matchesFavorite;
    }).toList();
  }

  String _getOriginalFileName(Map<String, dynamic> item) {
    final filesData = item['files'];

    if (filesData is Map) {
      return filesData['original_name']?.toString() ?? '';
    }

    if (filesData is List && filesData.isNotEmpty) {
      final firstFile = filesData.first;
      if (firstFile is Map) {
        return firstFile['original_name']?.toString() ?? '';
      }
    }

    return '';
  }

  // ============================================================
  // LOAD LIBRARY
  // ============================================================

  Future<void> _loadLibrary() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      await _dbHelper.ensureDefaultLibraryFolders();
      final results = await Future.wait([
        _dbHelper.getLibraryItems(),
        _dbHelper.getLibraryFolders(),
      ]);
      final items = results[0];
      final folders = results[1];

      final Map<int, String> imageUrls = {};
      final Map<int, String> pdfUrls = {};

      for (final item in items) {
        final contentType = item['content_type']?.toString().toUpperCase();

        // Hanya IMAGE dan PDF
        if (contentType != 'IMAGE' && contentType != 'PDF') {
          continue;
        }

        final itemId = item['id'];

        if (itemId == null) {
          continue;
        }

        final fileData = item['files'];

        if (fileData == null) {
          debugPrint('$contentType: files kosong untuk item $itemId');
          continue;
        }

        String? storagePath;

        // Supabase mengembalikan Map
        if (fileData is Map<String, dynamic>) {
          storagePath = fileData['storage_path']?.toString();
        }

        // Jaga-jaga kalau List
        if (fileData is List && fileData.isNotEmpty && fileData.first is Map) {
          storagePath = fileData.first['storage_path']?.toString();
        }

        if (storagePath == null || storagePath.isEmpty) {
          debugPrint('$contentType: storage_path kosong untuk item $itemId');
          continue;
        }

        try {
          final url = await _dbHelper.getLibraryFileUrl(storagePath);

          debugPrint('========================================');
          debugPrint('PDF/IMAGE CONTENT TYPE: $contentType');
          debugPrint('ITEM ID: $itemId');
          debugPrint('STORAGE PATH: $storagePath');
          debugPrint('SIGNED URL: $url');
          debugPrint('========================================');
          final id = int.parse(itemId.toString());

          if (contentType == 'IMAGE') {
            imageUrls[id] = url;
          } else if (contentType == 'PDF') {
            pdfUrls[id] = url;
          }

          debugPrint('$contentType berhasil mendapatkan URL: $id');
        } catch (e) {
          debugPrint('Gagal membuat URL $contentType: $e');
        }
      }

      if (!mounted) return;

      setState(() {
        _items = List<Map<String, dynamic>>.from(items);
        _folders = List<Map<String, dynamic>>.from(folders);

        _imageUrls
          ..clear()
          ..addAll(imageUrls);

        _pdfUrls
          ..clear()
          ..addAll(pdfUrls);

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      if (mounted) {
        setState(() {
          _isUploading = true;
          _errorMessage = null;
        });
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt',
          'jpg',
          'jpeg',
          'png',
          'webp',
        ],
      );

      // User membatalkan pilih file
      if (result == null) {
        return;
      }

      final pickedFile = result.files.single;

      // ============================================================
      // CEK BYTES
      // ============================================================

      if (pickedFile.bytes == null) {
        throw Exception('File tidak dapat dibaca.');
      }

      // ============================================================
      // UPLOAD FILE
      // ============================================================

      await _dbHelper.uploadLibraryFile(
        bytes: pickedFile.bytes!,
        fileName: pickedFile.name,
        title: pickedFile.name,
        description: 'File uploaded to Library',
      );

      // ============================================================
      // REFRESH LIBRARY
      // ============================================================

      if (!mounted) return;

      await _loadLibrary();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File berhasil diupload ke Library')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal upload file: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // ============================================================
  // IMAGE PREVIEW
  // ============================================================

  Widget _buildLibraryPreview(Map<String, dynamic> item) {
    final contentType = item['content_type']?.toString().toUpperCase();

    final itemId = item['id'];

    if (contentType == 'IMAGE' && itemId != null) {
      final imageUrl = _imageUrls[itemId as int];

      if (imageUrl != null && imageUrl.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            width: 64,
            height: 64,
            fit: BoxFit.cover,

            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }

              return Container(
                width: 64,
                height: 64,
                color: Colors.deepPurple.withValues(alpha: 0.08),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },

            errorBuilder: (context, error, stackTrace) {
              return _buildFileIcon(contentType);
            },
          ),
        );
      }
    }

    // ============================================================
    // PDF PREVIEW
    // ============================================================

    if (contentType == 'PDF') {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.picture_as_pdf,
          color: Colors.deepPurple,
          size: 32,
        ),
      );
    }

    return _buildFileIcon(contentType);
  }

  void _openImageFullscreen(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }

                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 60,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Gagal memuat gambar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // FILE ICON
  // ============================================================

  Widget _buildFileIcon(String? contentType) {
    IconData icon;

    switch (contentType) {
      case 'IMAGE':
        icon = Icons.image_outlined;
        break;

      case 'PDF':
        icon = Icons.picture_as_pdf_outlined;
        break;

      case 'DOCUMENT':
        icon = Icons.description_outlined;
        break;

      case 'TEXT':
        icon = Icons.article_outlined;
        break;

      case 'NOTE':
        icon = Icons.note_outlined;
        break;

      case 'FLASHCARD':
        icon = Icons.style_outlined;
        break;

      case 'QUIZ':
        icon = Icons.quiz_outlined;
        break;

      default:
        icon = Icons.insert_drive_file_outlined;
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.deepPurple, size: 30),
    );
  }

  Future<void> _openPdf(String url, String title) async {
    try {
      debugPrint('PDF URL: $url');

      final response = await http.get(Uri.parse(url));

      debugPrint('PDF STATUS: ${response.statusCode}');

      debugPrint('PDF BYTES: ${response.bodyBytes.length}');

      if (response.statusCode != 200) {
        throw Exception(
          'Gagal mengambil PDF. '
          'HTTP ${response.statusCode}',
        );
      }

      final Uint8List pdfBytes = response.bodyBytes;

      if (pdfBytes.isEmpty) {
        throw Exception('PDF kosong.');
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            return Scaffold(
              appBar: AppBar(
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),

              body: SfPdfViewer.memory(
                pdfBytes,

                onDocumentLoaded: (details) {
                  debugPrint(
                    'PDF BERHASIL: '
                    '${details.document.pages.count} halaman',
                  );
                },

                onDocumentLoadFailed: (details) {
                  debugPrint(
                    'PDF VIEWER GAGAL: '
                    '${details.error}',
                  );

                  debugPrint(
                    'PDF DETAIL: '
                    '${details.description}',
                  );
                },
              ),
            );
          },
        ),
      );
    } catch (e) {
      debugPrint('PDF DOWNLOAD GAGAL: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuka PDF: $e')));
    }
  }

  // ============================================================
  // PICK IMAGE + UPLOAD
  // ============================================================

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();

      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      // User batal pilih gambar
      if (image == null) {
        return;
      }

      if (!mounted) return;

      setState(() {
        _isUploading = true;
        _errorMessage = null;
      });

      // Upload
      await _dbHelper.uploadLibraryImage(image: image);

      // Reload Library
      await _loadLibrary();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gambar berhasil ditambahkan ke Library')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload gagal: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // ============================================================
  // FILE SIZE
  // ============================================================

  String _formatFileSize(dynamic size) {
    if (size == null) {
      return '';
    }

    final bytes = int.tryParse(size.toString());

    if (bytes == null) {
      return '';
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // ============================================================
  // FILE LABEL
  // ============================================================

  String _getFileLabel(String sourceType, String contentType) {
    if (sourceType == 'AI_SCAN') {
      return 'AI Scan';
    }

    switch (contentType) {
      case 'PDF':
        return 'PDF';

      case 'IMAGE':
        return 'Image';

      case 'DOCUMENT':
        return 'Document';

      case 'TEXT':
        return 'Text';

      case 'NOTE':
        return 'Note';

      case 'FLASHCARD':
        return 'Flashcard';

      case 'QUIZ':
        return 'Quiz';

      default:
        return 'Library Item';
    }
  }

  int? _itemId(Map<String, dynamic> item) =>
      int.tryParse(item['id']?.toString() ?? '');

  String _nameForId(List<Map<String, dynamic>> values, dynamic id) {
    for (final value in values) {
      if (value['id']?.toString() == id?.toString()) {
        return value['name']?.toString() ?? '-';
      }
    }
    return '-';
  }

  Future<void> _toggleFavorite(Map<String, dynamic> item) async {
    final id = _itemId(item);
    if (id == null) return;
    final nextValue = item['is_favorite'] != true;
    try {
      await _dbHelper.setLibraryItemFavorite(id, nextValue);
      await _loadLibrary();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memperbarui favorit: $e')));
    }
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final id = _itemId(item);
    if (id == null) return;
    final titleController = TextEditingController(
      text: item['title']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: item['description']?.toString() ?? '',
    );
    int? folderId = int.tryParse(item['folder_id']?.toString() ?? '');
    int? categoryId = int.tryParse(item['category_id']?.toString() ?? '');
    var isFavorite = item['is_favorite'] == true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Judul'),
                ),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Deskripsi'),
                ),
                DropdownButtonFormField<int?>(
                  initialValue: folderId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Folder'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tanpa folder'),
                    ),
                    ..._folders.map(
                      (folder) => DropdownMenuItem<int?>(
                        value: int.tryParse(folder['id'].toString()),
                        child: Text(folder['name']?.toString() ?? 'Folder'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => folderId = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Favorit'),
                  value: isFavorite,
                  onChanged: (value) =>
                      setDialogState(() => isFavorite = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: titleController.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && titleController.text.trim().isNotEmpty) {
      try {
        await _dbHelper.updateLibraryItem(
          id,
          title: titleController.text,
          description: descriptionController.text,
          folderId: folderId,
          categoryId: categoryId,
          isFavorite: isFavorite,
        );
        await _loadLibrary();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal menyimpan item: $e')));
        }
      }
    } else if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul tidak boleh kosong.')),
      );
    }
    titleController.dispose();
    descriptionController.dispose();
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final id = _itemId(item);
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus item?'),
        content: Text(
          '"${item['title'] ?? 'Item ini'}" akan dihapus dari Library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _dbHelper.deleteLibraryItem(id);
      await _loadLibrary();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menghapus item: $e')));
      }
    }
  }

  Future<void> _moveItemToFolder(Map<String, dynamic> item) async {
    final selected = await showModalBottomSheet<int?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Pindahkan ke folder')),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('Tanpa folder'),
              onTap: () => Navigator.pop(sheetContext),
            ),
            ..._folders.map(
              (folder) => ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder['name']?.toString() ?? 'Folder'),
                onTap: () => Navigator.pop(
                  sheetContext,
                  int.tryParse(folder['id'].toString()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    final itemId = _itemId(item);
    if (itemId == null) return;
    try {
      await _dbHelper.moveLibraryItem(itemId, folderId: selected);
      await _loadLibrary();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memindahkan file: $e')));
    }
  }

  Future<void> _openFolder(Map<String, dynamic> folder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryFolderPage(
          folder: folder,
          onItemAction: _handleFolderItemAction,
        ),
      ),
    );
    if (mounted) await _loadLibrary();
  }

  Future<void> _handleFolderItemAction(
    String action,
    Map<String, dynamic> item,
  ) async {
    switch (action) {
      case 'open':
        _openItem(item);
        break;
      case 'download':
        await _downloadItem(item);
        break;
      case 'share_link':
        await _shareDownloadLink(item);
        break;
      case 'move':
        await _moveItemToFolder(item);
        break;
      case 'details':
        _showItemInfo(item);
        break;
      case 'favorite':
        await _toggleFavorite(item);
        break;
      case 'edit':
        await _editItem(item);
        break;
      case 'delete':
        await _deleteItem(item);
        break;
    }
  }

  void _openItem(Map<String, dynamic> item) {
    final contentType = item['content_type']?.toString().toUpperCase();
    final id = _itemId(item);
    if (id == null) return;

    if (contentType == 'IMAGE') {
      final imageUrl = _imageUrls[id];
      if (imageUrl != null && imageUrl.isNotEmpty) {
        _openImageFullscreen(imageUrl);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gambar belum tersedia')));
      }
      return;
    }

    if (contentType == 'PDF') {
      final pdfUrl = _pdfUrls[id];
      if (pdfUrl != null && pdfUrl.isNotEmpty) {
        _openPdf(pdfUrl, item['title']?.toString() ?? 'PDF');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL PDF tidak ditemukan.')),
        );
      }
      return;
    }

    _openWithDeviceApp(item);
  }

  Map<String, dynamic>? _fileForItem(Map<String, dynamic> item) {
    final files = item['files'];
    if (files is Map) return Map<String, dynamic>.from(files);
    if (files is List && files.isNotEmpty && files.first is Map) {
      return Map<String, dynamic>.from(files.first as Map);
    }
    return null;
  }

  Future<String> _signedUrlForItem(Map<String, dynamic> item) async {
    final file = _fileForItem(item);
    final storagePath = file?['storage_path']?.toString();
    if (storagePath == null || storagePath.isEmpty) {
      throw Exception('File belum tersedia.');
    }
    return _dbHelper.getLibraryFileUrl(storagePath);
  }

  Future<void> _openWithDeviceApp(Map<String, dynamic> item) async {
    try {
      final url = await _signedUrlForItem(item);
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw Exception('Tidak ada aplikasi untuk membuka file ini.');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuka file: $e')));
    }
  }

  Future<void> _downloadItem(Map<String, dynamic> item) async {
    try {
      final file = _fileForItem(item);
      final fileName =
          file?['original_name']?.toString().trim().isNotEmpty == true
          ? file!['original_name'].toString()
          : item['title']?.toString() ?? 'file-chatatan';
      final mimeType =
          file?['mime_type']?.toString() ?? 'application/octet-stream';
      final url = await _signedUrlForItem(item);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Server mengembalikan status ${response.statusCode}.');
      }
      await FileSaver.instance.saveFile(
        bytes: response.bodyBytes,
        name: fileName,
        includeExtension: false,
        mimeType: MimeType.custom,
        customMimeType: mimeType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$fileName berhasil diunduh ke perangkat.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengunduh file: $e')));
    }
  }

  Future<void> _shareDownloadLink(Map<String, dynamic> item) async {
    try {
      final storagePath = _fileForItem(item)?['storage_path']?.toString();
      if (storagePath == null || storagePath.isEmpty) {
        throw Exception('File belum tersedia.');
      }
      final url = await _dbHelper.getLibraryDownloadUrl(storagePath);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Bagikan link unduhan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Siapa pun yang membuka link ini akan langsung mengunduh file. Link aktif selama 7 hari.',
              ),
              const SizedBox(height: 12),
              SelectableText(url, maxLines: 4),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tutup'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link unduhan disalin.')),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Salin link'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuat link: $e')));
    }
  }

  // ============================================================
  // LIBRARY ITEM
  // ============================================================

  Widget _buildLibraryItem(Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = item['title']?.toString() ?? 'Untitled';

    final description = item['description']?.toString() ?? '';

    final sourceType = item['source_type']?.toString() ?? '';

    final contentType = item['content_type']?.toString() ?? '';

    final isFavorite = item['is_favorite'] == true;

    // Nested relation files
    final dynamic filesData = item['files'];

    Map<String, dynamic>? file;

    if (filesData is Map) {
      file = Map<String, dynamic>.from(filesData);
    }

    final fileName = file?['original_name']?.toString();

    final fileSize = file?['file_size'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF202842), const Color(0xFF141A30)]
              : [
                  Colors.white.withValues(alpha: .78),
                  const Color(0xFFDDE7FF).withValues(alpha: .46),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? const Color(0xFF9CA9D8).withValues(alpha: .22)
              : Colors.white.withValues(alpha: .9),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6678BE).withValues(alpha: .10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),

          // --------------------------------------------------------
          // ICON
          // --------------------------------------------------------
          leading: _buildLibraryPreview(item),

          // --------------------------------------------------------
          // ON TAP
          // --------------------------------------------------------
          onTap: () => _openItem(item),

          // --------------------------------------------------------
          // TITLE
          // --------------------------------------------------------
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          // --------------------------------------------------------
          // SUBTITLE
          // --------------------------------------------------------
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description.isNotEmpty)
                Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),

              const SizedBox(height: 4),

              Text(
                fileName ?? _getFileLabel(sourceType, contentType),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),

              if (fileSize != null)
                Text(
                  _formatFileSize(fileSize),
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                ),
            ],
          ),

          // --------------------------------------------------------
          // TRAILING
          // --------------------------------------------------------
          trailing: PopupMenuButton<String>(
            tooltip: 'Aksi item',
            onSelected: (action) {
              switch (action) {
                case 'open':
                  _openItem(item);
                  break;
                case 'details':
                  _showItemInfo(item);
                  break;
                case 'download':
                  _downloadItem(item);
                  break;
                case 'share_link':
                  _shareDownloadLink(item);
                  break;
                case 'move':
                  _moveItemToFolder(item);
                  break;
                case 'favorite':
                  _toggleFavorite(item);
                  break;
                case 'edit':
                  _editItem(item);
                  break;
                case 'delete':
                  _deleteItem(item);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'open',
                child: ListTile(
                  leading: Icon(Icons.visibility_outlined),
                  title: Text('Buka file'),
                ),
              ),
              const PopupMenuItem(
                value: 'download',
                child: ListTile(
                  leading: Icon(Icons.download_outlined),
                  title: Text('Unduh ke perangkat'),
                ),
              ),
              const PopupMenuItem(
                value: 'share_link',
                child: ListTile(
                  leading: Icon(Icons.link_outlined),
                  title: Text('Bagikan link unduhan'),
                ),
              ),
              const PopupMenuItem(
                value: 'move',
                child: ListTile(
                  leading: Icon(Icons.drive_file_move_outline),
                  title: Text('Pindahkan ke folder'),
                ),
              ),
              const PopupMenuItem(
                value: 'details',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Lihat detail'),
                ),
              ),
              PopupMenuItem(
                value: 'favorite',
                child: ListTile(
                  leading: Icon(isFavorite ? Icons.star_outline : Icons.star),
                  title: Text(
                    isFavorite ? 'Hapus dari favorit' : 'Tambah favorit',
                  ),
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit'),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('Hapus', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
            child: Icon(
              isFavorite ? Icons.star_rounded : Icons.more_vert_rounded,
              color: isFavorite ? Colors.amber : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ITEM INFO
  // ============================================================

  void _showItemInfo(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? 'Untitled';
    final contentType = item['content_type']?.toString() ?? '';
    final sourceType = item['source_type']?.toString() ?? '';
    final fileName = _getOriginalFileName(item);
    final files = item['files'];
    final fileSize = files is Map ? files['file_size'] : null;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text('Tipe: ${_getFileLabel(sourceType, contentType)}'),
                Text('Sumber: $sourceType'),
                if (fileName.isNotEmpty) Text('File: $fileName'),
                if (fileSize != null)
                  Text('Ukuran: ${_formatFileSize(fileSize)}'),
                if (item['folder_id'] != null)
                  Text('Folder: ${_nameForId(_folders, item['folder_id'])}'),
                if ((item['description']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(item['description'].toString()),
                ],

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (contentType.toUpperCase() == 'IMAGE' ||
                          contentType.toUpperCase() == 'PDF') {
                        _openItem(item);
                      }
                    },
                    icon: const Icon(Icons.visibility_rounded),
                    label: Text(
                      contentType.toUpperCase() == 'IMAGE' ||
                              contentType.toUpperCase() == 'PDF'
                          ? 'Buka'
                          : 'Tutup',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 16),

            const Text(
              'Library masih kosong',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              'Tambahkan gambar atau dokumen '
              'ke Library kamu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _showAddLibraryMenu,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah item'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: Colors.red,
            ),

            const SizedBox(height: 16),

            const Text(
              'Gagal memuat Library',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _loadLibrary,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final hasFilters = _favoritesOnly;
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          FilterChip(
            label: const Text('Favorit'),
            selected: _favoritesOnly,
            avatar: const Icon(Icons.star_outline, size: 18),
            onSelected: (value) => setState(() => _favoritesOnly = value),
          ),
          if (hasFilters) ...[
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Reset'),
              onPressed: () => setState(() {
                _favoritesOnly = false;
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFolderCarousel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = _searchQuery.trim().toLowerCase();
    final folders = _folders.where((folder) {
      return query.isEmpty ||
          (folder['name']?.toString().toLowerCase() ?? '').contains(query);
    }).toList();
    if (folders.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 108,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'FOLDERS',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF5D6B85),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: folders.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final folder = folders[index];
                final folderId = folder['id'];
                final itemCount = _items
                    .where(
                      (item) =>
                          item['folder_id'].toString() == folderId.toString(),
                    )
                    .length;
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _openFolder(folder),
                  child: Container(
                    width: 178,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF202842), const Color(0xFF141A30)]
                            : [
                                Colors.white.withValues(alpha: .80),
                                const Color(0xFFDDE7FF).withValues(alpha: .46),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF9CA9D8).withValues(alpha: .22)
                            : Colors.white.withValues(alpha: .92),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEE9FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.folder_outlined,
                            color: Color(0xFF6C5CE7),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                folder['name']?.toString() ?? 'Folder',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$itemCount file',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createFolder() async {
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _FolderNamePage(title: 'Buat folder'),
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await _dbHelper.createLibraryFolder(name: name.trim());
      await _loadLibrary();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membuat folder: $e')));
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ChatatanAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Library',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _loadLibrary,
                      child: _buildBody(),
                    ),

                    if (_isUploading)
                      Container(
                        color: Colors.black.withValues(alpha: 0.25),
                        child: const Center(
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),

                                  SizedBox(height: 16),

                                  Text('Mengupload item...'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // ----------------------------------------------------------
      // ADD BUTTON
      // ----------------------------------------------------------
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 112),
        child: ChatatanGlass(
          radius: 32,
          opacity: .72,
          blur: 26,
          onTap: _isUploading ? null : _showAddLibraryMenu,
          child: const SizedBox(
            width: 62,
            height: 62,
            child: Center(
              child: Icon(
                Icons.add_rounded,
                color: ChatatanColors.primary,
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddLibraryMenu() {
    showChatatanGlassSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ChatatanSheetHandle(),
                const Text(
                  'Tambah ke Library',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 20),

                ChatatanGlass(
                  radius: 19,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.image, color: Colors.deepPurple),
                    ),
                    title: const Text('Gambar'),
                    subtitle: const Text('JPG, PNG, WEBP, GIF'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadImage();
                    },
                  ),
                ),
                ChatatanGlass(
                  radius: 19,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.create_new_folder_outlined,
                        color: Colors.deepPurple,
                      ),
                    ),
                    title: const Text('Folder baru'),
                    subtitle: const Text('Kelompokkan item Library'),
                    onTap: () {
                      Navigator.pop(context);
                      _createFolder();
                    },
                  ),
                ),

                ChatatanGlass(
                  radius: 19,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.description,
                        color: Colors.deepPurple,
                      ),
                    ),
                    title: const Text('PDF / Dokumen'),
                    subtitle: const Text('PDF, DOCX, XLSX, PPTX, TXT'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadFile();
                    },
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    final filteredItems = _filteredItems;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: ChatatanGlass(
            radius: 22,
            opacity: .64,
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari judul, deskripsi, atau nama file',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        _buildFolderCarousel(),
        _buildFilterBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null && _items.isEmpty
              ? _buildErrorState()
              : _items.isEmpty
              ? _buildEmptyState()
              : filteredItems.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(32),
                  children: const [
                    SizedBox(height: 80),
                    Icon(Icons.search_off, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Tidak ada item yang cocok',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    return _buildLibraryItem(filteredItems[index]);
                  },
                ),
        ),
      ],
    );
  }
}

class LibraryFolderPage extends StatefulWidget {
  const LibraryFolderPage({
    super.key,
    required this.folder,
    required this.onItemAction,
  });

  final Map<String, dynamic> folder;
  final Future<void> Function(String action, Map<String, dynamic> item)
  onItemAction;

  @override
  State<LibraryFolderPage> createState() => _LibraryFolderPageState();
}

class _LibraryFolderPageState extends State<LibraryFolderPage> {
  final _dbHelper = DbHelper();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _folders = [];
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _query = '';

  int? get _folderId => int.tryParse(widget.folder['id'].toString());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final folderId = _folderId;
    if (folderId == null) return;
    setState(() => _loading = true);
    try {
      final result = await Future.wait([
        _dbHelper.getLibraryFoldersByParent(parentFolderId: folderId),
        _dbHelper.getLibraryItems(folderId: folderId),
      ]);
      if (!mounted) return;
      setState(() {
        _folders = List<Map<String, dynamic>>.from(result[0]);
        _items = List<Map<String, dynamic>>.from(result[1]);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createSubfolder() async {
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            const _FolderNamePage(title: 'Buat folder di dalam folder ini'),
      ),
    );
    if (name == null || name.trim().isEmpty || _folderId == null) return;
    await _dbHelper.createLibraryFolder(
      name: name.trim(),
      parentFolderId: _folderId,
    );
    await _load();
  }

  Future<void> _openSubfolder(Map<String, dynamic> folder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryFolderPage(
          folder: folder,
          onItemAction: widget.onItemAction,
        ),
      ),
    );
    if (mounted) await _load();
  }

  IconData _iconForItem(Map<String, dynamic> item) {
    final type = item['content_type']?.toString().toUpperCase();
    if (type == 'PDF') return Icons.picture_as_pdf_outlined;
    if (type == 'IMAGE') return Icons.image_outlined;
    return Icons.description_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.folder['name']?.toString() ?? 'Folder';
    final query = _query.trim().toLowerCase();
    final folders = _folders
        .where(
          (folder) =>
              query.isEmpty ||
              (folder['name']?.toString().toLowerCase() ?? '').contains(query),
        )
        .toList();
    final items = _items.where((item) {
      final file = item['files'];
      final fileName = file is Map
          ? file['original_name']?.toString().toLowerCase() ?? ''
          : '';
      return query.isEmpty ||
          (item['title']?.toString().toLowerCase() ?? '').contains(query) ||
          fileName.contains(query);
    }).toList();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(name),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Buat folder di sini',
            onPressed: _createSubfolder,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Cari folder atau file',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: folders.isEmpty && items.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 160),
                              Icon(Icons.folder_open_outlined, size: 72),
                              SizedBox(height: 16),
                              Center(child: Text('Folder ini masih kosong')),
                            ],
                          )
                        : GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: .78,
                                ),
                            itemCount: folders.length + items.length,
                            itemBuilder: (context, index) {
                              if (index < folders.length) {
                                final folder = folders[index];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _openSubfolder(folder),
                                  child: Column(
                                    children: [
                                      const Expanded(
                                        child: Center(
                                          child: Icon(
                                            Icons.folder_rounded,
                                            size: 66,
                                            color: Color(0xFFFFBE2E),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        folder['name']?.toString() ?? 'Folder',
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              final item = items[index - folders.length];
                              return InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => widget.onItemAction('open', item),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          Center(
                                            child: Icon(
                                              _iconForItem(item),
                                              size: 60,
                                              color: const Color(0xFF6C5CE7),
                                            ),
                                          ),
                                          Positioned(
                                            top: 0,
                                            right: -8,
                                            child: PopupMenuButton<String>(
                                              icon: const Icon(
                                                Icons.more_vert,
                                                size: 20,
                                              ),
                                              onSelected: (value) async {
                                                await widget.onItemAction(
                                                  value,
                                                  item,
                                                );
                                                if (mounted) await _load();
                                              },
                                              itemBuilder: (_) => [
                                                const PopupMenuItem(
                                                  value: 'open',
                                                  child: Text('Buka file'),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'download',
                                                  child: Text(
                                                    'Unduh ke perangkat',
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'share_link',
                                                  child: Text(
                                                    'Bagikan link unduhan',
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: 'move',
                                                  child: Text(
                                                    'Pindahkan ke folder',
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'details',
                                                  child: Text('Lihat detail'),
                                                ),
                                                PopupMenuItem(
                                                  value: 'favorite',
                                                  child: Text(
                                                    item['is_favorite'] == true
                                                        ? 'Hapus dari favorit'
                                                        : 'Tambah favorit',
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Text('Edit'),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('Hapus'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      item['title']?.toString() ?? 'File',
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
