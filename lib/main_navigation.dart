import 'package:flutter/material.dart';

import 'home_page.dart';
import 'library_page.dart';
import 'community_page.dart';
import 'profile_page.dart';
import 'scan_page.dart';
import 'push_notification_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final List<int> _tabHistory = [];
  final GlobalKey<LibraryPageState> _libraryKey = GlobalKey<LibraryPageState>();
  final GlobalKey<CommunityPageState> _communityKey =
      GlobalKey<CommunityPageState>();

  late final List<Widget> _pages = [
    HomePage(onOpenCommunity: _openCommunityFromHome),
    LibraryPage(key: _libraryKey),
    const ScanPage(),
    CommunityPage(key: _communityKey),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    PushNotificationService.instance.initialize();
  }

  void _openCommunityFromHome(int tab) {
    _communityKey.currentState?.selectTab(tab);
    _onItemTapped(3);
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;
    setState(() {
      if (index == 0) {
        // Home is the root page; returning to it clears tab navigation history.
        _tabHistory.clear();
      } else {
        _tabHistory.add(_currentIndex);
      }
      _currentIndex = index;
    });
    if (index == 1) {
      _libraryKey.currentState?.refreshLibrary();
    }
  }

  void _goBackToPreviousTab() {
    if (_currentIndex == 0 && _tabHistory.isEmpty) return;
    setState(() {
      _currentIndex = _tabHistory.isNotEmpty ? _tabHistory.removeLast() : 0;
    });
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

        body: IndexedStack(index: _currentIndex, children: _pages),

        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: SafeArea(
        top: false,

        child: SizedBox(
          height: 72,

          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,

            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
              ),

              _buildNavItem(
                index: 1,
                icon: Icons.library_books_outlined,
                activeIcon: Icons.library_books_rounded,
                label: 'Library',
              ),

              _buildScanButton(),

              _buildNavItem(
                index: 3,
                icon: Icons.people_outline_rounded,
                activeIcon: Icons.people_rounded,
                label: 'Community',
              ),

              _buildNavItem(
                index: 4,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),

        borderRadius: BorderRadius.circular(20),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(
              isSelected ? activeIcon : icon,

              size: 24,

              color: isSelected ? Colors.deepPurple : Colors.grey.shade500,
            ),

            const SizedBox(height: 4),

            Text(
              label,

              style: TextStyle(
                fontSize: 10,

                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,

                color: isSelected ? Colors.deepPurple : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    final isSelected = _currentIndex == 2;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(2),

        child: Transform.translate(
          offset: const Offset(0, -16),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),

                width: isSelected ? 54 : 50,
                height: isSelected ? 54 : 50,

                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,

                  border: Border.all(color: Colors.white, width: 5),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withValues(alpha: 0.25),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),

                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),

              const SizedBox(height: 0),

              Text(
                'Scan',

                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.deepPurple : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
