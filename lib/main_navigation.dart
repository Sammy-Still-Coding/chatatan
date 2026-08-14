import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;

import 'home_page.dart';
import 'library_page.dart';
import 'community_page.dart';
import 'profile_page.dart';
import 'scan_page.dart';
import 'push_notification_service.dart';
import 'community_chat_page.dart';
import 'forum_detail_page.dart';
import 'db_helper.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final List<int> _tabHistory = [];
  final GlobalKey<LibraryPageState> _libraryKey = GlobalKey<LibraryPageState>();
  final GlobalKey<CommunityPageState> _communityKey =
      GlobalKey<CommunityPageState>();
  final _db = DbHelper();
  StreamSubscription<Map<String, String>>? _pushOpenSubscription;
  Timer? _pageTransitionTimer;
  int? _transitionFromIndex;
  int _transitionDirection = 1;
  late final AnimationController _pageMorphController;

  late final List<Widget> _pages = [
    HomePage(
      onOpenCommunity: _openCommunityFromHome,
      onOpenScan: () => _onItemTapped(2),
      onOpenLibrary: () => _onItemTapped(1),
    ),
    LibraryPage(key: _libraryKey),
    const ScanPage(),
    CommunityPage(key: _communityKey),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageMorphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
    PushNotificationService.instance.initialize();
    _pushOpenSubscription = PushNotificationService
        .instance
        .onNotificationOpened
        .listen(_openPushTarget);
  }

  @override
  void dispose() {
    _pushOpenSubscription?.cancel();
    _pageTransitionTimer?.cancel();
    _pageMorphController.dispose();
    super.dispose();
  }

  Future<void> _openPushTarget(Map<String, String> data) async {
    final navigator = Navigator.of(context);
    final entityType = data['entity_type'];
    final entityId = int.tryParse(data['entity_id'] ?? '');
    if (entityId == null) return;
    if (entityType == 'FORUM_POST') {
      await navigator.push(
        MaterialPageRoute(builder: (_) => ForumDetailPage(postId: entityId)),
      );
      return;
    }
    if (entityType == 'CONVERSATION') {
      final room = await _db.getConversation(entityId);
      if (!mounted || room == null) return;
      final isGroup = room['conversation_type']?.toString() == 'GROUP';
      final title = room['title']?.toString().trim();
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => CommunityChatPage(
            conversationId: entityId,
            title: title == null || title.isEmpty
                ? (isGroup ? 'Grup chat' : 'Chat')
                : title,
            isGroup: isGroup,
          ),
        ),
      );
    }
  }

  void _openCommunityFromHome(int tab) {
    _communityKey.currentState?.selectTab(tab);
    _onItemTapped(3);
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;
    final previousIndex = _currentIndex;
    setState(() {
      if (index == 0) {
        // Home is the root page; returning to it clears tab navigation history.
        _tabHistory.clear();
      } else {
        _tabHistory.add(_currentIndex);
      }
      _transitionDirection = index > previousIndex ? 1 : -1;
      _transitionFromIndex = previousIndex;
      _currentIndex = index;
    });
    _pageMorphController.forward(from: 0);
    _finishPageTransition();
    if (index == 1) {
      _libraryKey.currentState?.refreshLibrary();
    }
  }

  void _goBackToPreviousTab() {
    if (_currentIndex == 0 && _tabHistory.isEmpty) return;
    final previousIndex = _currentIndex;
    final targetIndex = _tabHistory.isNotEmpty ? _tabHistory.removeLast() : 0;
    setState(() {
      _transitionDirection = targetIndex > previousIndex ? 1 : -1;
      _currentIndex = targetIndex;
      _transitionFromIndex = previousIndex;
    });
    _pageMorphController.forward(from: 0);
    _finishPageTransition();
  }

  void _finishPageTransition() {
    _pageTransitionTimer?.cancel();
    _pageTransitionTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _transitionFromIndex = null);
    });
  }

  Widget _buildSlidingPages() {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: _pageMorphController,
          builder: (context, _) {
            final rawProgress = _pageMorphController.value;
            final progress = Curves.easeOutCubic.transform(rawProgress);
            final blur = math.sin(math.pi * rawProgress) * .65;
            return Stack(
              fit: StackFit.expand,
              children: List.generate(_pages.length, (index) {
                final isCurrent = index == _currentIndex;
                final isLeaving = index == _transitionFromIndex;
                final isVisible = isCurrent || isLeaving;
                final dx = isCurrent
                    ? _transitionDirection *
                          (1 - progress) *
                          constraints.maxWidth
                    : isLeaving
                    ? -_transitionDirection * progress * constraints.maxWidth
                    : (index < _currentIndex ? -1 : 1) * constraints.maxWidth;

                return Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !isCurrent,
                    child: TickerMode(
                      enabled: isVisible,
                      child: Opacity(
                        opacity: isVisible ? 1 : 0,
                        child: Transform.translate(
                          offset: Offset(dx, 0),
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: isVisible ? blur : 0,
                              sigmaY: isVisible ? blur : 0,
                            ),
                            child: RepaintBoundary(child: _pages[index]),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0 && _tabHistory.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBackToPreviousTab();
      },
      child: Scaffold(
        extendBody: true,
        body: _buildSlidingPages(),
        bottomNavigationBar: _GlassNavBar(
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass navigation bar — kapsul utuh, satu RRect (tanpa bump terpisah),
// dengan bubble indikator yang "melar" seperti tetesan air saat berpindah tab.
// ---------------------------------------------------------------------------

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const List<_NavItemData> _kNavItems = [
  _NavItemData(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Home',
  ),
  _NavItemData(
    icon: Icons.library_books_outlined,
    activeIcon: Icons.library_books_rounded,
    label: 'Library',
  ),
  _NavItemData(
    icon: Icons.camera_alt_outlined,
    activeIcon: Icons.camera_alt_rounded,
    label: 'Camera',
  ),
  _NavItemData(
    icon: Icons.people_outline_rounded,
    activeIcon: Icons.people_rounded,
    label: 'Community',
  ),
  _NavItemData(
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    label: 'Profile',
  ),
];

const double _kPillHeight = 82;

class _GlassNavBar extends StatefulWidget {
  const _GlassNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  State<_GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<_GlassNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _indexAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _indexAnimation = AlwaysStoppedAnimation(widget.currentIndex.toDouble());
  }

  @override
  void didUpdateWidget(covariant _GlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      // Mulai dari posisi bubble saat ini (bukan selalu dari index lama),
      // supaya kalau user tap cepat berkali-kali animasinya tetap mulus.
      final fromValue = _indexAnimation.value;
      _indexAnimation =
          Tween<double>(
            begin: fromValue,
            end: widget.currentIndex.toDouble(),
          ).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _NavBarColors.of(isDark);
    final itemCount = _kNavItems.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 12),
      child: Container(
        height: _kPillHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kPillHeight / 2),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_kPillHeight / 2),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                gradient: colors.tintGradient,
                border: Border.all(color: colors.border, width: 1.2),
                borderRadius: BorderRadius.circular(_kPillHeight / 2),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / itemCount;
                  return Stack(
                    children: [
                      // Bubble cair — melar saat bergerak, menyusut saat diam.
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          final t = _controller.value.clamp(0.0, 1.0);
                          final stretch = math.sin(math.pi * t); // 0 -> 1 -> 0
                          final centerX =
                              itemWidth * (_indexAnimation.value + 0.5);

                          final baseWidth = itemWidth * 0.94;
                          final baseHeight = _kPillHeight * 0.80;
                          final bubbleWidth = baseWidth + (22 * stretch);
                          final bubbleHeight = baseHeight - (10 * stretch);

                          return Positioned(
                            left: centerX - bubbleWidth / 2,
                            top: (_kPillHeight - bubbleHeight) / 2,
                            width: bubbleWidth,
                            height: bubbleHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  bubbleHeight / 2,
                                ),
                                gradient: colors.bubbleGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.bubbleGlow,
                                    blurRadius: 18,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Ikon + label.
                      Row(
                        children: List.generate(itemCount, (index) {
                          final item = _kNavItems[index];
                          final selected = widget.currentIndex == index;
                          return _NavItem(
                            selected: selected,
                            icon: item.icon,
                            activeIcon: item.activeIcon,
                            label: item.label,
                            colors: colors,
                            showSparkle: index == 2,
                            onTap: () => widget.onTap(index),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.showSparkle = false,
  });

  final bool selected;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final _NavBarColors colors;
  final VoidCallback onTap;
  final bool showSparkle;

  @override
  Widget build(BuildContext context) {
    final color = selected ? colors.activeIcon : colors.inactiveIcon;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 26,
              width: 26,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1, end: selected ? 1.12 : 1.0),
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Icon(
                      selected ? activeIcon : icon,
                      size: 24,
                      color: color,
                    ),
                  ),
                  if (showSparkle)
                    Positioned(
                      top: -6,
                      right: -8,
                      child: Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: colors.sparkle,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 14,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Warna adaptif — otomatis ganti varian gelap saat Theme.brightness == dark.
class _NavBarColors {
  const _NavBarColors({
    required this.tintGradient,
    required this.bubbleGradient,
    required this.bubbleGlow,
    required this.border,
    required this.shadow,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.sparkle,
  });

  final Gradient tintGradient;
  final Gradient bubbleGradient;
  final Color bubbleGlow;
  final Color border;
  final Color shadow;
  final Color activeIcon;
  final Color inactiveIcon;
  final Color sparkle;

  static _NavBarColors of(bool isDark) {
    if (isDark) {
      return _NavBarColors(
        tintGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .07),
            Colors.white.withValues(alpha: .02),
          ],
        ),
        bubbleGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8D7BFF).withValues(alpha: .28),
            const Color(0xFFB98CFF).withValues(alpha: .22),
          ],
        ),
        bubbleGlow: const Color(0xFF8D7BFF).withValues(alpha: .18),
        border: Colors.white.withValues(alpha: .14),
        shadow: Colors.black.withValues(alpha: .55),
        activeIcon: const Color(0xFFC3BBFF),
        inactiveIcon: const Color(0xFF9AA3B8),
        sparkle: const Color(0xFFCF9DFF),
      );
    }
    return _NavBarColors(
      tintGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: .55),
          const Color(0xFFEDE7FF).withValues(alpha: .35),
        ],
      ),
      bubbleGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFEBD6FF).withValues(alpha: .85),
          const Color(0xFFD8CBFF).withValues(alpha: .55),
        ],
      ),
      bubbleGlow: const Color(0xFFC9A9FF).withValues(alpha: .35),
      border: Colors.white.withValues(alpha: .85),
      shadow: const Color(0xFF5367B9).withValues(alpha: .22),
      activeIcon: const Color(0xFF6C5BFF),
      inactiveIcon: const Color(0xFF9AA5C4),
      sparkle: const Color(0xFFB565FF),
    );
  }
}
