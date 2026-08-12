import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_forum_modal.dart';
import 'forum_detail_page.dart';

class ForumTab extends StatefulWidget {
  const ForumTab({super.key});

  @override
  State<ForumTab> createState() => _ForumTabState();
}

class _ForumTabState extends State<ForumTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

  // --- STATE TOGGLE LIKE (Mencegah Spam Like) ---
  final Set<int> _likedPostIds = {};

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.from('forum_posts').select('''
            id,
            title,
            content,
            created_at,
            category_id,
            like_count,
            users:user_id (username, full_name, avatar_url),
            forum_categories ( name ),
            forum_replies ( count )
          ''').order('created_at', ascending: false);

      setState(() {
        _posts = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error fetching posts: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTimeAgo(String? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.tryParse(timestamp);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);

    if (diff.inDays > 0) return '${diff.inDays} hari lalu';
    if (diff.inHours > 0) return '${diff.inHours} jam lalu';
    if (diff.inMinutes > 0) return '${diff.inMinutes} menit lalu';
    return 'Baru saja';
  }

  // --- TOGGLE LIKE (+1 / -1) ---
  Future<void> _toggleLike(int index) async {
    final post = _posts[index];
    final postId = post['id'] as int?;

    // Mencegah error jika ID postingan bernilai null
    if (postId == null) return;

    final isLiked = _likedPostIds.contains(postId);
    final currentLikes = (post['like_count'] as int?) ?? 0;
    final newLikes = isLiked ? (currentLikes - 1) : (currentLikes + 1);
    final safeLikes = newLikes < 0 ? 0 : newLikes;

    setState(() {
      if (isLiked) {
        _likedPostIds.remove(postId);
      } else {
        _likedPostIds.add(postId);
      }
      _posts[index]['like_count'] = safeLikes;
    });

    try {
      await _supabase
          .from('forum_posts')
          .update({'like_count': safeLikes})
          .eq('id', postId);
    } catch (e) {
      debugPrint('Gagal update like: $e');
    }
  }

  void _toggleBookmarkUI(int index) {
    setState(() {
      _posts[index]['is_bookmarked'] = !(_posts[index]['is_bookmarked'] ?? false);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_posts[index]['is_bookmarked'] == true ? 'Postingan disimpan' : 'Batal menyimpan'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openCreateModal() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const CreateForumModal(),
    );

    if (result == true) {
      _fetchPosts();
    }
  }

  Future<void> _openDetailPage(int postId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForumDetailPage(postId: postId),
      ),
    );
    _fetchPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FB),
      body: RefreshIndicator(
        onRefresh: _fetchPosts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Tombol Buat Diskusi Baru
              InkWell(
                onTap: _openCreateModal,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EAF6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF6C5CE7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Buat Diskusi Baru',
                        style: TextStyle(
                          color: Color(0xFF6C5CE7),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Daftar Postingan Forum
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                )
              else if (_posts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'Belum ada diskusi. Jadilah yang pertama membuat postingan!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    final postId = post['id'] as int;
                    final user = post['users'] ?? {};
                    final category = post['forum_categories'];
                    final categoryName = category != null ? category['name'] : 'Umum';
                    final displayName = user['full_name'] ?? user['username'] ?? 'User';
                    final likes = post['like_count'] ?? 0;
                    final isLiked = _likedPostIds.contains(postId);

                    final repliesCountData = post['forum_replies'] as List?;
                    final replies = (repliesCountData != null && repliesCountData.isNotEmpty)
                        ? (repliesCountData.first['count'] as int? ?? 0)
                        : 0;
                    final isBookmarked = post['is_bookmarked'] ?? false;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openDetailPage(postId),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header: Avatar, Nama, Waktu, dan Hashtag
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFF6C5CE7),
                                    backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                                    child: user['avatar_url'] == null
                                        ? Text(displayName.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text(_formatTimeAgo(post['created_at']), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                    ],
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEDF2FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '#$categoryName',
                                      style: const TextStyle(
                                        color: Color(0xFF4C6EF5),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Isi Postingan
                              Text(
                                post['content'] ?? '',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Footer Action: Like, Balasan, dan Bookmark
                              Row(
                                children: [
                                  // Tombol Like (Toggle)
                                  InkWell(
                                    onTap: () => _toggleLike(index),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                                            size: 18,
                                            color: isLiked ? const Color(0xFF6C63FF) : Colors.grey,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$likes',
                                            style: TextStyle(
                                              color: isLiked ? const Color(0xFF6C63FF) : Colors.grey,
                                              fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Tombol Balasan
                                  InkWell(
                                    onTap: () => _openDetailPage(postId),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$replies balasan',
                                            style: const TextStyle(color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const Spacer(),

                                  // Tombol Bookmark
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      isBookmarked ? Icons.bookmark : Icons.bookmark_border_rounded,
                                      color: isBookmarked ? const Color(0xFF6C63FF) : Colors.grey,
                                      size: 20,
                                    ),
                                    onPressed: () => _toggleBookmarkUI(index),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}