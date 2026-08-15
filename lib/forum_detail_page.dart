import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'attachment_preview.dart';
import 'db_helper.dart';
import 'chatatan_theme.dart';

class ForumDetailPage extends StatefulWidget {
  final int postId;
  const ForumDetailPage({Key? key, required this.postId}) : super(key: key);

  @override
  State<ForumDetailPage> createState() => _ForumDetailPageState();
}

class _ForumDetailPageState extends State<ForumDetailPage> {
  final _supabase = Supabase.instance.client;
  final _dbHelper = DbHelper();
  final _replyController = TextEditingController();
  final _focusNode = FocusNode();

  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _replies = [];
  List<Map<String, dynamic>> _selectedReplyLibraryItems = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _attachments = [];

  // --- STATE TOGGLE LIKE (Mencegah Spam Like) ---
  String? _postVote;
  final Set<int> _likedReplyIds = {};

  // --- STATE MEMBALAS BALASAN (Reply-to-Reply) ---
  Map<String, dynamic>? _replyingTo;

  // UI State untuk Bookmark
  bool _isBookmarked = false;
  final Set<int> _savedAttachmentIds = {};

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
      final postRes = await _supabase
          .from('forum_posts')
          .select('''
        *,
        users:user_id (username, full_name, avatar_url),
        forum_categories:category_id (name)
      ''')
          .eq('id', widget.postId)
          .single();

      // 2. Fetch Replies
      final repliesRes = await _supabase
          .from('forum_replies')
          .select('''
        *,
        users:user_id (username, full_name, avatar_url),
        forum_attachments (
          id, uploaded_by, curation_status, relevance_label,
          files (original_name, extension, mime_type, file_size, storage_path)
        ),
        parent:parent_reply_id (
          users:user_id (username, full_name)
        )
      ''')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      final attachments = await _dbHelper.getForumAttachments(widget.postId);
      final postVote = await _dbHelper.getForumPostVote(widget.postId);
      Set<int> likedReplyIds = {};
      try {
        likedReplyIds = await _dbHelper.getMyLikedForumReplies(widget.postId);
      } catch (_) {
        // Migration lama tetap dapat membuka detail forum.
      }

      // Ambil status bookmark awal postingan
      final isBookmarked = await _dbHelper.isForumPostBookmarked(widget.postId);

      // ------------------------------------------------------------------------
      // [PERBAIKAN] Ambil ID attachment yang sudah pernah disimpan pengguna
      // ------------------------------------------------------------------------
      Set<int> savedAttachmentIds = {};
      try {
        savedAttachmentIds = await _dbHelper.getSavedForumAttachmentIds(widget.postId);
      } catch (_) {
        // Jika helper belum tersedia/error, biarkan kosong agar tidak crash
      }

      if (!mounted) return;
      setState(() {
        _post = postRes;
        _replies = List<Map<String, dynamic>>.from(repliesRes);
        _attachments = attachments;
        _postVote = postVote;
        _isBookmarked = isBookmarked;
        _likedReplyIds
          ..clear()
          ..addAll(likedReplyIds);
        
        // Update state savedAttachmentIds agar warna ikon tetap ungu setelah refresh
        _savedAttachmentIds
          ..clear()
          ..addAll(savedAttachmentIds);
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

  Future<void> _togglePostVote(String reaction) async {
    if (_post == null) return;
    try {
      final result = await _dbHelper.setForumPostVote(widget.postId, reaction);
      if (!mounted) return;
      setState(() {
        _post!['like_count'] = result['like_count'] ?? 0;
        _post!['dislike_count'] = result['dislike_count'] ?? 0;
        _postVote = result['reaction']?.toString();
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
  Future<void> _toggleBookmarkUI() async {
    try {
      final newStatus = await _dbHelper.toggleForumBookmark(
        widget.postId,
        _isBookmarked,
      );

      if (!mounted) return;
      setState(() {
        _isBookmarked = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isBookmarked ? 'Postingan disimpan' : 'Batal menyimpan postingan',
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

  Future<void> _saveAttachmentToLibrary(
    int attachmentId, {
    String folderName = 'Dari Forum',
  }) async {
    try {
      await _dbHelper.saveForumAttachmentToLibrary(
        attachmentId,
        folderName: folderName,
      );
      if (mounted) {
        // Update state agar ikon berubah warna jadi terisi (filled bookmark)
        setState(() {
          _savedAttachmentIds.add(attachmentId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File disimpan ke Library'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan file: $e')));
      }
    }
  }

  Future<void> _retryAttachmentCuration(int attachmentId) async {
    try {
      await _dbHelper.retryForumAttachmentCuration(attachmentId);
      await _loadPostData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kurasi belum dapat dilakukan: $e')),
        );
      }
    }
  }

  Future<void> _pickReplyFilesFromLibrary() async {
    try {
      final items = await _dbHelper.getLibraryItems();
      if (!mounted) return;
      final selectedIds = _selectedReplyLibraryItems
          .map((item) => item['id']?.toString())
          .whereType<String>()
          .toSet();
      final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          final selected = <String>{...selectedIds};
          return StatefulBuilder(
            builder: (context, setSheetState) => SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .7,
                child: Column(
                  children: [
                    const ListTile(
                      title: Text('Pilih file dari Library'),
                      subtitle: Text(
                        'Lampiran balasan tidak melalui kurasi AI',
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final files = item['files'];
                          final hasFile =
                              files is Map && files['original_name'] != null;
                          final id = item['id'].toString();
                          return CheckboxListTile(
                            value: selected.contains(id),
                            enabled: hasFile,
                            title: Text(
                              item['title']?.toString() ?? 'Tanpa judul',
                            ),
                            subtitle: Text(
                              hasFile
                                  ? files['original_name'].toString()
                                  : 'Item tanpa file',
                            ),
                            onChanged: hasFile
                                ? (value) => setSheetState(() {
                                    if (value == true) {
                                      selected.add(id);
                                    } else {
                                      selected.remove(id);
                                    }
                                  })
                                : null,
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
        setState(() => _selectedReplyLibraryItems = result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membuka Library: $e')));
      }
    }
  }

  Widget _buildAttachments() {
    if (_attachments.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'File dibagikan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ..._attachments.map((attachment) {
          final file = attachment['files'] is Map
              ? Map<String, dynamic>.from(attachment['files'] as Map)
              : <String, dynamic>{};
          final attachmentId = int.tryParse(attachment['id'].toString()) ?? 0;
          final isSaved = _savedAttachmentIds.contains(attachmentId);
          final status = attachment['curation_status']?.toString() ?? 'PENDING';
          final score = attachment['relevance_score'];
          final label = attachment['relevance_label']?.toString();
          final passed = status == 'PASSED';
          final isOwner =
              attachment['uploaded_by']?.toString() ==
              _supabase.auth.currentUser?.id;
          final statusColor = passed
              ? Colors.green
              : status == 'FAILED'
              ? Colors.red
              : Colors.orange;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF151B30).withValues(alpha: .60)
                  : Colors.white.withValues(alpha: .70),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF9CA9D8).withValues(alpha: .22)
                    : Colors.white.withValues(alpha: .9),
              ),
            ),
            child: ListTile(
              onTap: file['storage_path'] == null
                  ? null
                  : () async {
                      final url = await _dbHelper.getLibraryFileUrl(
                        file['storage_path'].toString(),
                      );
                      if (mounted) {
                        await openAttachmentPreview(
                          context,
                          url: url,
                          name: file['original_name']?.toString(),
                        );
                      }
                    },
              leading: const Icon(
                Icons.description_outlined,
                color: ChatatanColors.primary,
              ),
              title: Text(
                file['original_name']?.toString() ?? 'File',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status == 'PENDING'
                        ? 'Menunggu kurasi'
                        : status == 'PASSED'
                        ? 'Lolos kurasi'
                        : 'Tidak lolos kurasi',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (score != null)
                    Text(
                      'Relevansi belajar: ' +
                          score.toString() +
                          '/100' +
                          (label == null ? '' : ' · ' + label),
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .7),
                      ),
                    ),
                  if ((attachment['curation_feedback']?.toString() ?? '')
                      .isNotEmpty)
                    Text(attachment['curation_feedback'].toString()),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: isSaved
                        ? 'Tersimpan di Library'
                        : (passed ? 'Simpan ke Library' : 'Belum dapat disimpan'),
                    onPressed: passed
                        ? () => _saveAttachmentToLibrary(attachmentId)
                        : null,
                    icon: Icon(
                      // Menggunakan library_add khas simpan file
                      isSaved
                          ? Icons.library_add
                          : Icons.library_add_outlined,
                      color: isSaved
                          ? const Color(0xFF6C63FF) // Warna ungu saat tersimpan
                          : (passed ? Colors.grey : Colors.grey.withValues(alpha: .3)),
                    ),
                  ),
                  if (status == 'PENDING' && isOwner)
                    IconButton(
                      tooltip: 'Ulangi kurasi AI',
                      onPressed: () => _retryAttachmentCuration(attachmentId),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _toggleReplyLike(int index) async {
    final reply = _replies[index];
    final replyId = int.tryParse(reply['id'].toString());
    if (replyId == null) return;

    try {
      final result = await _dbHelper.toggleForumReplyLike(replyId);
      if (!mounted) return;
      setState(() {
        if (result['liked'] == true) {
          _likedReplyIds.add(replyId);
        } else {
          _likedReplyIds.remove(replyId);
        }
        _replies[index]['like_count'] = result['like_count'] ?? 0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memperbarui like: $e')));
      }
    }
  }

  void _setReplyingTo(Map<String, dynamic> reply) {
    final user = reply['users'] ?? {};
    final username = user['username'] ?? user['full_name'] ?? 'User';

    setState(() {
      _replyingTo = {'id': reply['id'], 'username': username};
    });

    _focusNode.requestFocus();
  }

  void _cancelReplying() {
    setState(() {
      _replyingTo = null;
    });
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    final userId = _supabase.auth.currentUser?.id;
    if ((text.isEmpty && _selectedReplyLibraryItems.isEmpty) ||
        userId == null) {
      return;
    }

    try {
      final Map<String, dynamic> insertData = {
        'post_id': widget.postId,
        'user_id': userId,
        'content': text.isEmpty ? 'Membagikan lampiran dari Library.' : text,
        'like_count': 0,
      };

      if (_replyingTo != null) {
        insertData['parent_reply_id'] = _replyingTo!['id'];
      }

      final createdReply = await _supabase
          .from('forum_replies')
          .insert(insertData)
          .select('id')
          .single();

      await _dbHelper.attachLibraryItemsToForumReply(
        replyId: int.parse(createdReply['id'].toString()),
        libraryItemIds: _selectedReplyLibraryItems
            .map((item) => int.tryParse(item['id'].toString()))
            .whereType<int>()
            .toList(),
      );

      final currentReplyCount = (_post?['reply_count'] as int?) ?? 0;
      await _supabase
          .from('forum_posts')
          .update({'reply_count': currentReplyCount + 1})
          .eq('id', widget.postId);

      _replyController.clear();
      setState(() => _selectedReplyLibraryItems = []);
      _cancelReplying();
      _loadPostData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengirim balasan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_post == null) {
      return const Scaffold(
        body: Center(child: Text('Postingan tidak ditemukan')),
      );
    }

    final user = _post!['users'] ?? {};
    final category = _post!['forum_categories'] ?? {};
    final categoryName = category['name'] ?? 'Umum';
    final displayName = user['full_name'] ?? user['username'] ?? 'User';
    final score =
        (_post!['like_count'] as int? ?? 0) -
        (_post!['dislike_count'] as int? ?? 0);
    final repliesCount = _replies.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Detail Forum',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0.5,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF202842), const Color(0xFF151B30)]
                            : [
                                Colors.white.withValues(alpha: .66),
                                const Color(0xFFDDE7FF).withValues(alpha: .34),
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
                          color: ChatatanColors.primary.withValues(alpha: .10),
                          blurRadius: 24,
                          offset: const Offset(0, 9),
                        ),
                      ],
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
                              backgroundImage: user['avatar_url'] != null
                                  ? NetworkImage(user['avatar_url'])
                                  : null,
                              child: user['avatar_url'] == null
                                  ? Text(
                                      displayName.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  _formatTimeAgo(_post!['created_at']),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
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
                        const SizedBox(height: 14),

                        if (_post!['title'] != null &&
                            _post!['title'].toString().isNotEmpty) ...[
                          Text(
                            _post!['title'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          _post!['content'] ?? '',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        _buildAttachments(),
                        const SizedBox(height: 16),

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
                                    ? const Color(0xFF9CA9D8).withValues(alpha: .22)
                                    : Colors.white.withValues(alpha: .9),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Vote naik',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _togglePostVote('LIKE'),
                                  icon: Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 24,
                                    color: _postVote == 'LIKE'
                                        ? const Color(0xFF6C63FF)
                                        : Colors.grey,
                                  ),
                                ),
                                Text(
                                  '$score',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _postVote == null
                                        ? Colors.grey.shade700
                                        : const Color(0xFF6C63FF),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Vote turun',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _togglePostVote('DISLIKE'),
                                  icon: Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 24,
                                    color: _postVote == 'DISLIKE'
                                        ? Colors.redAccent
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                            const SizedBox(width: 20),
                            Row(
                              children: [
                                const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$repliesCount balasan',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                _isBookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border_rounded,
                                color: _isBookmarked
                                    ? const Color(0xFF6C63FF)
                                    : Colors.grey,
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
                  Text(
                    'Balasan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _replies.length,
                    itemBuilder: (context, index) {
                      final reply = _replies[index];
                      final replyId = reply['id'];
                      final replyUser = reply['users'] ?? {};
                      final replyName =
                          replyUser['full_name'] ??
                          replyUser['username'] ??
                          'User';
                      final replyLikes = reply['like_count'] ?? 0;
                      final isReplyLiked = _likedReplyIds.contains(replyId);

                      final parentData = reply['parent'];
                      final parentUser = parentData != null
                          ? parentData['users']
                          : null;
                      final parentName = parentUser != null
                          ? (parentUser['username'] ?? parentUser['full_name'])
                          : null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    const Color(0xFF202842),
                                    const Color(0xFF151B30),
                                  ]
                                : [
                                    Colors.white.withValues(alpha: .70),
                                    const Color(
                                      0xFFDDE7FF,
                                    ).withValues(alpha: .34),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF9CA9D8).withValues(alpha: .22)
                                : Colors.white.withValues(alpha: .9),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ChatatanColors.primary.withValues(
                                alpha: .07,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF8E8E93),
                              backgroundImage: replyUser['avatar_url'] != null
                                  ? NetworkImage(replyUser['avatar_url'])
                                  : null,
                              child: replyUser['avatar_url'] == null
                                  ? Text(
                                      replyName.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        replyName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatTimeAgo(reply['created_at']),
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (parentName != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Membalas @$parentName',
                                      style: const TextStyle(
                                        color: Color(0xFF6C5CE7),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 4),
                                  Text(
                                    reply['content'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  if (reply['forum_attachments'] is List)
                                    ...List<Map<String, dynamic>>.from(
                                      reply['forum_attachments'] as List,
                                    ).map((attachment) {
                                      final file = attachment['files'] is Map
                                          ? Map<String, dynamic>.from(
                                              attachment['files'] as Map,
                                            )
                                          : <String, dynamic>{};
                                      final replyAttId = int.tryParse(attachment['id'].toString()) ?? 0;
                                      final isReplyAttSaved = _savedAttachmentIds.contains(replyAttId);

                                      return Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF151B30).withValues(alpha: .60)
                                              : Colors.white.withValues(alpha: .70),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isDark
                                                ? const Color(0xFF9CA9D8).withValues(alpha: .20)
                                                : Colors.white.withValues(alpha: .8),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              (file['mime_type']?.toString() ?? '')
                                                      .startsWith('image/')
                                                  ? Icons.image_outlined
                                                  : Icons.attach_file_rounded,
                                              size: 18,
                                              color: ChatatanColors.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: InkWell(
                                                onTap: file['storage_path'] == null
                                                    ? null
                                                    : () async {
                                                        final url = await _dbHelper.getLibraryFileUrl(
                                                          file['storage_path'].toString(),
                                                        );
                                                        if (mounted) {
                                                          await openAttachmentPreview(
                                                            context,
                                                            url: url,
                                                            name: file['original_name']?.toString(),
                                                          );
                                                        }
                                                      },
                                                child: Text(
                                                  file['original_name']?.toString() ?? 'Lampiran balasan',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    decoration: TextDecoration.underline,
                                                    color: Theme.of(context).colorScheme.onSurface,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: isReplyAttSaved
                                                  ? 'Tersimpan di Library'
                                                  : 'Simpan ke Library',
                                              visualDensity: VisualDensity.compact,
                                              onPressed: () => _saveAttachmentToLibrary(
                                                replyAttId,
                                                folderName: 'Dari Balasan Forum',
                                              ),
                                              icon: Icon(
                                                // Menggunakan library_add untuk lampiran balasan
                                                isReplyAttSaved
                                                    ? Icons.library_add
                                                    : Icons.library_add_outlined,
                                                size: 20,
                                                color: isReplyAttSaved
                                                    ? const Color(0xFF6C63FF) // Warna ungu saat tersimpan
                                                    : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  const SizedBox(height: 10),

                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () => _toggleReplyLike(index),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isReplyLiked
                                                    ? Icons.thumb_up
                                                    : Icons
                                                          .thumb_up_alt_outlined,
                                                size: 15,
                                                color: isReplyLiked
                                                    ? const Color(0xFF6C63FF)
                                                    : Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$replyLikes',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isReplyLiked
                                                      ? const Color(0xFF6C63FF)
                                                      : Colors.grey,
                                                  fontWeight: isReplyLiked
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      InkWell(
                                        onTap: () => _setReplyingTo(reply),
                                        borderRadius: BorderRadius.circular(6),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          child: Text(
                                            'Balas',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: ChatatanGlass(
                radius: 25,
                opacity: .76,
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Indikator Membalas Pesan
                    if (_replyingTo != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ChatatanColors.primary.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Membalas @${_replyingTo!['username']}',
                                style: const TextStyle(
                                  color: ChatatanColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: _cancelReplying,
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: ChatatanColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Indikator File yang Dipilih dari Library
                    if (_selectedReplyLibraryItems.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _selectedReplyLibraryItems
                              .map(
                                (item) => Chip(
                                  backgroundColor: ChatatanColors.primary
                                      .withValues(alpha: .15),
                                  deleteIconColor: ChatatanColors.primary,
                                  side: BorderSide.none,
                                  label: Text(
                                    item['title']?.toString() ?? 'File Library',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                  onDeleted: () => setState(() {
                                    _selectedReplyLibraryItems.removeWhere(
                                      (selected) =>
                                          selected['id'].toString() ==
                                          item['id'].toString(),
                                    );
                                  }),
                                ),
                              )
                              .toList(),
                        ),
                      ),

                    // Input Pesan & Tombol-tombol Aksi
                    Row(
                      children: [
                        // Tombol Lampiran (Hanya buka Library)
                        ChatatanGlass(
                          radius: 22,
                          opacity: .60,
                          padding: const EdgeInsets.all(10),
                          onTap: _pickReplyFilesFromLibrary,
                          child: const Icon(
                            Icons.attach_file_rounded,
                            color: ChatatanColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            focusNode: _focusNode,
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 1,
                            maxLines: 4,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: _replyingTo != null
                                  ? 'Balas @${_replyingTo!['username']}...'
                                  : 'Tulis balasan...',
                              hintStyle: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: .6),
                                fontSize: 14,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF151B30)
                                  : Colors.white.withValues(alpha: .54),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? const Color(
                                          0xFF9CA9D8,
                                        ).withValues(alpha: .22)
                                      : Colors.white.withValues(alpha: .78),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? const Color(
                                          0xFF9CA9D8,
                                        ).withValues(alpha: .22)
                                      : Colors.white.withValues(alpha: .78),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: const BorderSide(
                                  color: ChatatanColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        // Tombol Kirim Balasan
                        ChatatanGlass(
                          radius: 22,
                          opacity: .72,
                          padding: const EdgeInsets.all(10),
                          onTap: _sendReply,
                          child: const Icon(
                            Icons.send_rounded,
                            color: ChatatanColors.primary,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
