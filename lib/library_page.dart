import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'db_helper.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final DbHelper _dbHelper = DbHelper();

  List<Map<String, dynamic>> _items = [];

  bool _isLoading = true;
  bool _isUploading = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadLibrary();
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
      final items = await _dbHelper.getLibraryItems();

      if (!mounted) return;

      setState(() {
        _items = items;
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

  // ============================================================
  // FILE ICON
  // ============================================================

  IconData _getFileIcon(String sourceType, String contentType) {
    if (sourceType == 'AI_SCAN') {
      return Icons.document_scanner_rounded;
    }

    switch (contentType) {
      case 'PDF':
        return Icons.picture_as_pdf_rounded;

      case 'IMAGE':
        return Icons.image_rounded;

      case 'DOCUMENT':
        return Icons.description_rounded;

      case 'TEXT':
        return Icons.text_snippet_rounded;

      case 'NOTE':
        return Icons.sticky_note_2_rounded;

      case 'FLASHCARD':
        return Icons.style_rounded;

      case 'QUIZ':
        return Icons.quiz_rounded;

      default:
        return Icons.insert_drive_file_rounded;
    }
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

    final icon = _getFileIcon(sourceType, contentType);

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
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.deepPurple),
        ),

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
        trailing: Icon(
          isFavorite ? Icons.star_rounded : Icons.chevron_right_rounded,
          color: isFavorite ? Colors.amber : Colors.grey.shade500,
        ),

        // --------------------------------------------------------
        // ON TAP
        // --------------------------------------------------------
        onTap: () {
          _showItemInfo(item);
        },
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

                Text('Type: $contentType'),

                Text('Source: $sourceType'),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Preview akan dibuat pada tahap berikutnya.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text('Preview'),
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
              onPressed: _pickAndUploadImage,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: const Text('Tambah Gambar'),
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

                        Text('Mengupload gambar...'),
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
          onPressed: _isUploading ? null : _pickAndUploadImage,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _items.isEmpty) {
      return _buildErrorState();
    }

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        return _buildLibraryItem(_items[index]);
      },
    );
  }
}
