import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/unified_playback_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/yt_sidebar.dart';
import '../widgets/yt_top_bar.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Root shell managing primary navigation across Home, Explore/Search, and Library.
/// Features responsive layout: YouTube Music desktop sidebar + top bar on wide screens,
/// and responsive drawer + top bar on mobile screens.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _switchTab(int index) {
    if (index == 3) {
      // Upgrade / Settings tab
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF212121),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Playlist title',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF141414),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.youtubeRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context.read<LibraryProvider>().createPlaylist(name);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Created playlist: $name'), duration: const Duration(seconds: 2)),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    final player = context.watch<UnifiedPlaybackController>();
    final hasPlayer = player.hasActiveTrack;

    final screens = [
      HomeScreen(
        onSearchTapped: () => _switchTab(1),
        onLibraryTapped: () => _switchTab(2),
        onProfileTapped: () => _switchTab(3),
      ),
      const SearchScreen(),
      LibraryScreen(onExploreTapped: () => _switchTab(0)),
    ];

    if (isWide) {
      // --- Widescreen YouTube Music Desktop / Tablet Interface ---
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            // Left Navigation Sidebar (YouTube Music)
            YtSidebar(
              selectedIndex: _currentIndex,
              onSelectTab: _switchTab,
              onNewPlaylist: _showCreatePlaylistDialog,
              onSettingsTapped: () => _switchTab(3),
            ),

            const VerticalDivider(
              color: Color(0x1FFFFFFF),
              width: 1,
              thickness: 1,
            ),

            // Main View Area: Top Bar + Active Screen Body
            Expanded(
              child: Column(
                children: [
                  // Top Search & Account Header
                  YtTopBar(
                    onSearchTapped: () => _switchTab(1),
                  ),

                  // Active Screen Page
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: hasPlayer ? 72 : 0),
                      child: IndexedStack(
                        index: _currentIndex,
                        children: screens,
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

    // --- Compact / Mobile Interface ---
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: Drawer(
        backgroundColor: const Color(0xFF030303),
        child: SafeArea(
          child: YtSidebar(
            selectedIndex: _currentIndex,
            onSelectTab: (idx) {
              Navigator.pop(context);
              _switchTab(idx);
            },
            onNewPlaylist: () {
              Navigator.pop(context);
              _showCreatePlaylistDialog();
            },
            onSettingsTapped: () {
              Navigator.pop(context);
              _switchTab(3);
            },
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Hamburger for Mobile
            YtTopBar(
              showMenuButton: true,
              onMenuTapped: () => _scaffoldKey.currentState?.openDrawer(),
              onSearchTapped: () => _switchTab(1),
            ),

            // Content Stack
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    bottom: 64,
                    child: IndexedStack(
                      index: _currentIndex,
                      children: screens,
                    ),
                  ),

                  // Mobile 3-tab bottom navigation
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildMobileBottomBar(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBottomBar() {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(
          top: BorderSide(color: Color(0x1AFFFFFF), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMobileNavItem(0, 'Home', Icons.home_filled, Icons.home_outlined),
          _buildMobileNavItem(1, 'Explore', Icons.explore, Icons.explore_outlined),
          _buildMobileNavItem(2, 'Library', Icons.bookmark_rounded, Icons.bookmark_border_rounded),
        ],
      ),
    );
  }

  Widget _buildMobileNavItem(int index, String label, IconData activeIcon, IconData inactiveIcon) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => _switchTab(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? activeIcon : inactiveIcon,
            color: isActive ? Colors.white : Colors.white54,
            size: 24,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white54,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
