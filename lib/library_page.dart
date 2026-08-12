import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;

import 'db_helper.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final DbHelper _dbHelper = DbHelper();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _folders = [];
  List<Map<String, dynamic>> _categories = [];
  String _searchQuery = '';
  int? _selectedFolderId;
  int? _selectedCategoryId;
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
      final matchesFolder =
          _selectedFolderId == null || item['folder_id'] == _selectedFolderId;
      final matchesCategory =
          _selectedCategoryId == null ||
          item['category_id'] == _selectedCategoryId;
      final matchesFavorite = !_favoritesOnly || item['is_favorite'] == true;

      return matchesSearch &&
          matchesFolder &&
          matchesCategory &&
          matchesFavorite;
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
      final results = await Future.wait([
        _dbHelper.getLibraryItems(),
        _dbHelper.getLibraryFolders(),
        _dbHelper.getLibraryCategories(),
      ]);
      final items = results[0];
      final folders = results[1];
      final categories = results[2];

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
        _categories = List<Map<String, dynamic>>.from(categories);

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
                DropdownButtonFormField<int?>(
                  initialValue: categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tanpa kategori'),
                    ),
                    ..._categories.map(
                      (category) => DropdownMenuItem<int?>(
                        value: int.tryParse(category['id'].toString()),
                        child: Text(category['name']?.toString() ?? 'Kategori'),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => categoryId = value),
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

    _showItemInfo(item);
  }

  // ============================================================
  // LIBRARY ITEM
  // ============================================================

  Widget _buildLibraryItem(Map<String, dynamic> item) {
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                title: Text('Buka / detail'),
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
                if (item['category_id'] != null)
                  Text(
                    'Kategori: ${_nameForId(_categories, item['category_id'])}',
                  ),
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
    final hasFilters =
        _selectedFolderId != null ||
        _selectedCategoryId != null ||
        _favoritesOnly;
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
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.folder_outlined, size: 18),
            label: Text(
              _selectedFolderId == null
                  ? 'Semua folder'
                  : _nameForId(_folders, _selectedFolderId),
            ),
            onPressed: _showFolderFilter,
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.category_outlined, size: 18),
            label: Text(
              _selectedCategoryId == null
                  ? 'Semua kategori'
                  : _nameForId(_categories, _selectedCategoryId),
            ),
            onPressed: _showCategoryFilter,
          ),
          if (hasFilters) ...[
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Reset'),
              onPressed: () => setState(() {
                _selectedFolderId = null;
                _selectedCategoryId = null;
                _favoritesOnly = false;
              }),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showFolderFilter() async {
    final selected = await showModalBottomSheet<int?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Pilih folder')),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('Semua folder'),
              onTap: () => Navigator.pop(sheetContext),
            ),
            ..._folders.map(
              (folder) => ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder['name']?.toString() ?? 'Folder'),
                trailing:
                    folder['id']?.toString() == _selectedFolderId?.toString()
                    ? const Icon(Icons.check, color: Colors.deepPurple)
                    : null,
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
    setState(() => _selectedFolderId = selected);
  }

  Future<void> _showCategoryFilter() async {
    final selected = await showModalBottomSheet<int?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Pilih kategori')),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Semua kategori'),
              onTap: () => Navigator.pop(sheetContext),
            ),
            ..._categories.map(
              (category) => ListTile(
                leading: const Icon(Icons.category_outlined),
                title: Text(category['name']?.toString() ?? 'Kategori'),
                trailing:
                    category['id']?.toString() ==
                        _selectedCategoryId?.toString()
                    ? const Icon(Icons.check, color: Colors.deepPurple)
                    : null,
                onTap: () => Navigator.pop(
                  sheetContext,
                  int.tryParse(category['id'].toString()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _selectedCategoryId = selected);
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buat folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nama folder'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Buat'),
          ),
        ],
      ),
    );
    final name = controller.text.trim();
    controller.dispose();
    if (created != true || name.isEmpty) return;
    try {
      await _dbHelper.createLibraryFolder(name: name);
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
      backgroundColor: const Color(0xFFF7F5FA),

      appBar: AppBar(
        title: const Text('Library'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: Stack(
        children: [
          RefreshIndicator(onRefresh: _loadLibrary, child: _buildBody()),

          // ------------------------------------------------------
          // UPLOAD LOADING
          // ------------------------------------------------------
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

      // ----------------------------------------------------------
      // ADD BUTTON
      // ----------------------------------------------------------
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton(
          onPressed: _isUploading ? null : _showAddLibraryMenu,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showAddLibraryMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tambah ke Library',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 20),

                ListTile(
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
                ListTile(
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

                ListTile(
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
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
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
