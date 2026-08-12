import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'community_chat_page.dart';
import 'create_forum_modal.dart';
import 'forum_tab.dart';
import 'ai_chat_page.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final DbHelper _dbHelper = DbHelper();

  // 0: Groups, 1: Forum, 2: Chats. Forum menjadi halaman Community default.
  int _selectedTabIndex = 1;
  bool _isLoading = false;
  List<Map<String, dynamic>> _recentChats = [];

  @override
  void initState() {
    super.initState();
    _loadRecentChats();
  }

  /// Mengambil daftar percakapan terbaru
  Future<void> _loadRecentChats() async {
    setState(() => _isLoading = true);
    try {
      final chats = await _dbHelper.getRecentChats(limit: 20);
      setState(() {
        _recentChats = chats;
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        List<Map<String, dynamic>> searchResults = [];
        bool isSearching = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 20,
                left: 16,
                right: 16,
              ),
              height: MediaQuery.of(context).size.height * 0.65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cari Orang / Mulai Chat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Ketik nama / username...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF6C63FF),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) async {
                      if (val.trim().isEmpty) {
                        setModalState(() => searchResults = []);
                        return;
                      }
                      setModalState(() => isSearching = true);
                      final results = await _dbHelper.searchUsers(val);
                      setModalState(() {
                        searchResults = results;
                        isSearching = false;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (isSearching)
                    const Center(child: CircularProgressIndicator())
                  else if (searchResults.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Ketik nama teman untuk mencari.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final targetUser = searchResults[index];
                          final username = targetUser['username'] ?? 'User';
                          final avatarUrl = targetUser['avatar_url'];

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: _getAvatarColor(username),
                              backgroundImage: avatarUrl != null
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl == null
                                  ? Text(
                                      _getInitials(username),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: const Text(
                              'Klik untuk mulai chat pribadi',
                            ),
                            trailing: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Color(0xFF6C63FF),
                            ),
                            onTap: () {
                              Navigator.pop(context); // Tutup modal
                              _openPrivateChat(targetUser['id'], username);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openCreateForumModal() async {
    // Hanya jalankan jika tab aktif saat ini adalah Forum (misal index 1)
    if (_selectedTabIndex == 1) {
      // Sesuaikan '_selectedTabIndex' dengan nama variabel index tab di kodemu
      final isCreated = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 20,
                left: 16,
                right: 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
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
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
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
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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
                        child: const Text(
                          'Buat Grup',
                          style: TextStyle(color: Colors.white, fontSize: 16),
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
      backgroundColor: const Color(
        0xFFF5F6FF,
      ), // Warna background soft lavender/putih
      body: SafeArea(
        child: Column(
          children: [
            // ================= HEADER & SEARCH/ADD BUTTONS =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Community 🌍',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F1D42),
                    ),
                  ),
                  const Spacer(),
                  // Tombol Search
                  _buildIconButton(
                    icon: Icons.search,
                    onTap: _showSearchUserModal,
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
    );
  }

  /// Widget Tombol Ikon Lingkaran Putih di Header
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: Colors.black12,
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
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _dbHelper.getGroupConversations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = snapshot.data ?? [];

        if (groups.isEmpty) {
          return const Center(
            child: Text(
              'Belum ada grup.\nTekan tombol + untuk membuat grup baru!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final memberCount =
                (group['conversation_members'] as List?)?.first['count'] ?? 1;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFEEECFF),
                  child: const Icon(Icons.groups, color: Color(0xFF6C63FF)),
                ),
                title: Text(
                  group['title'] ?? 'Grup',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('$memberCount members'),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityChatPage(
                        conversationId: group['id'],
                        title: group['title'] ?? 'Grup',
                        isGroup: true,
                      ),
                    ),
                  );
                  if (mounted) setState(() {});
                },
              ),
            );
          },
        );
      },
    );
  }

  /// Widget Tab Bar Switcher Custom
  Widget _buildTabSwitcher() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _buildTabItem('Groups', 0),
          _buildTabItem('Forum', 1),
          _buildTabItem('Chats', 2),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
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
              final messageContent = lastMessage != null
                  ? lastMessage['content'] ?? ''
                  : 'Belum ada pesan';

              // Format Waktu
              final createdAt =
                  lastMessage != null && lastMessage['created_at'] != null
                  ? DateTime.tryParse(lastMessage['created_at'])
                  : null;
              final timeStr = createdAt != null
                  ? "${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}"
                  : '';

              return _buildChatItem(
                title: title,
                lastMessage: messageContent,
                timeStr: timeStr,
                avatarUrl: avatarUrl,
                isPinned: settings['is_pinned'] == true,
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
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    bool isPinned = false,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: _getAvatarColor(title),
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
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
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
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
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
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
