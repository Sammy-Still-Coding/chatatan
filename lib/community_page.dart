import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'community_chat_page.dart';
import 'create_forum_modal.dart';
import 'forum_tab.dart';
import 'ai_chat_page.dart';
import 'forum_detail_page.dart';
import 'chatatan_theme.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, this.initialTabIndex = 1});

  final int initialTabIndex;

  @override
  State<CommunityPage> createState() => CommunityPageState();
}

class _UserSearchSheet extends StatefulWidget {
  const _UserSearchSheet({required this.onSelected});
  final void Function(String userId, String username) onSelected;

  @override
  State<_UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends State<_UserSearchSheet> {
  final _db = DbHelper();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  int _request = 0;

  Future<void> _search(String value) async {
    final request = ++_request;
    if (value.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await _db.searchUsers(value);
      if (mounted && request == _request) setState(() => _results = results);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .65,
          child: Column(
            children: [
              const ChatatanSheetHandle(),
              const Text(
                'Cari Orang / Mulai Chat',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                onChanged: _search,
                decoration: const InputDecoration(
                  hintText: 'Ketik nama / username...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                    ? const Center(
                        child: Text('Ketik nama teman untuk mencari.'),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (_, index) {
                          final user = _results[index];
                          final name = user['username']?.toString() ?? 'User';
                          return ChatatanGlass(
                            radius: 19,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: ChatatanColors.primary
                                    .withValues(alpha: .12),
                                child: Text(
                                  name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    color: ChatatanColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: const Text('Mulai chat pribadi'),
                              trailing: const Icon(
                                Icons.arrow_forward_rounded,
                                color: ChatatanColors.primary,
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                widget.onSelected(user['id'].toString(), name);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForumSearchSheet extends StatefulWidget {
  const _ForumSearchSheet();

  @override
  State<_ForumSearchSheet> createState() => _ForumSearchSheetState();
}

class _ForumSearchSheetState extends State<_ForumSearchSheet> {
  final _db = DbHelper();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  int _request = 0;

  Future<void> _search(String value) async {
    final request = ++_request;
    if (value.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await _db.searchForumPosts(value);
      if (mounted && request == _request) setState(() => _results = results);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .65,
          child: Column(
            children: [
              const ChatatanSheetHandle(),
              const Text(
                'Cari diskusi forum',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                onChanged: _search,
                decoration: const InputDecoration(
                  hintText: 'Cari judul atau isi diskusi...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                    ? const Center(child: Text('Masukkan kata kunci forum.'))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (_, index) {
                          final post = _results[index];
                          return ChatatanGlass(
                            radius: 19,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFEDEBFF),
                                child: Icon(
                                  Icons.forum_outlined,
                                  color: ChatatanColors.primary,
                                ),
                              ),
                              title: Text(
                                post['title']?.toString() ?? 'Diskusi',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                post['content']?.toString() ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                final id = int.tryParse(post['id'].toString());
                                if (id == null) return;
                                Navigator.pop(context);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ForumDetailPage(postId: id),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return SizedBox(
      width: 24,
      height: 24,
      child: Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFF6C63FF),
          shape: BoxShape.circle,
        ),
        child: FittedBox(
          child: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class CommunityPageState extends State<CommunityPage>
    with SingleTickerProviderStateMixin {
  final DbHelper _dbHelper = DbHelper();

  // 0: Groups, 1: Forum, 2: Chats. Forum menjadi halaman Community default.
  late int _selectedTabIndex;
  bool _isLoading = false;
  List<Map<String, dynamic>> _recentChats = [];
  List<Map<String, dynamic>> _groups = [];
  Map<int, int> _unreadCounts = {};
  late final AnimationController _tabBubbleController;
  late Animation<double> _tabIndexAnimation;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex.clamp(0, 2);
    _tabBubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _tabIndexAnimation = AlwaysStoppedAnimation(_selectedTabIndex.toDouble());
    _loadRecentChats();
  }

  @override
  void dispose() {
    _tabBubbleController.dispose();
    super.dispose();
  }

  void selectTab(int index) {
    final tab = index.clamp(0, 2);
    if (_selectedTabIndex == tab) return;
    final fromValue = _tabIndexAnimation.value;
    setState(() => _selectedTabIndex = tab);
    _tabIndexAnimation = Tween<double>(begin: fromValue, end: tab.toDouble())
        .animate(
          CurvedAnimation(
            parent: _tabBubbleController,
            curve: Curves.easeOutCubic,
          ),
        );
    _tabBubbleController.forward(from: 0);
    if (tab == 0 || tab == 2) _loadRecentChats();
  }

  /// Mengambil daftar percakapan terbaru
  Future<void> _loadRecentChats() async {
    setState(() => _isLoading = true);
    try {
      // Unread badges are optional until the matching SQL migration has been
      // run. A missing RPC must never hide a user's existing conversations.
      final chats = await _dbHelper.getRecentChats(limit: 20);
      List<Map<String, dynamic>> groups = [];
      try {
        groups = await _dbHelper.getGroupConversations();
      } catch (_) {
        // Chat data still remains available if a group-specific policy fails.
      }
      Map<int, int> unreadCounts = {};
      try {
        unreadCounts = await _dbHelper.getConversationUnreadCounts();
      } catch (_) {
        // The normal chat and group lists remain usable without badges.
      }
      setState(() {
        _recentChats = chats;
        _groups = groups;
        _unreadCounts = unreadCounts;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat pesan: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Menampilkan BottomSheet untuk mencari orang berdasarkan Username
  void _showSearchUserModal() {
    showChatatanGlassSheet(
      context: context,
      builder: (_) => _UserSearchSheet(
        onSelected: (userId, username) {
          _openPrivateChat(userId, username);
        },
      ),
    );
  }

  void _showForumSearch() {
    showChatatanGlassSheet(
      context: context,
      builder: (_) => const _ForumSearchSheet(),
    );
  }

  void _openCreateForumModal() async {
    // Hanya jalankan jika tab aktif saat ini adalah Forum (misal index 1)
    if (_selectedTabIndex == 1) {
      // Sesuaikan '_selectedTabIndex' dengan nama variabel index tab di kodemu
      final isCreated = await showChatatanGlassSheet<bool>(
        context: context,
        builder: (_) => const CreateForumModal(),
      );

      // Refresh halaman jika user selesai membuat postingan
      if (isCreated == true) {
        setState(() {});
      }
    }
  }

  void _showCreateGroupModal() {
    final TextEditingController groupNameController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    List<Map<String, dynamic>> selectedUsers = [];

    showChatatanGlassSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 0,
                left: 16,
                right: 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ChatatanSheetHandle(),
                    const Text(
                      'Buat Grup Baru',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Input Nama Grup
                    TextField(
                      controller: groupNameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Grup',
                        hintText: 'Contoh: Study Group OOP',
                        prefixIcon: const Icon(Icons.groups_2_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Chip Anggota Terpilih
                    if (selectedUsers.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        children: selectedUsers.map((u) {
                          return Chip(
                            label: Text(u['username'] ?? 'User'),
                            onDeleted: () {
                              setModalState(() {
                                selectedUsers.removeWhere(
                                  (item) => item['id'] == u['id'],
                                );
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Input Cari User untuk Ditambah ke Grup
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari & pilih anggota...',
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (val) async {
                        if (val.trim().isEmpty) {
                          setModalState(() => searchResults = []);
                          return;
                        }
                        final results = await _dbHelper.searchUsers(val);
                        setModalState(() => searchResults = results);
                      },
                    ),
                    const SizedBox(height: 8),

                    // List Hasil Pencarian
                    Expanded(
                      child: ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final u = searchResults[index];
                          final isSelected = selectedUsers.any(
                            (item) => item['id'] == u['id'],
                          );
                          return ListTile(
                            title: Text(u['username'] ?? 'User'),
                            trailing: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: isSelected ? Colors.green : Colors.grey,
                            ),
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  selectedUsers.removeWhere(
                                    (item) => item['id'] == u['id'],
                                  );
                                } else {
                                  selectedUsers.add(u);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),

                    // Tombol Submit Buat Grup
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final title = groupNameController.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nama grup tidak boleh kosong'),
                              ),
                            );
                            return;
                          }

                          final selectedIds = selectedUsers
                              .map((u) => u['id'].toString())
                              .toList();

                          Navigator.pop(context); // Tutup modal

                          try {
                            final convId = await _dbHelper
                                .createGroupConversation(
                                  title: title,
                                  selectedUserIds: selectedIds,
                                );

                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CommunityChatPage(
                                    conversationId: convId,
                                    title: title,
                                    isGroup: true,
                                  ),
                                ),
                              );
                              setState(() {}); // Refresh UI
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal membuat grup: $e'),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.group_add_rounded),
                        label: const Text(
                          'Buat Grup',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Membuka atau membuat percakapan pribadi
  Future<void> _openPrivateChat(String targetUserId, String title) async {
    try {
      // Tampilkan indikator loading sebentar
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final conversationId = await _dbHelper.getOrCreatePrivateConversation(
        targetUserId,
      );

      if (mounted) {
        Navigator.pop(context); // Tutup loading dialog

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CommunityChatPage(conversationId: conversationId, title: title),
          ),
        );

        _loadRecentChats(); // Refresh daftar chat saat kembali
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Tutup loading dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membuat percakapan: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatatanColors.background,
      body: ChatatanAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ================= HEADER & SEARCH/ADD BUTTONS =================
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Community',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: ChatatanColors.ink,
                      ),
                    ),
                    const Spacer(),
                    // Tombol Search
                    _buildIconButton(
                      icon: Icons.search,
                      onTap: _selectedTabIndex == 1
                          ? _showForumSearch
                          : _showSearchUserModal,
                    ),
                    const SizedBox(width: 8),
                    // Tombol Plus (+) untuk cari/buat chat baru
                    _buildIconButton(
                      icon: Icons.add,
                      onTap: () {
                        if (_selectedTabIndex == 2) {
                          _showSearchUserModal(); // Jika di tab Chats -> Cari User Private
                        } else if (_selectedTabIndex == 0) {
                          _showCreateGroupModal(); // Jika di tab Groups -> Buat Grup Baru
                        } else if (_selectedTabIndex == 1) {
                          _openCreateForumModal(); // <-- TAMBAHKAN BARIS INI (Jika di tab Forum)
                        }
                      },
                    ),
                  ],
                ),
              ),

              // ================= TAB SWITCHER (Groups | Forum | Chats) =================
              _buildTabSwitcher(),

              const SizedBox(height: 12),

              // ================= DAFTAR CHAT / KONTEN TAB =================
              Expanded(
                child: _selectedTabIndex == 2
                    ? _buildChatsList()
                    : _selectedTabIndex == 0
                    ? _buildGroupsList() // Tampilkan daftar grup
                    : const ForumTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget Tombol Ikon Lingkaran Putih di Header
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: .64),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: .92)),
      ),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: const Color(0xFF6C63FF), size: 22),
        ),
      ),
    );
  }

  Widget _buildGroupsList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_groups.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada grup.\nTekan tombol + untuk membuat grup baru!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRecentChats,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _groups.length,
        itemBuilder: (context, index) {
          final group = _groups[index];
          final rawTitle = group['title']?.toString().trim() ?? '';
          final title = rawTitle.isEmpty
              ? 'Grup #${group['id'] ?? index + 1}'
              : rawTitle;
          final lastMessage = group['last_message'];
          final messageType = lastMessage is Map
              ? lastMessage['message_type']?.toString()
              : null;
          final preview = lastMessage is Map
              ? messageType == 'IMAGE'
                    ? '📷 Foto'
                    : messageType == 'FILE'
                    ? '📎 Dokumen'
                    : lastMessage['content']?.toString() ?? 'Belum ada pesan'
              : 'Belum ada pesan';

          return ChatatanGlass(
            margin: const EdgeInsets.only(bottom: 8),
            radius: 20,
            opacity: .66,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFEEECFF),
                backgroundImage:
                    group['avatar_url']?.toString().trim().isNotEmpty == true
                    ? NetworkImage(group['avatar_url'].toString())
                    : null,
                child: group['avatar_url']?.toString().trim().isNotEmpty == true
                    ? null
                    : const Icon(Icons.groups, color: Color(0xFF6C63FF)),
              ),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: _UnreadBadge(
                count:
                    _unreadCounts[int.tryParse(group['id'].toString()) ?? -1] ??
                    0,
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityChatPage(
                      conversationId: group['id'],
                      title: title,
                      isGroup: true,
                    ),
                  ),
                );
                if (mounted) _loadRecentChats();
              },
            ),
          );
        },
      ),
    );
  }

  /// Widget Tab Bar Switcher Custom
  Widget _buildTabSwitcher() {
    const labels = ['Groups', 'Forum', 'Chats'];
    const switcherHeight = 50.0;
    return ChatatanGlass(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(5),
      radius: 28,
      opacity: .66,
      blur: 26,
      child: SizedBox(
        height: switcherHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = constraints.maxWidth / labels.length;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: _tabBubbleController,
                  builder: (context, _) {
                    final t = _tabBubbleController.value.clamp(0.0, 1.0);
                    final stretch = math.sin(math.pi * t);
                    final centerX =
                        segmentWidth * (_tabIndexAnimation.value + .5);
                    final bubbleWidth = segmentWidth * .94 + (26 * stretch);
                    final bubbleHeight = switcherHeight * .86 - (10 * stretch);
                    return Positioned(
                      left: centerX - bubbleWidth / 2,
                      top: (switcherHeight - bubbleHeight) / 2,
                      width: bubbleWidth,
                      height: bubbleHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(bubbleHeight / 2),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF7168F6).withValues(alpha: .76),
                              const Color(0xFF9D8AF5).withValues(alpha: .58),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .56),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ChatatanColors.primary.withValues(
                                alpha: .18,
                              ),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: List.generate(labels.length, (index) {
                    final selected = _selectedTabIndex == index;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: selected,
                        label: labels[index],
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => selectTab(index),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOut,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : ChatatanColors.muted,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 14,
                                shadows: selected
                                    ? const [
                                        Shadow(
                                          color: Color(0x55000000),
                                          blurRadius: 5,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(labels[index]),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Widget List Chat
  Widget _buildChatsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadRecentChats,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // 1. Pinned Item: ChaTatan AI
          _buildAiChatItem(),

          const SizedBox(height: 8),

          // 2. Daftar Chat Pengguna Lain
          if (_recentChats.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'Belum ada obrolan.\nTekan tombol + untuk memulai chat!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, height: 1.5),
                ),
              ),
            )
          else
            ..._recentChats.map((chatData) {
              final conversation = chatData['conversation'] ?? {};
              final otherUser = chatData['other_user'] ?? {};
              final presence = chatData['other_presence'] ?? {};
              final settings = chatData['settings'] ?? {};
              final lastMessage = chatData['last_message'];

              final defaultTitle =
                  conversation['conversation_type'] == 'PRIVATE'
                  ? (otherUser['username'] ?? 'User')
                  : (conversation['title'] ?? 'Grup Chat');
              final title =
                  settings['nickname']?.toString().trim().isNotEmpty == true
                  ? settings['nickname'].toString()
                  : defaultTitle;

              final avatarUrl = otherUser['avatar_url'];
              final isOnline = presence['is_online'] == true;
              final seen = DateTime.tryParse(
                presence['last_seen_at']?.toString() ?? '',
              )?.toLocal();
              final messageContent = lastMessage != null
                  ? lastMessage['content'] ?? ''
                  : 'Belum ada pesan';

              // Format Waktu
              final createdAt =
                  lastMessage != null && lastMessage['created_at'] != null
                  ? DateTime.tryParse(lastMessage['created_at'])
                  : null;
              final localCreatedAt = createdAt?.toLocal();
              final timeStr = localCreatedAt != null
                  ? "${localCreatedAt.hour.toString().padLeft(2, '0')}:${localCreatedAt.minute.toString().padLeft(2, '0')}"
                  : '';

              return _buildChatItem(
                title: title,
                lastMessage: messageContent,
                timeStr: timeStr,
                avatarUrl: avatarUrl,
                isOnline: isOnline,
                lastSeen: seen == null ? null : _formatLastSeen(seen),
                isPinned: settings['is_pinned'] == true,
                unreadCount:
                    _unreadCounts[int.tryParse(conversation['id'].toString()) ??
                        -1] ??
                    0,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityChatPage(
                        conversationId: conversation['id'],
                        title: title,
                      ),
                    ),
                  );
                  _loadRecentChats();
                },
              );
            }),
        ],
      ),
    );
  }

  /// Widget khusus Item Chat AI (ChaTatan AI)
  Widget _buildAiChatItem() {
    return ChatatanGlass(
      radius: 20,
      opacity: .66,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF6C63FF),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 26,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            const Text(
              'ChaTatan AI',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.push_pin, size: 14, color: Color(0xFF6C63FF)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEEECFF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'AI',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF6C63FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: const Text(
          'Halo! Ada yang bisa aku bantu hari ini?',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        trailing: const Text(
          'Now',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiChatPage()),
        ),
      ),
    );
  }

  /// Widget Item Chat Biasa
  Widget _buildChatItem({
    required String title,
    required String lastMessage,
    required String timeStr,
    String? avatarUrl,
    bool isOnline = false,
    String? lastSeen,
    bool isPinned = false,
    int unreadCount = 0,
    required VoidCallback onTap,
  }) {
    return ChatatanGlass(
      margin: const EdgeInsets.only(bottom: 8),
      radius: 20,
      opacity: .66,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _getAvatarColor(title),
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      _getInitials(title),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            if (isOnline)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            Text(
              isOnline ? 'Online' : (lastSeen ?? 'Offline'),
              style: TextStyle(
                fontSize: 11,
                color: isOnline ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isPinned)
              const Icon(
                Icons.push_pin_outlined,
                size: 15,
                color: Color(0xFF6C63FF),
              ),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 12,
                color: unreadCount > 0 ? const Color(0xFF6C63FF) : Colors.grey,
                fontWeight: unreadCount > 0
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(height: 4),
              _UnreadBadge(count: unreadCount),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  /// Helper membuat warna avatar bervariasi otomatis berdasarkan nama
  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF7C4DFF),
      const Color(0xFF42A5F5),
      const Color(0xFF26A69A),
      const Color(0xFFFF7043),
      const Color(0xFFEC407A),
      const Color(0xFFAB47BC),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  String _formatLastSeen(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'Terakhir aktif baru saja';
    if (diff.inHours < 1) return 'Terakhir aktif ${diff.inMinutes} mnt lalu';
    if (diff.inDays < 1) return 'Terakhir aktif ${diff.inHours} jam lalu';
    return 'Terakhir aktif ${diff.inDays} hari lalu';
  }

  /// Helper mendapatkan inisial 2 huruf (contoh: "Ivan Pamungkas" -> "IP")
  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}
