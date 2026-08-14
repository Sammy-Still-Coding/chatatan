import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_forum_modal.dart';
import 'forum_detail_page.dart';
import 'db_helper.dart';
import 'chatatan_theme.dart';

class ForumTab extends StatefulWidget {
  const ForumTab({super.key});

  @override
  State<ForumTab> createState() => _ForumTabState();
}

class _ForumTabState extends State<ForumTab> {
  final _supabase = Supabase.instance.client;
  final _dbHelper = DbHelper();
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

  final Map<int, String?> _postVotes = {};

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('forum_posts')
          .select('''
            id,
            title,
            content,
            created_at,
            category_id,
            like_count,
            dislike_count,
            users:user_id (username, full_name, avatar_url),
            forum_categories ( name ),
            forum_replies ( count ),
            forum_attachments (
              id, curation_status, relevance_score, relevance_label,
              files (storage_path, original_name, mime_type, extension)
            )
          ''')
          .order('created_at', ascending: false);

      final posts = List<Map<String, dynamic>>.from(response);
      final votes = <int, String?>{};
      for (final post in posts) {
        final id = int.tryParse(post['id'].toString());
        if (id != null) {
          votes[id] = await _dbHelper.getForumPostVote(id);
          post['is_bookmarked'] = await _dbHelper.isForumPostBookmarked(id);
        }
      }
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _postVotes
          ..clear()
          ..addAll(votes);
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

  Future<void> _toggleVote(int index, String reaction) async {
    final post = _posts[index];
    final postId = post['id'] as int?;
    if (postId == null) return;
    try {
      final result = await _dbHelper.setForumPostVote(postId, reaction);
      if (!mounted) return;
      setState(() {
        _posts[index]['like_count'] = result['like_count'] ?? 0;
        _posts[index]['dislike_count'] = result['dislike_count'] ?? 0;
        _postVotes[postId] = result['reaction']?.toString();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memperbarui vote: $e')));
      }
    }
  }

  // --- TOGGLE BOOKMARK FORUM ---
  Future<void> _toggleBookmarkUI(int index) async {
    final post = _posts[index];
    final postId = post['id'] as int?;
    if (postId == null) return;

    final currentBookmarkStatus = post['is_bookmarked'] ?? false;

    try {
      final newStatus = await _dbHelper.toggleForumBookmark(
        postId,
        currentBookmarkStatus,
      );

      if (!mounted) return;
      setState(() {
        _posts[index]['is_bookmarked'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus ? 'Postingan disimpan' : 'Batal menyimpan postingan',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengubah bookmark: $e')));
    }
  }

  Future<void> _openCreateModal() async {
    final result = await showChatatanGlassSheet<bool>(
      context: context,
      builder: (_) => const CreateForumModal(),
    );

    if (result == true) {
      _fetchPosts();
    }
  }

  Future<void> _openDetailPage(int postId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ForumDetailPage(postId: postId)),
    );
    _fetchPosts();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [const Color(0xFF202842), const Color(0xFF171C34)]
                          : [
                              Colors.white.withValues(alpha: .80),
                              const Color(0xFFDCD9FF).withValues(alpha: .58),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF9CA9D8).withValues(alpha: .22)
                          : Colors.white.withValues(alpha: .9),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF6C5CE7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
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
                    final categoryName = category != null
                        ? category['name']
                        : 'Umum';
                    final displayName =
                        user['full_name'] ?? user['username'] ?? 'User';
                    final score =
                        (post['like_count'] as int? ?? 0) -
                        (post['dislike_count'] as int? ?? 0);
                    final vote = _postVotes[postId];

                    final repliesCountData = post['forum_replies'] as List?;
                    final replies =
                        (repliesCountData != null &&
                            repliesCountData.isNotEmpty)
                        ? (repliesCountData.first['count'] as int? ?? 0)
                        : 0;
                    final isBookmarked = post['is_bookmarked'] ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  const Color(0xFF202842),
                                  const Color(0xFF141A30),
                                ]
                              : [
                                  Colors.white.withValues(alpha: .78),
                                  const Color(
                                    0xFFDDE7FF,
                                  ).withValues(alpha: .42),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF9CA9D8).withValues(alpha: .22)
                              : Colors.white.withValues(alpha: .92),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF6678BE,
                            ).withValues(alpha: .10),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openDetailPage(postId),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFF6C5CE7),
                                    backgroundImage: user['avatar_url'] != null
                                        ? NetworkImage(user['avatar_url'])
                                        : null,
                                    child: user['avatar_url'] == null
                                        ? Text(
                                            displayName
                                                .substring(0, 1)
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        _formatTimeAgo(post['created_at']),
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
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

                              Text(
                                post['content'] ?? '',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  height: 1.4,
                                ),
                              ),
                              if (post['forum_attachments'] is List &&
                                  (post['forum_attachments'] as List)
                                      .isNotEmpty) ...[
                                const SizedBox(height: 12),
                                ...List<Map<String, dynamic>>.from(
                                  post['forum_attachments'] as List,
                                ).map(_buildAttachmentPreview),
                              ],
                              const SizedBox(height: 14),

                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF151B30)
                                          : Colors.white.withValues(alpha: .66),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(
                                                0xFF9CA9D8,
                                              ).withValues(alpha: .22)
                                            : Colors.white.withValues(
                                                alpha: .9,
                                              ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Vote naik',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () =>
                                              _toggleVote(index, 'LIKE'),
                                          icon: Icon(
                                            Icons.arrow_upward_rounded,
                                            size: 24,
                                            color: vote == 'LIKE'
                                                ? const Color(0xFF6C63FF)
                                                : Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          '$score',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: vote == null
                                                ? Colors.grey.shade700
                                                : const Color(0xFF6C63FF),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Vote turun',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () =>
                                              _toggleVote(index, 'DISLIKE'),
                                          icon: Icon(
                                            Icons.arrow_downward_rounded,
                                            size: 24,
                                            color: vote == 'DISLIKE'
                                                ? Colors.redAccent
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  InkWell(
                                    onTap: () => _openDetailPage(postId),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.chat_bubble_outline,
                                            size: 18,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$replies balasan',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
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
                                      isBookmarked
                                          ? Icons.bookmark
                                          : Icons.bookmark_border_rounded,
                                      color: isBookmarked
                                          ? const Color(0xFF6C63FF)
                                          : Colors.grey,
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

  Widget _buildAttachmentPreview(Map<String, dynamic> attachment) {
    final file = attachment['files'] is Map
        ? Map<String, dynamic>.from(attachment['files'] as Map)
        : <String, dynamic>{};
    final storagePath = file['storage_path']?.toString() ?? '';
    final extension = file['extension']?.toString().toLowerCase() ?? '';
    final mime = file['mime_type']?.toString().toLowerCase() ?? '';
    final isImage =
        mime.startsWith('image/') ||
        const {'png', 'jpg', 'jpeg', 'gif', 'webp'}.contains(extension);
    final status = attachment['curation_status']?.toString() ?? 'PENDING';
    final score = attachment['relevance_score'];
    final passed = status == 'PASSED';
    final color = passed
        ? Colors.green
        : status == 'FAILED'
        ? Colors.redAccent
        : Colors.orange;
    final label = passed
        ? 'Lolos${score == null ? '' : ' · $score/100'}'
        : status == 'FAILED'
        ? 'Tidak lolos${score == null ? '' : ' · $score/100'}'
        : 'Menunggu kurasi';
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (isImage && storagePath.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FutureBuilder<String>(
                future: _dbHelper.getLibraryFileUrl(storagePath),
                builder: (_, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 150,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  return Image.network(
                    snapshot.data!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 110,
                      child: Center(child: Icon(Icons.broken_image_outlined)),
                    ),
                  );
                },
              ),
            ),
            Positioned(top: 8, right: 8, child: badge),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file_rounded, color: Color(0xFF6C63FF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              file['original_name']?.toString() ?? 'Lampiran',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87,),
            ),
          ),
          const SizedBox(width: 8),
          badge,
        ],
      ),
    );
  }
}
