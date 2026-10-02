import 'package:flutter/material.dart';
import '../screens/settings_screen.dart';
import '../theme/app_colors.dart';

/// Top header bar matching YouTube Music web/desktop interface.
/// Features centered pill search bar, cast button, and user profile avatar.
class YtTopBar extends StatelessWidget {
  final VoidCallback onSearchTapped;
  final VoidCallback? onMenuTapped;
  final bool showMenuButton;

  const YtTopBar({
    super.key,
    required this.onSearchTapped,
    this.onMenuTapped,
    this.showMenuButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF030303),
      child: Row(
        children: [
          // Left: Optional Hamburger + Logo for compact mode
          if (showMenuButton) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
              onPressed: onMenuTapped,
            ),
            const SizedBox(width: 8),
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
            const SizedBox(width: 16),
          ],

          // Center: Large pill Search Bar
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: GestureDetector(
                  onTap: onSearchTapped,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF212121),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0x33FFFFFF), width: 1),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Search songs, albums, artists, podcasts',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Right: Cast Icon
          IconButton(
            icon: const Icon(Icons.cast_rounded, color: Colors.white, size: 22),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cast device search active'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Cast',
          ),
          const SizedBox(width: 6),

          // Right: Profile Avatar
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFE65100), Color(0xFFFF9800)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Text(
                  'B',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
