import 'package:flutter/material.dart';
import 'db_helper.dart'; // 1. Pastikan path import ini sesuai lokasi db_helper.dart kamu

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // 2. Inisialisasi DbHelper
  final DbHelper _dbHelper = DbHelper();
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FF),
      body: SafeArea(
        // 3. Gunakan FutureBuilder di body untuk mengambil data async dari Supabase
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _dbHelper.getFullProfileData(),
          builder: (context, snapshot) {
            // Loading State
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Error / Empty State
            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: Text('Gagal memuat data profil.'));
            }

            // Extract Data dari Supabase
            final data = snapshot.data!;
            final profile = data['profile'] ?? {};
            final gamification = data['gamification'] ?? {};

            final name = profile['username'] ?? profile['name'] ?? 'Pengguna';
            final university = profile['university'] ?? 'Universitas Bina Nusantara';
            final major = profile['major'] ?? 'Informatika';
            final streak = gamification['streak_count'] ?? gamification['streak'] ?? 0;
            final tokens = gamification['tokens'] ?? 0;
            final rank = gamification['rank'] != null ? '#${gamification['rank']}' : '-';
            final totalNotes = data['total_notes'] ?? 0;
            final discussions = data['total_discussions'] ?? 0;
            final xpPoints = gamification['xp_points'] ?? gamification['xp'] ?? 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Card (Nama, Campus, Mini Stats)
                  _buildHeaderCard(name, university, major, streak, tokens, rank),
                  const SizedBox(height: 20),

                  // 2. Stat Summary Cards (Notes, Discussions, XP)
                  _buildStatSummary(totalNotes, discussions, xpPoints),
                  const SizedBox(height: 24),

                  // 3. Achievements Section
                  const Text(
                    '🏅 Achievements',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1B3E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildAchievementsGrid(data['achievements'] as List),
                  const SizedBox(height: 24),

                  // 4. Settings Section
                  const Text(
                    '⚙️ Settings',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1B3E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSettingsList(),
                  const SizedBox(height: 20),

                  // 5. Logout Button
                  _buildLogoutButton(),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- HELPER METHODS & UI COMPONENTS ---

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'U';
    List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Widget _buildHeaderCard(
    String name,
    String university,
    String major,
    int streak,
    int tokens,
    String rank,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF5B6CFF), Color(0xFF8D6BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B6CFF).withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.25),
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _getInitials(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 16,
                    color: Color(0xFF5B6CFF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_outlined,
                size: 15,
                color: Colors.white.withOpacity(0.8),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '$university · $major',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniStat('🔥', '$streak', 'Streak'),
              _buildMiniStat('⭐', '$tokens', 'Tokens'),
              _buildMiniStat('🏆', rank, 'Rank'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String emoji, String val, String label) {
    return Column(
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              val,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStatSummary(int totalNotes, int discussions, int xpPoints) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard('$totalNotes', 'Total Notes', const Color(0xFF5B6CFF)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard('$discussions', 'Discussions', const Color(0xFF8D6BFF)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard('$xpPoints', 'XP Points', const Color(0xFF34D399)),
        ),
      ],
    );
  }

  Widget _buildStatCard(String number, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B6CFF).withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            number,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsGrid(List achievementsFromDb) {
    // Default list jika database achievements masih kosong
    final defaultAchievements = [
      {'icon': '🔥', 'title': '7-Day Streak', 'is_locked': true, 'bg': const Color(0xFFFFB86C)},
      {'icon': '📚', 'title': '100 Notes', 'is_locked': true, 'bg': const Color(0xFF5B6CFF)},
      {'icon': '🏆', 'title': 'Top 3', 'is_locked': true, 'bg': const Color(0xFFFFD700)},
      {'icon': '🎯', 'title': 'Quiz Master', 'is_locked': true, 'bg': const Color(0xFF5BE39D)},
      {'icon': '💬', 'title': 'Helper', 'is_locked': true, 'bg': const Color(0xFF8D6BFF)},
      {'icon': '⚡', 'title': 'Speed Learner', 'is_locked': true, 'bg': const Color(0xFF69D2FF)},
    ];

    final items = achievementsFromDb.isNotEmpty ? achievementsFromDb : defaultAchievements;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final bool isLocked = item['is_locked'] ?? item['locked'] ?? true;
        final Color bgColor = (item['bg'] is Color) ? item['bg'] : const Color(0xFF5B6CFF);

        return Opacity(
          opacity: isLocked ? 0.45 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5B6CFF).withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bgColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      item['icon'] as String? ?? '🏆',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item['title'] as String? ?? 'Badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF1A1B3E),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isLocked) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'Locked',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 9,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B6CFF).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingItem(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            trailing: SizedBox(
              height: 24,
              child: Switch(
                value: _isDarkMode,
                onChanged: (val) {
                  setState(() {
                    _isDarkMode = val;
                  });
                },
                activeColor: const Color(0xFF5B6CFF),
              ),
            ),
          ),
          _divider(),
          _buildSettingItem(
            icon: Icons.notifications_none_rounded,
            title: 'Notifikasi',
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF6B7280), size: 20),
            onTap: () {},
          ),
          _divider(),
          _buildSettingItem(
            icon: Icons.lock_outline_rounded,
            title: 'Privacy & Keamanan',
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF6B7280), size: 20),
            onTap: () {},
          ),
          _divider(),
          _buildSettingItem(
            icon: Icons.language_rounded,
            title: 'Bahasa',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Indonesia',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, color: Color(0xFF6B7280), size: 20),
              ],
            ),
            onTap: () {},
          ),
          _divider(),
          _buildSettingItem(
            icon: Icons.help_outline_rounded,
            title: 'Help Center',
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF6B7280), size: 20),
            onTap: () {},
          ),
          _divider(),
          _buildSettingItem(
            icon: Icons.star_outline_rounded,
            title: 'Rate ChaTatan',
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF6B7280), size: 20),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF5B6CFF).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: const Color(0xFF5B6CFF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1A1B3E),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.withOpacity(0.12),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () async {
          await _dbHelper.signOut();
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5B5B).withOpacity(0.08),
          side: BorderSide(color: const Color(0xFFFF5B5B).withOpacity(0.2)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.logout_rounded, color: Color(0xFFFF5B5B), size: 18),
            SizedBox(width: 8),
            Text(
              'Keluar dari Akun',
              style: TextStyle(
                color: Color(0xFFFF5B5B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}