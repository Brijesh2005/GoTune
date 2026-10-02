import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Left sidebar navigation component matching the YouTube Music desktop layout.
class YtSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback? onNewPlaylist;
  final VoidCallback? onSettingsTapped;

  const YtSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelectTab,
    this.onNewPlaylist,
    this.onSettingsTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: const Color(0xFF030303),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top logo header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 18),
                // YouTube Music Red Play Logo
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.youtubeRed,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Music',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),

          // Primary Navigation Links
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _buildNavItem(0, 'Home', Icons.home_filled, Icons.home_outlined),
                const SizedBox(height: 4),
                _buildNavItem(1, 'Explore', Icons.explore, Icons.explore_outlined),
                const SizedBox(height: 4),
                _buildNavItem(2, 'Library', Icons.bookmark_rounded, Icons.bookmark_border_rounded),
                const SizedBox(height: 4),
                _buildNavItem(3, 'Upgrade', Icons.radio_button_checked, Icons.radio_button_unchecked),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // "+ New playlist" button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: onNewPlaylist,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF212121),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x22FFFFFF), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'New playlist',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),
          const Divider(color: Color(0x1FFFFFFF), height: 1, indent: 16, endIndent: 16),
          const SizedBox(height: 12),

          // Playlist / Saved Items Section
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // "Episodes for later" Auto playlist
                InkWell(
                  onTap: () => onSelectTab(2),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Episodes for later',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Auto playlist',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => onSelectTab(2),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Liked Music',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Auto playlist',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Settings shortcut at bottom of sidebar
          if (onSettingsTapped != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.settings_outlined, color: Colors.white70, size: 20),
                title: const Text('Settings', style: TextStyle(color: Colors.white70, fontSize: 13)),
                onTap: onSettingsTapped,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData activeIcon, IconData inactiveIcon) {
    final isActive = selectedIndex == index;

    return InkWell(
      onTap: () => onSelectTab(index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF272727) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
