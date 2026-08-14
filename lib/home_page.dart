import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;

import 'app_states.dart';
import 'community_chat_page.dart';
import 'db_helper.dart';
import 'forum_detail_page.dart';
import 'leaderboard_page.dart';
import 'notification_page.dart';
import 'pet_roadmap_page.dart';
import 'pet_selection_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.onOpenCommunity,
    this.onOpenScan,
    this.onOpenLibrary,
  });

  final ValueChanged<int>? onOpenCommunity;
  final VoidCallback? onOpenScan;
  final VoidCallback? onOpenLibrary;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _ink = Color(0xFF111938);
  static const _primary = Color(0xFF635BFF);
  final _db = DbHelper();
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _game;
  Map<String, dynamic>? _pet;
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _forums = [];
  List<Map<String, dynamic>> _leaders = [];
  int _libraryCount = 0;
  int _notificationCount = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openHome();
  }

  Future<void> _openHome() async {
    try {
      await _db.claimLearningStreak();
    } catch (_) {}
    try {
      await _db.claimActivePetDailyExp();
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final home = await _db.getHomeData();
      final results = await Future.wait([
        _db.getRecentChats(limit: 5),
        _db.getRecentForums(limit: 6),
        _db.getUnreadNotificationCount(),
        _db.getExpLeaderboard(limit: 3),
        _db.getLibraryItems(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = home['profile'];
        _game = home['gamification'];
        _pet = home['pet'];
        _chats = List<Map<String, dynamic>>.from(results[0] as List);
        _forums = List<Map<String, dynamic>>.from(results[1] as List);
        _notificationCount = results[2] as int;
        _leaders = List<Map<String, dynamic>>.from(results[3] as List);
        _libraryCount = (results[4] as List).length;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  int _number(String key) => int.tryParse((_game?[key] ?? 0).toString()) ?? 0;
  String get _name =>
      _profile?['username']?.toString().trim().isNotEmpty == true
      ? _profile!['username'].toString()
      : 'Teman Belajar';
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF0F5FF),
    body: Stack(
      children: [
        Positioned(
          top: -120,
          right: -100,
          child: _ambientBlob(const Color(0xFFB9B6FF).withValues(alpha: .32)),
        ),
        Positioned(
          top: 310,
          left: -130,
          child: _ambientBlob(const Color(0xFFC8E9FF).withValues(alpha: .34)),
        ),
        SafeArea(
          child: _loading
              ? const AppLoadingState(label: 'Menyiapkan beranda...')
              : _error != null
              ? AppErrorState(onRetry: _load, message: _error)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // Ruang atas memberi jarak dari status bar; ruang bawah
                    // memastikan Leaderboard/CTA tidak tertutup floating navbar.
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 38),
                    children: [
                      _header(),
                      const SizedBox(height: 24),
                      _hero(),
                      const SizedBox(height: 22),
                      _sectionHeader(
                        'Recent Chat',
                        Icons.forum_rounded,
                        () => widget.onOpenCommunity?.call(2),
                      ),
                      const SizedBox(height: 12),
                      _recentChats(),
                      const SizedBox(height: 26),
                      _sectionHeader(
                        'Trending Discussion',
                        Icons.local_fire_department_rounded,
                        () => widget.onOpenCommunity?.call(1),
                      ),
                      const SizedBox(height: 12),
                      _forumsStrip(),
                      const SizedBox(height: 26),
                      _overview(),
                      const SizedBox(height: 20),
                      _leaderboard(),
                      const SizedBox(height: 20),
                      _scanCta(),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );

  Widget _ambientBlob(Color color) => ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
    child: Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );

  /// Shared liquid-glass surface used by buttons and dashboard cards.
  Widget _glassSurface({
    required Widget child,
    double radius = 24,
    Color? tint,
  }) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (tint ?? Colors.white).withValues(alpha: .70),
              Colors.white.withValues(alpha: .34),
            ],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: .86)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6373B7).withValues(alpha: .12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );

  Widget _header() => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, $_name! 👋',
              style: const TextStyle(
                fontSize: 19,
                height: 1.05,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              "Let's make today productive!",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF65718F),
              ),
            ),
          ],
        ),
      ),
      _roundButton(Icons.notifications_none_rounded, () async {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NotificationPage()));
        _load();
      }, badge: _notificationCount),
      const SizedBox(width: 8),
      _roundButton(
        Icons.card_giftcard_rounded,
        () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PetRoadmapPage())),
      ),
    ],
  );

  Widget _roundButton(IconData icon, VoidCallback action, {int badge = 0}) =>
      _glassSurface(
        radius: 999,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: action,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(icon, color: _ink, size: 22),
                  if (badge > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF4E65),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _hero() {
    final streak = _number('current_streak');
    final tokens = _number('token_balance');
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PetRoadmapPage())),
      borderRadius: BorderRadius.circular(30),
      child: Ink(
        // Fixed layout avoids overlaps on narrow Android screens.
        height: 242,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFDDE7FF), Color(0xFFEBD9FF)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: .9)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5765B8).withValues(alpha: .14),
              blurRadius: 28,
              offset: const Offset(0, 13),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: 106,
              child: Column(
                children: [
                  _metric(
                    streak.toString(),
                    'Day Streak',
                    '🔥 On Fire!',
                    const Color(0xFFFF6B28),
                    () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PetRoadmapPage()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _metric(
                    tokens.toString(),
                    'Tokens',
                    '✨ isi ulang mingguan',
                    _primary,
                    null,
                  ),
                ],
              ),
            ),
            Positioned(
              right: 4,
              bottom: -5,
              width: 168,
              height: 218,
              child: _petHero(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(
    String value,
    String label,
    String caption,
    Color accent,
    VoidCallback? onTap,
  ) => SizedBox(
    height: 105,
    width: double.infinity,
    child: _glassSurface(
      radius: 23,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(23),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  label == 'Day Streak'
                      ? Icons.local_fire_department_rounded
                      : Icons.auto_awesome_rounded,
                  color: accent,
                  size: 18,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _petHero() => Stack(
    alignment: Alignment.center,
    children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF8D83FF).withValues(alpha: .55),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      Positioned(
        top: 10,
        right: 4,
        child: Icon(
          Icons.auto_awesome,
          color: const Color(0xFFFFD23F).withValues(alpha: .85),
        ),
      ),
      Positioned(
        bottom: 3,
        left: 0,
        child: Icon(
          Icons.auto_awesome,
          color: Colors.white.withValues(alpha: .9),
          size: 18,
        ),
      ),
      GestureDetector(
        onTap: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PetSelectionPage()));
          if (mounted) _load();
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _petImage(_pet?['name']?.toString()),
        ),
      ),
      Positioned(
        bottom: 3,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A5690).withValues(alpha: .12),
                blurRadius: 10,
              ),
            ],
          ),
          child: Text(
            _pet?['name']?.toString() ?? 'ChaTatan Pet',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _petIcon() =>
      const Icon(Icons.smart_toy_rounded, color: _primary, size: 74);

  Widget _petImage(String? name) {
    final asset = _petAsset(name);
    final image = Image.asset(
      asset,
      fit: asset.endsWith('chatatan_study_pet.png')
          ? BoxFit.cover
          : BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => _petIcon(),
    );
    return asset.endsWith('chatatan_study_pet.png')
        ? ClipOval(child: image)
        : image;
  }

  String _petAsset(String? rawName) {
    final name = rawName?.trim().toLowerCase() ?? '';
    if (name.contains('lumi')) return 'assets/images/pet_lumi.png';
    if (name.contains('kucing')) return 'assets/images/pet_kucing.png';
    if (name.contains('piko')) return 'assets/images/pet_piko.png';
    if (name.contains('nori')) return 'assets/images/pet_nori.png';
    if (name.contains('astra')) return 'assets/images/pet_astra.png';
    return 'assets/images/chatatan_study_pet.png';
  }

  Widget _sectionHeader(String title, IconData icon, VoidCallback onSeeAll) =>
      Row(
        children: [
          Icon(icon, color: _primary, size: 23),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
          TextButton(
            onPressed: onSeeAll,
            child: const Text(
              'Lihat semua  ›',
              style: TextStyle(color: _primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );

  Widget _recentChats() => SizedBox(
    height: 193,
    child: _chats.isEmpty
        ? _emptyStrip(
            Icons.chat_bubble_outline_rounded,
            'Belum ada chat',
            'Mulai obrolan dari Community',
          )
        : ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _chats.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, index) => _chatCard(_chats[index]),
          ),
  );

  Widget _chatCard(Map<String, dynamic> item) {
    final conversation = item['conversation'] as Map<String, dynamic>? ?? {};
    final other = item['other_user'] as Map<String, dynamic>? ?? {};
    final last = item['last_message'] as Map<String, dynamic>? ?? {};
    final id = int.tryParse(conversation['id'].toString());
    final title =
        other['username']?.toString() ??
        conversation['title']?.toString() ??
        'Chat';
    final image = other['avatar_url']?.toString();
    final preview = last['message_type'] == 'IMAGE'
        ? '📷 Mengirim foto'
        : last['message_type'] == 'FILE'
        ? '📎 Mengirim dokumen'
        : last['content']?.toString() ?? 'Belum ada pesan';
    return SizedBox(
      width: 186,
      child: _glassSurface(
        radius: 24,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: id == null
                ? null
                : () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CommunityChatPage(
                          conversationId: id,
                          title: title,
                          isGroup: false,
                        ),
                      ),
                    );
                    _load();
                  },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color(0xFFEAE7FF),
                        backgroundImage: image?.isNotEmpty == true
                            ? NetworkImage(image!)
                            : null,
                        child: image?.isNotEmpty == true
                            ? null
                            : const Icon(Icons.person_rounded, color: _primary),
                      ),
                      const Spacer(),
                      const CircleAvatar(
                        radius: 19,
                        backgroundColor: Color(0xFFEDEBFF),
                        child: Icon(
                          Icons.forum_rounded,
                          color: _primary,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF68738F),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    _time(last['created_at']),
                    style: const TextStyle(
                      color: Color(0xFF7B86A4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _forumsStrip() => SizedBox(
    height: 218,
    child: _forums.isEmpty
        ? _emptyStrip(
            Icons.forum_outlined,
            'Belum ada diskusi',
            'Jadilah yang pertama berbagi',
          )
        : ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _forums.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, index) => _forumCard(_forums[index], index),
          ),
  );

  Widget _forumCard(Map<String, dynamic> forum, int index) {
    const colors = [
      Color(0xFFF2E9FF),
      Color(0xFFE5F1FF),
      Color(0xFFE5FAF3),
      Color(0xFFFFF0DE),
    ];
    final id = int.tryParse(forum['id'].toString());
    final replies = forum['reply_count'] ?? 0;
    final category = forum['forum_categories'];
    final rawCategory = category is Map ? category['name'] : null;
    final attachments = forum['forum_attachments'];
    final attachmentCount = attachments is List ? attachments.length : 0;
    final voteScore =
        (int.tryParse((forum['like_count'] ?? 0).toString()) ?? 0) -
        (int.tryParse((forum['dislike_count'] ?? 0).toString()) ?? 0);
    final hashtag = rawCategory?.toString().trim().isNotEmpty == true
        ? '#${rawCategory.toString().trim().replaceAll(RegExp(r'^#+'), '')}'
        : '#umum';
    final author = forum['users'];
    final rawAuthorName = author is Map
        ? (author['full_name']?.toString().trim().isNotEmpty == true
              ? author['full_name'].toString()
              : author['username']?.toString() ?? 'Pengguna')
        : 'Pengguna';
    final authorName = rawAuthorName.trim().isEmpty
        ? 'Pengguna'
        : rawAuthorName;
    final authorAvatar = author is Map
        ? author['avatar_url']?.toString()
        : null;
    return SizedBox(
      width: 198,
      child: _glassSurface(
        radius: 24,
        tint: colors[index % colors.length],
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: id == null
                ? null
                : () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ForumDetailPage(postId: id),
                      ),
                    );
                    _load();
                  },
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .62),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          hashtag,
                          style: TextStyle(
                            color: _primary.withValues(alpha: .9),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (attachmentCount > 0) ...[
                        const Icon(
                          Icons.attach_file_rounded,
                          color: _primary,
                          size: 15,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$attachmentCount',
                          style: const TextStyle(
                            color: _primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 7),
                      ],
                      const Icon(Icons.forum_rounded, color: _primary),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Text(
                      forum['title']?.toString() ?? 'Diskusi tanpa judul',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: const Color(0xFFE2DEFF),
                        backgroundImage:
                            authorAvatar != null && authorAvatar.isNotEmpty
                            ? NetworkImage(authorAvatar)
                            : null,
                        child: authorAvatar != null && authorAvatar.isNotEmpty
                            ? null
                            : Text(
                                authorName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: _primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF65718F),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_rounded,
                        color: _primary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$replies balasan',
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_upward_rounded,
                        color: _primary,
                        size: 16,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$voteScore',
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overview() {
    final exp = _number('total_points');
    final level = _level(exp);
    return Row(
      children: [
        Expanded(
          child: _overviewCard(
            Icons.description_rounded,
            'Library',
            '$_libraryCount file tersimpan',
            widget.onOpenLibrary ?? () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _overviewCard(
            Icons.workspace_premium_rounded,
            'Level $level',
            '$exp total EXP',
            _showLevel,
          ),
        ),
      ],
    );
  }

  Widget _overviewCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => _glassSurface(
    radius: 23,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(23),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _primary),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF6C7694), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _scanCta() => _glassSurface(
    radius: 25,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: widget.onOpenScan,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, Color(0xFF9A55FF)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.document_scanner_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Punya catatan baru?',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Scan catatan atau papan tulis dengan AI',
                      style: TextStyle(color: Color(0xFF6C7694), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, Color(0xFFA05DFF)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'Scan',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _emptyStrip(IconData icon, String title, String message) => Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _primary, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
          ),
          const SizedBox(height: 3),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF6C7694), fontSize: 12),
          ),
        ],
      ),
    ),
  );

  int _level(int exp) {
    var level = 1;
    var used = exp;
    while (used >= level * 100) {
      used -= level * 100;
      level++;
    }
    return level;
  }

  String _time(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} mnt';
    if (diff.inDays < 1) return '${diff.inHours} jam';
    return '${diff.inDays} hari';
  }

  void _showLevel() {
    final points = _number('total_points');
    final level = _level(points);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Level $level',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Kamu telah mengumpulkan $points EXP dari streak dan kontribusi komunitas.',
            ),
            const SizedBox(height: 8),
            const Text('Terus belajar dan berbagi agar levelmu naik!'),
          ],
        ),
      ),
    );
  }

  void _openLeaderboard() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LeaderboardPage()));
  }

  Widget _leaderboard() => _glassSurface(
    radius: 25,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: _openLeaderboard,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFFFB51B),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Leaderboard',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _openLeaderboard,
                    child: const Text(
                      'EXP',
                      style: TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_leaders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 17),
                  child: Center(child: Text('Belum ada peringkat EXP.')),
                )
              else
                ..._leaders.asMap().entries.map(
                  (entry) => _leaderRow(entry.key, entry.value),
                ),
              const SizedBox(height: 5),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EEFF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bar_chart_rounded, color: _primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Ayo naik peringkat lebih tinggi!',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _leaderRow(int index, Map<String, dynamic> user) {
    const medals = [Color(0xFFFFB51B), Color(0xFF9EA7B8), Color(0xFFC97945)];
    final isMe = user['user_id']?.toString() == _db.currentUser?.id;
    final avatar = user['avatar_url']?.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Icon(
              Icons.workspace_premium_rounded,
              color: medals[index < medals.length ? index : medals.length - 1],
              size: 23,
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFEAE7FF),
            backgroundImage: avatar?.isNotEmpty == true
                ? NetworkImage(avatar!)
                : null,
            child: avatar?.isNotEmpty == true
                ? null
                : const Icon(Icons.person_rounded, color: _primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${user['username'] ?? 'Pengguna'}${isMe ? ' (Kamu)' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMe ? _primary : _ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '${user['total_points'] ?? 0}',
            style: const TextStyle(
              color: Color(0xFF5E6B8A),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.star_rounded, color: Color(0xFFFFB51B), size: 17),
        ],
      ),
    );
  }
}
