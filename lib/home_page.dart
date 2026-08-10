import 'package:flutter/material.dart';

import 'db_helper.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DbHelper _dbHelper = DbHelper();
  
  List<Map<String, dynamic>> _recentChats = [];
  List<Map<String, dynamic>> _recentForums = [];

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _gamification;
  Map<String, dynamic>? _pet;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  // ============================================================
  // loadHome
  // ============================================================

  Future<void> _loadHome() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _dbHelper.getHomeData();

      final recentChats = await _dbHelper.getRecentChats(
        limit: 3,
      );

      final recentForums = await _dbHelper.getRecentForums(
        limit: 3,
      );

      if (!mounted) return;

      setState(() {
        _profile = data['profile'];
        _gamification = data['gamification'];
        _pet = data['pet'];

        _recentChats = recentChats;
        _recentForums = recentForums;

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
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    await _dbHelper.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _getUsername() {
    final username = _profile?['username'];

    if (username != null &&
        username.toString().trim().isNotEmpty) {
      return username.toString();
    }

    final metadata =
        _dbHelper.currentUser?.userMetadata;

    final metadataUsername = metadata?['username'];

    if (metadataUsername != null) {
      return metadataUsername.toString();
    }

    return 'User';
  }

  int _getInt(String key) {
    final value = _gamification?[key];

    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  String _getPetName() {
    return _pet?['name']?.toString() ?? 'Your Pet';
  }

  String _getPetDescription() {
    return _pet?['description']?.toString() ??
        'Keep learning and take care of your pet!';
  }

  String? _getPetImage() {
    final image = _pet?['image_url'];

    if (image == null) {
      return null;
    }

    if (image.toString().trim().isEmpty) {
      return null;
    }

    return image.toString();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,

        title: const Text(
          'ChaTatan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadHome,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.black87,
            ),
          ),

          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.black87,
            ),
          ),
        ],
      ),

      body: _buildBody(),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _loadHome,

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.fromLTRB(
          20,
          8,
          20,
          32,
        ),

        children: [
          _buildGreeting(),

          const SizedBox(height: 24),

          _buildStreakCard(),

          const SizedBox(height: 16),

          _buildPetCard(),

          const SizedBox(height: 16),

          _buildStatsCard(),

          const SizedBox(height: 24),

          _buildRecentChats(),

          const SizedBox(height: 24),

          _buildCommunity(),

          const SizedBox(height: 24),

          _buildDatabaseStatus(), 

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ============================================================
  // GREETING
  // ============================================================

  Widget _buildGreeting() {
    final username = _getUsername();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, $username 👋',
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Ready to learn something today?',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STREAK CARD
  // ============================================================

  Widget _buildStreakCard() {
    final streak = _getInt('current_streak');
    final longestStreak = _getInt('longest_streak');

    return Container(
      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: BorderRadius.circular(28),
      ),

      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,

            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),

            child: const Center(
              child: Text(
                '🔥',
                style: TextStyle(
                  fontSize: 32,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Learning Streak',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  '$streak days',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  'Best: $longestStreak days',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PET CARD
  // ============================================================

  Widget _buildPetCard() {
    final petLevel = _getInt('pet_level');
    final petName = _getPetName();
    final petDescription = _getPetDescription();
    final petImage = _getPetImage();

    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 82,
            height: 82,

            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(22),
            ),

            child: petImage != null
                ? ClipRRect(
                    borderRadius:
                        BorderRadius.circular(22),

                    child: Image.network(
                      petImage,
                      fit: BoxFit.cover,

                      errorBuilder:
                          (context, error, stackTrace) {
                        return const Icon(
                          Icons.pets_rounded,
                          size: 40,
                          color: Colors.deepPurple,
                        );
                      },
                    ),
                  )
                : const Icon(
                    Icons.pets_rounded,
                    size: 40,
                    color: Colors.deepPurple,
                  ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  petName,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  petDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),

                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),

                  child: Text(
                    'Level $petLevel',
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATS CARD
  // ============================================================

  Widget _buildStatsCard() {
    final points = _getInt('total_points');
    final tokens = _getInt('token_balance');
    final level = _getInt('current_level');

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.star_rounded,
            title: 'Points',
            value: points.toString(),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _StatCard(
            icon: Icons.token_rounded,
            title: 'Tokens',
            value: tokens.toString(),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _StatCard(
            icon: Icons.workspace_premium_rounded,
            title: 'Level',
            value: level.toString(),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // RECENT CHAT SECTION
  // ============================================================

  Widget _buildRecentChats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Chat',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            TextButton(
              onPressed: () {
                // Nanti buka Chat Room
              },
              child: const Text('See all'),
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (_recentChats.isEmpty)
          _buildEmptyChat()
        else
          ..._recentChats.map(
            (chat) => _buildChatItem(chat),
          ),
      ],
    );
  }
  
// ============================================================
// EMPTY CHAT
// ============================================================

  Widget _buildEmptyChat() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),

      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,

            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.deepPurple,
              size: 28,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'No recent chats',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Start a conversation with your friends or AI.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHAT ITEM
  // ============================================================

  Widget _buildChatItem(
    Map<String, dynamic> chat,
  ) {
    final conversation =
        chat['conversation'] as Map<String, dynamic>?;

    final lastMessage =
        chat['last_message'] as Map<String, dynamic>?;

    final otherUser =
        chat['other_user'] as Map<String, dynamic>?;

    final type =
        conversation?['conversation_type']?.toString() ??
            'PRIVATE';

    String title;
    IconData icon;

    if (type == 'AI') {
      title = conversation?['title']?.toString() ??
          'AI Assistant';

      icon = Icons.auto_awesome_rounded;
    } else if (type == 'GROUP') {
      title = conversation?['title']?.toString() ??
          'Group Chat';

      icon = Icons.groups_rounded;
    } else {
      title = otherUser?['username']?.toString() ??
          conversation?['title']?.toString() ??
          'Private Chat';

      icon = Icons.person_rounded;
    }

    final messageType =
        lastMessage?['message_type']?.toString() ??
            'TEXT';

    final content =
        lastMessage?['content']?.toString() ?? '';

    String preview;

    switch (messageType) {
      case 'IMAGE':
        preview = '📷 Image';

        break;

      case 'FILE':
        preview = '📎 File';

        break;

      case 'NOTE':
        preview = '📝 Note';

        break;

      case 'LEARNING_CARD':
        preview = '📚 Learning Card';

        break;

      default:
        preview = content.isEmpty
            ? 'No messages yet'
            : content;
    }

    final avatarUrl =
        otherUser?['avatar_url']?.toString();

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius: BorderRadius.circular(20),

          onTap: () {
            // Nanti diarahkan ke ChatRoomPage
            //
            // Navigator.push(...)
          },

          child: Padding(
            padding: const EdgeInsets.all(14),

            child: Row(
              children: [
                // AVATAR
                Container(
                  width: 52,
                  height: 52,

                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    shape: BoxShape.circle,
                  ),

                  child: avatarUrl != null &&
                          avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,

                            errorBuilder:
                                (context, error, stackTrace) {
                              return Icon(
                                icon,
                                color: Colors.deepPurple,
                              );
                            },
                          ),
                        )
                      : Icon(
                          icon,
                          color: Colors.deepPurple,
                        ),
                ),

                const SizedBox(width: 14),

                // CHAT INFO
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // TIME
                Text(
                  _formatChatTime(
                    lastMessage?['created_at'],
                  ),

                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _formatChatTime(dynamic value) {
    if (value == null) {
      return '';
    }

    final date = DateTime.tryParse(
      value.toString(),
    );

    if (date == null) {
      return '';
    }

    final now = DateTime.now();

    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }

    return '${date.day}/${date.month}';
  }

  // ============================================================
  // DATABASE STATUS
  // ============================================================

  Widget _buildDatabaseStatus() {
    final user = _dbHelper.currentUser;

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Text(
            'Supabase Connection',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          _InfoRow(
            label: 'Auth',
            value: user != null
                ? 'Connected ✓'
                : 'Not connected',
          ),

          const SizedBox(height: 8),

          _InfoRow(
            label: 'Profile',
            value: _profile != null
                ? 'Loaded ✓'
                : 'Not found',
          ),

          const SizedBox(height: 8),

          _InfoRow(
            label: 'Gamification',
            value: _gamification != null
                ? 'Loaded ✓'
                : 'Not found',
          ),

          const SizedBox(height: 8),

          _InfoRow(
            label: 'Pet',
            value: _pet != null
                ? 'Loaded ✓'
                : 'Not assigned',
          ),
        ],
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
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: Colors.redAccent,
            ),

            const SizedBox(height: 16),

            const Text(
              'Gagal mengambil data Home',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _loadHome,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COMMUNITY SECTION 
  // ============================================================

    Widget _buildCommunity() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Community',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              TextButton(
                onPressed: () {
                  // Nanti menuju CommunityPage
                },
                child: const Text('See all'),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (_recentForums.isEmpty)
            _buildEmptyForum()
          else
            ..._recentForums.map(
              (forum) => _buildForumItem(forum),
            ),
        ],
      );
    }

    // ============================================================
    // EMPTY FORUM
    // ============================================================

    Widget _buildEmptyForum() {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),

        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,

              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                shape: BoxShape.circle,
              ),

              child: const Icon(
                Icons.forum_outlined,
                color: Colors.deepPurple,
                size: 28,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'No community posts yet',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              'Be the first to share something with the community.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

  Widget _buildForumItem(
    Map<String, dynamic> forum,
  ) {
    final title =
        forum['title']?.toString() ?? 'Untitled';

    final content =
        forum['content']?.toString() ?? '';

    final likes =
        forum['like_count'] ?? 0;

    final dislikes =
        forum['dislike_count'] ?? 0;

    final replies =
        forum['reply_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius: BorderRadius.circular(20),

          onTap: () {
            // Nanti:
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(
            //     builder: (_) => ForumDetailPage(
            //       forumId: forum['id'],
            //     ),
            //   ),
            // );
          },

          child: Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),

                      child: const Text(
                        'Community',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const Spacer(),

                    Text(
                      _formatChatTime(
                        forum['created_at'],
                      ),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                if (content.isNotEmpty) ...[
                  const SizedBox(height: 5),

                  Text(
                    content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                Row(
                  children: [
                    const Icon(
                      Icons.thumb_up_outlined,
                      size: 16,
                      color: Colors.grey,
                    ),

                    const SizedBox(width: 4),

                    Text(
                      likes.toString(),
                      style: const TextStyle(
                        fontSize: 11,
                      ),
                    ),

                    const SizedBox(width: 14),

                    const Icon(
                      Icons.thumb_down_outlined,
                      size: 16,
                      color: Colors.grey,
                    ),

                    const SizedBox(width: 4),

                    Text(
                      dislikes.toString(),
                      style: const TextStyle(
                        fontSize: 11,
                      ),
                    ),

                    const SizedBox(width: 14),

                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                      color: Colors.grey,
                    ),

                    const SizedBox(width: 4),

                    Text(
                      '$replies replies',
                      style: const TextStyle(
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

// ============================================================
// STAT CARD
// ============================================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 18,
        horizontal: 10,
      ),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.deepPurple,
            size: 24,
          ),

          const SizedBox(height: 8),

          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// INFO ROW
// ============================================================

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ),

        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}