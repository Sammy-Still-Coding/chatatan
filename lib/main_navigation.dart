import 'package:flutter/material.dart';

import 'home_page.dart';
import 'library_page.dart';
import 'community_page.dart';
import 'profile_page.dart';
import 'scan_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final GlobalKey<LibraryPageState> _libraryKey = GlobalKey<LibraryPageState>();

  late final List<Widget> _pages = [
    const HomePage(),
    LibraryPage(key: _libraryKey),
    const ScanPage(),
    const CommunityPage(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (index == 1) {
      _libraryKey.currentState?.refreshLibrary();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,

      body: IndexedStack(index: _currentIndex, children: _pages),

      bottomNavigationBar: _buildBottomNavigationBar(),
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

                width: isSelected ? 62 : 58,
                height: isSelected ? 62 : 58,

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

              const SizedBox(height: 2),

              Text(
                'Scan',

                style: TextStyle(
                  fontSize: 10,
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
