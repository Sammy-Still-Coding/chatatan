import 'package:flutter/material.dart';
import 'chatatan_theme.dart';
import 'db_helper.dart';
import 'forum_detail_page.dart';
 
class SavedPage extends StatefulWidget {
  const SavedPage({super.key});
 
  @override
  State<SavedPage> createState() => _SavedPageState();
}
 
class _SavedPageState extends State<SavedPage> {
  final DbHelper _dbHelper = DbHelper();
  bool _isLoading = true;
  List<Map<String, dynamic>> _savedPosts = [];
 
  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }
 
  Future<void> _loadSavedPosts() async {
    setState(() => _isLoading = true);
    try {
      final posts = await _dbHelper.getBookmarkedForumPosts();
      setState(() {
        _savedPosts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat item tersimpan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
 
  Future<void> _removeBookmark(int postId, int index) async {
    try {
      await _dbHelper.toggleForumBookmark(postId, true);
      setState(() {
        _savedPosts.removeAt(index);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item berhasil dihapus dari tersimpan.'),
            backgroundColor: Color(0xFF5B6CFF),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menghapus bookmark.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
 
  String _formatDate(String? rawDate) {
    if (rawDate == null) return '';
    final date = DateTime.tryParse(rawDate);
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Item Tersimpan',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ChatatanAmbientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadSavedPosts,
                  color: const Color(0xFF5B6CFF),
                  child: _savedPosts.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          itemCount: _savedPosts.length,
                          itemBuilder: (context, index) {
                            final item = _savedPosts[index];
                            final post =
                                item['forum_posts'] as Map<String, dynamic>?;
 
                            if (post == null) return const SizedBox.shrink();
 
                            final int postId = post['id'];
                            final String title = post['title'] ?? 'Tanpa Judul';
                            final String content = post['content'] ?? '';
                            final String createdAt = _formatDate(
                              post['created_at'],
                            );
 
                            final user =
                                post['users']
                                    as Map<
                                      String,
                                      dynamic
                                    >?; // ✅ sesuaikan ke 'users'
                            final String author =
                                user?['username'] ??
                                user?['full_name'] ??
                                'Pengguna';
                            final String? avatarUrl = user?['avatar_url'];
 
                            return _buildSavedCard(
                              index: index,
                              postId: postId,
                              title: title,
                              content: content,
                              author: author,
                              avatarUrl: avatarUrl,
                              createdAt: createdAt,
                              rawPost: post, // ✅ Tambahkan baris ini
                            );
                          },
                        ),
                ),
        ),
      ),
    );
  }
 
  Widget _buildSavedCard({
    required int index,
    required int postId,
    required String title,
    required String content,
    required String author,
    required String? avatarUrl,
    required String createdAt,
    required Map<String, dynamic>
    rawPost, // Kirim seluruh data post jika dibutuhkan
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            // Ganti nama parameter sesuai konstruktor di ForumDetailPage kamu
            builder: (context) => ForumDetailPage(postId: postId),
          ),
        );
      },
      child: ChatatanGlass(
        margin: const EdgeInsets.only(bottom: 14),
        radius: 22,
        opacity: .66,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF5B6CFF).withOpacity(0.1),
                    backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty)
                        ? Text(
                            author.isNotEmpty ? author[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: Color(0xFF5B6CFF),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          author,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (createdAt.isNotEmpty)
                          Text(
                            createdAt,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.bookmark_remove_rounded,
                      color: Color(0xFFFF5B5B),
                      size: 22,
                    ),
                    tooltip: 'Hapus Bookmark',
                    onPressed: () => _removeBookmark(postId, index),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
 
  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(), // Memungkinkan Pull-to-Refresh
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B6CFF).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bookmark_outline_rounded,
                        size: 40,
                        color: Color(0xFF5B6CFF),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Belum Ada Item Tersimpan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Postingan forum yang Anda tandai dengan bookmark akan muncul di halaman ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}