import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

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

  final Map<int, String> _imageUrls = {};
  final Map<int, String> _pdfUrls = {};

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

      final Map<int, String> imageUrls = {};
      final Map<int, String> pdfUrls = {};

      for (final item in items) {
        final contentType =
            item['content_type']?.toString().toUpperCase();

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
          debugPrint(
            '$contentType: files kosong untuk item $itemId',
          );
          continue;
        }

        String? storagePath;

        // Supabase mengembalikan Map
        if (fileData is Map<String, dynamic>) {
          storagePath =
              fileData['storage_path']?.toString();
        }

        // Jaga-jaga kalau List
        if (fileData is List &&
            fileData.isNotEmpty &&
            fileData.first is Map) {
          storagePath =
              fileData.first['storage_path']?.toString();
        }

        if (storagePath == null || storagePath.isEmpty) {
          debugPrint(
            '$contentType: storage_path kosong untuk item $itemId',
          );
          continue;
        }

        try {
          final url = await _dbHelper.getLibraryFileUrl(
            storagePath,
          );
          
          debugPrint(
            '========================================',
          );
          debugPrint(
            'PDF/IMAGE CONTENT TYPE: $contentType',
          );
          debugPrint(
            'ITEM ID: $itemId',
          );
          debugPrint(
            'STORAGE PATH: $storagePath',
          );
          debugPrint(
            'SIGNED URL: $url',
          );
          debugPrint(
            '========================================',
          );
          final id = int.parse(itemId.toString());

          if (contentType == 'IMAGE') {
            imageUrls[id] = url;
          } else if (contentType == 'PDF') {
            pdfUrls[id] = url;
          }

          debugPrint(
            '$contentType berhasil mendapatkan URL: $id',
          );
        } catch (e) {
          debugPrint(
            'Gagal membuat URL $contentType: $e',
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _items = items;

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
        throw Exception(
          'File tidak dapat dibaca.',
        );
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
        const SnackBar(
          content: Text(
            'File berhasil diupload ke Library',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal upload file: $e',
          ),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isUploading = false;
      });
    }
  }

  // ============================================================
  // IMAGE PREVIEW
  // ============================================================

  Widget _buildLibraryPreview(
    Map<String, dynamic> item,
  ) {
    final contentType =
        item['content_type']?.toString().toUpperCase();

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

            loadingBuilder: (
              context,
              child,
              loadingProgress,
            ) {
              if (loadingProgress == null) {
                return child;
              }

              return Container(
                width: 64,
                height: 64,
                color: Colors.deepPurple.withValues(
                  alpha: 0.08,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
              );
            },

            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
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
                loadingBuilder: (
                  context,
                  child,
                  loadingProgress,
                ) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
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
                          style: TextStyle(
                            color: Colors.white,
                          ),
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

  Widget _buildFileIcon(
  String? contentType,
  ) {
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
      color: Colors.deepPurple
          .withValues(alpha: 0.08),
      borderRadius:
          BorderRadius.circular(12),
    ),
    child: Icon(
      icon,
      color: Colors.deepPurple,
      size: 30,
    ),
    );
  }

  Future<void> _openPdf(
    String url,
    String title,
  ) async {
    try {
      debugPrint('PDF URL: $url');

      final response = await http.get(
        Uri.parse(url),
      );

      debugPrint(
        'PDF STATUS: ${response.statusCode}',
      );

      debugPrint(
        'PDF BYTES: ${response.bodyBytes.length}',
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Gagal mengambil PDF. '
          'HTTP ${response.statusCode}',
        );
      }

      final Uint8List pdfBytes =
          response.bodyBytes;

      if (pdfBytes.isEmpty) {
        throw Exception(
          'PDF kosong.',
        );
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
                backgroundColor:
                    Colors.deepPurple,
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
      debugPrint(
        'PDF DOWNLOAD GAGAL: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal membuka PDF: $e',
          ),
        ),
      );
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
        leading: _buildLibraryPreview(item),

        // --------------------------------------------------------
        // ON TAP
        // --------------------------------------------------------
        onTap: () {
          final contentType =
              item['content_type']?.toString().toUpperCase();

          final itemId = item['id'];

          if (itemId == null) return;

          final id = int.parse(itemId.toString());

          // =========================
          // IMAGE
          // =========================
          if (contentType == 'IMAGE') {
            final imageUrl = _imageUrls[id];

            if (imageUrl != null && imageUrl.isNotEmpty) {
              _openImageFullscreen(imageUrl);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gambar belum tersedia'),
                ),
              );
            }

            return;
          }

          // =========================
          // PDF
          // =========================
          if (contentType == 'PDF') {
            final pdfUrl = _pdfUrls[itemId];

            if (pdfUrl != null && pdfUrl.isNotEmpty) {
              _openPdf(
                pdfUrl,
                item['title']?.toString() ?? 'PDF',
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'URL PDF tidak ditemukan.',
                  ),
                ),
              );
            }

            return;
          }
        },


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
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(24),
      ),
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.image,
                    color: Colors.deepPurple,
                  ),
                ),
                title: const Text('Gambar'),
                subtitle: const Text(
                  'JPG, PNG, WEBP, GIF',
                ),
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
                    Icons.description,
                    color: Colors.deepPurple,
                  ),
                ),
                title: const Text('PDF / Dokumen'),
                subtitle: const Text(
                  'PDF, DOCX, XLSX, PPTX, TXT',
                ),
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
