import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForumDetailPage extends StatefulWidget {
  final int postId;
  const ForumDetailPage({Key? key, required this.postId}) : super(key: key);

  @override
  State<ForumDetailPage> createState() => _ForumDetailPageState();
}

class _ForumDetailPageState extends State<ForumDetailPage> {
  final _supabase = Supabase.instance.client;
  final _replyController = TextEditingController();
  final _focusNode = FocusNode();

  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _replies = [];
  bool _isLoading = true;

  // --- STATE TOGGLE LIKE (Mencegah Spam Like) ---
  bool _isPostLiked = false;
  final Set<int> _likedReplyIds = {}; // Menyimpan ID reply yang sudah di-like user

  // --- STATE MEMBALAS BALASAN (Reply-to-Reply) ---
  Map<String, dynamic>? _replyingTo; // Data reply yang sedang dibalas

  // UI State untuk Bookmark
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _loadPostData();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPostData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Post Detail
      final postRes = await _supabase.from('forum_posts').select('''
        *,
        users:user_id (username, full_name, avatar_url),
        forum_categories:category_id (name)
      ''').eq('id', widget.postId).single();

      // 2. Fetch Replies (Mengambil data pembalas + data orang yang dibalas via parent_reply_id)
      final repliesRes = await _supabase.from('forum_replies').select('''
        *,
        users:user_id (username, full_name, avatar_url),
        parent:parent_reply_id (
          users:user_id (username, full_name)
        )
      ''').eq('post_id', widget.postId).order('created_at', ascending: true);

      setState(() {
        _post = postRes;
        _replies = List<Map<String, dynamic>>.from(repliesRes);
      });
    } catch (e) {
      debugPrint('Error load detail: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTimeAgo(String? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.tryParse(timestamp);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);

    if (diff.inDays > 0) return '${diff.inDays} hr lalu';
    if (diff.inHours > 0) return '${diff.inHours} jam lalu';
    if (diff.inMinutes > 0) return '${diff.inMinutes} min lalu';
    return 'Baru saja';
  }

  // --- TOGGLE LIKE POST UTAMA (+1 / -1) ---
  Future<void> _togglePostLike() async {
    if (_post == null) return;
    final currentLikes = (_post!['like_count'] as int?) ?? 0;
    
    // Jika sudah di-like, kurangi 1 (Unlike). Jika belum, tambah 1 (Like).
    final newLikes = _isPostLiked ? (currentLikes - 1) : (currentLikes + 1);
    final safeLikes = newLikes < 0 ? 0 : newLikes;

    setState(() {
      _isPostLiked = !_isPostLiked;
      _post!['like_count'] = safeLikes;
    });

    try {
      await _supabase
          .from('forum_posts')
          .update({'like_count': safeLikes})
          .eq('id', widget.postId);
    } catch (e) {
      debugPrint('Gagal update like post: $e');
    }
  }

  // --- TOGGLE LIKE BALASAN / REPLY (+1 / -1) ---
  Future<void> _toggleReplyLike(int index) async {
    final reply = _replies[index];
    final replyId = reply['id'];
    final isLiked = _likedReplyIds.contains(replyId);
    final currentLikes = (reply['like_count'] as int?) ?? 0;

    final newLikes = isLiked ? (currentLikes - 1) : (currentLikes + 1);
    final safeLikes = newLikes < 0 ? 0 : newLikes;

    setState(() {
      if (isLiked) {
        _likedReplyIds.remove(replyId);
      } else {
        _likedReplyIds.add(replyId);
      }
      _replies[index]['like_count'] = safeLikes;
    });

    try {
      await _supabase
          .from('forum_replies')
          .update({'like_count': safeLikes})
          .eq('id', replyId);
    } catch (e) {
      debugPrint('Gagal update like reply: $e');
    }
  }

  // --- SET MEMBALAS KALIMAT/BALASAN TERTENTU ---
  void _setReplyingTo(Map<String, dynamic> reply) {
    final user = reply['users'] ?? {};
    final username = user['username'] ?? user['full_name'] ?? 'User';

    setState(() {
      _replyingTo = {
        'id': reply['id'],
        'username': username,
      };
    });

    // Otomatis fokus ke kolom input
    _focusNode.requestFocus();
  }

  void _cancelReplying() {
    setState(() {
      _replyingTo = null;
    });
  }

  // --- KIRIM BALASAN ---
  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    final userId = _supabase.auth.currentUser?.id;
    if (text.isEmpty || userId == null) return;

    try {
      final Map<String, dynamic> insertData = {
        'post_id': widget.postId,
        'user_id': userId,
        'content': text,
        'like_count': 0,
      };

      // Jika membalas balasan orang lain, masukkan parent_reply_id
      if (_replyingTo != null) {
        insertData['parent_reply_id'] = _replyingTo!['id'];
      }

      await _supabase.from('forum_replies').insert(insertData);

      // Increment reply_count di forum_posts
      final currentReplyCount = (_post?['reply_count'] as int?) ?? 0;
      await _supabase.from('forum_posts').update({
        'reply_count': currentReplyCount + 1,
      }).eq('id', widget.postId);

      _replyController.clear();
      _cancelReplying();
      _loadPostData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim balasan: $e')),
      );
    }
  }

  void _toggleBookmarkUI() {
    setState(() {
      _isBookmarked = !_isBookmarked;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isBookmarked ? 'Postingan disimpan' : 'Batal menyimpan postingan'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_post == null) {
      return const Scaffold(body: Center(child: Text('Postingan tidak ditemukan')));
    }

    final user = _post!['users'] ?? {};
    final category = _post!['forum_categories'] ?? {};
    final categoryName = category['name'] ?? 'Umum';
    final displayName = user['full_name'] ?? user['username'] ?? 'User';
    final likes = _post!['like_count'] ?? 0;
    final repliesCount = _replies.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FB),
      appBar: AppBar(
        title: const Text('Detail Forum', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CARD POST UTAMA ---
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF6C5CE7),
                              backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                              child: user['avatar_url'] == null
                                  ? Text(displayName.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(_formatTimeAgo(_post!['created_at']), style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                                style: const TextStyle(color: Color(0xFF4C6EF5), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (_post!['title'] != null && _post!['title'].toString().isNotEmpty) ...[
                          Text(_post!['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                        ],
                        Text(_post!['content'] ?? '', style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87)),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            // Tombol Like Post (Toggle + Indicator Aktif)
                            InkWell(
                              onTap: _togglePostLike,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      _isPostLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                                      size: 18,
                                      color: _isPostLiked ? const Color(0xFF6C63FF) : Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$likes',
                                      style: TextStyle(
                                        color: _isPostLiked ? const Color(0xFF6C63FF) : Colors.grey,
                                        fontWeight: _isPostLiked ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text('$repliesCount balasan', style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                _isBookmarked ? Icons.bookmark : Icons.bookmark_border_rounded,
                                color: _isBookmarked ? const Color(0xFF6C63FF) : Colors.grey,
                                size: 22,
                              ),
                              onPressed: _toggleBookmarkUI,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text('Balasan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 12),

                  // --- LIST BALASAN ---
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _replies.length,
                    itemBuilder: (context, index) {
                      final reply = _replies[index];
                      final replyId = reply['id'];
                      final replyUser = reply['users'] ?? {};
                      final replyName = replyUser['full_name'] ?? replyUser['username'] ?? 'User';
                      final replyLikes = reply['like_count'] ?? 0;
                      final isReplyLiked = _likedReplyIds.contains(replyId);

                      // Cek apakah balasan ini ditujukan ke orang lain (Parent Reply)
                      final parentData = reply['parent'];
                      final parentUser = parentData != null ? parentData['users'] : null;
                      final parentName = parentUser != null ? (parentUser['username'] ?? parentUser['full_name']) : null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF8E8E93),
                              backgroundImage: replyUser['avatar_url'] != null ? NetworkImage(replyUser['avatar_url']) : null,
                              child: replyUser['avatar_url'] == null
                                  ? Text(replyName.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(replyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(width: 6),
                                      Text(_formatTimeAgo(reply['created_at']), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                    ],
                                  ),
                                  
                                  // Label "Membalas @username" jika ini balasan bertingkat
                                  if (parentName != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Membalas @$parentName',
                                      style: const TextStyle(color: Color(0xFF6C5CE7), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],

                                  const SizedBox(height: 4),
                                  Text(reply['content'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                  const SizedBox(height: 10),

                                  // Action Bar Balasan: Like & Tombol Balas
                                  Row(
                                    children: [
                                      // Like Toggle Balasan
                                      InkWell(
                                        onTap: () => _toggleReplyLike(index),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isReplyLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                                                size: 15,
                                                color: isReplyLiked ? const Color(0xFF6C63FF) : Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$replyLikes',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isReplyLiked ? const Color(0xFF6C63FF) : Colors.grey,
                                                  fontWeight: isReplyLiked ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Tombol BALAS (Twitter-style reply)
                                      InkWell(
                                        onTap: () => _setReplyingTo(reply),
                                        borderRadius: BorderRadius.circular(6),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Text(
                                            'Balas',
                                            style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // --- BAR INPUT BALASAN ---
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Indikator "Membalas @user"
                  if (_replyingTo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Membalas @${_replyingTo!['username']}',
                            style: const TextStyle(color: Color(0xFF4C6EF5), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: _cancelReplying,
                            child: const Icon(Icons.close, size: 16, color: Color(0xFF4C6EF5)),
                          ),
                        ],
                      ),
                    ),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            hintText: _replyingTo != null
                                ? 'Balas @${_replyingTo!['username']}...'
                                : 'Tulis balasan...',
                            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                            filled: true,
                            fillColor: const Color(0xFFF5F6FB),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: Color(0xFF6C5CE7)),
                        onPressed: _sendReply,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}