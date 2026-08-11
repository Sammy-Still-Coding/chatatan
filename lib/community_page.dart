import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'community_chat_page.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final DbHelper _dbHelper = DbHelper();
  
  // 0: Groups, 1: Forum, 2: Chats (default dipilih Chats)
  int _selectedTabIndex = 2; 
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat pesan: $e')),
        );
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
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF6C63FF)),
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: _getAvatarColor(username),
                              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
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
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text('Klik untuk mulai chat pribadi'),
                            trailing: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF6C63FF)),
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

  /// Membuka atau membuat percakapan pribadi
  Future<void> _openPrivateChat(String targetUserId, String title) async {
    try {
      // Tampilkan indikator loading sebentar
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final conversationId = await _dbHelper.getOrCreatePrivateConversation(targetUserId);

      if (mounted) {
        Navigator.pop(context); // Tutup loading dialog

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityChatPage(
              conversationId: conversationId,
              title: title,
            ),
          ),
        );

        _loadRecentChats(); // Refresh daftar chat saat kembali
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Tutup loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat percakapan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF), // Warna background soft lavender/putih
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
                    onTap: _showSearchUserModal,
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
                  : Center(
                      child: Text(
                        _selectedTabIndex == 0 ? 'Halaman Groups' : 'Halaman Forum',
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget Tombol Ikon Lingkaran Putih di Header
  Widget _buildIconButton({required IconData icon, required VoidCallback onTap}) {
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
              final lastMessage = chatData['last_message'];

              final title = conversation['conversation_type'] == 'PRIVATE'
                  ? (otherUser['username'] ?? 'User')
                  : (conversation['title'] ?? 'Grup Chat');

              final avatarUrl = otherUser['avatar_url'];
              final messageContent = lastMessage != null ? lastMessage['content'] ?? '' : 'Belum ada pesan';
              
              // Format Waktu
              final createdAt = lastMessage != null && lastMessage['created_at'] != null
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
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 26),
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
                style: TextStyle(fontSize: 10, color: Color(0xFF6C63FF), fontWeight: FontWeight.bold),
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
        trailing: const Text('Now', style: TextStyle(fontSize: 12, color: Colors.grey)),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fitur ChaTatan AI akan segera hadir!')),
          );
        },
      ),
    );
  }

  /// Widget Item Chat Biasa
  Widget _buildChatItem({
    required String title,
    required String lastMessage,
    required String timeStr,
    String? avatarUrl,
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
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
        trailing: Text(
          timeStr,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
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