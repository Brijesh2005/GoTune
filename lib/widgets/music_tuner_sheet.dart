import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/unified_playback_controller.dart';
import '../screens/now_playing_screen.dart';

/// YouTube Music "Music Tuner / Radio Tuner" modal sheet (Screen 2).
/// Lets the user configure:
/// - Artist variety (Low, Medium, High)
/// - Song selection (Familiar, Blend, Discover)
/// - Music filters (Popular, Deep cuts, New releases, Pump-up, Chill, Upbeat, Downbeat, Focus)
class MusicTunerSheet extends StatefulWidget {
  final List<String>? initialArtists;

  const MusicTunerSheet({
    super.key,
    this.initialArtists,
  });

  static Future<void> show(BuildContext context, {List<String>? initialArtists}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MusicTunerSheet(initialArtists: initialArtists),
    );
  }

  @override
  State<MusicTunerSheet> createState() => _MusicTunerSheetState();
}

class _MusicTunerSheetState extends State<MusicTunerSheet> {
  late List<String> _artists;
  String _variety = 'Medium';
  String _selection = 'Discover';
  final Set<String> _selectedFilters = {'Popular'};

  final List<String> _availableFilters = const [
    'Popular',
    'Deep cuts',
    'New releases',
    'Pump-up',
    'Chill',
    'Upbeat',
    'Downbeat',
    'Focus',
  ];

  @override
  void initState() {
    super.initState();
    final controller = context.read<UnifiedPlaybackController>();
    _artists = widget.initialArtists ??
        (controller.currentTrack != null
            ? [controller.currentTrack!.artist, 'Doja Cat', 'Billie Eilish']
            : ['Lil Nas X', 'Doja Cat', 'Billie Eilish']);
    _variety = controller.radioVariety;
    _selection = controller.radioSongSelection;
    if (controller.radioFilters.isNotEmpty) {
      _selectedFilters.clear();
      _selectedFilters.addAll(controller.radioFilters);
    }
  }

  void _onDone() async {
    Navigator.of(context).pop();
    final controller = context.read<UnifiedPlaybackController>();
    await controller.startTunedRadio(
      seedArtists: _artists,
      variety: _variety,
      songSelection: _selection,
      filters: _selectedFilters.toList(),
    );
    if (mounted) {
      NowPlayingScreen.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF030303),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top pull handle & close bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Overlapping artist avatars with '+'
                  _buildArtistAvatarStack(),
                  // Close 'X' button
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Main scrollable tuner settings
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                children: [
                  // Artist Titles
                  Text(
                    _artists.join(', '),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Section 1: Artist variety
                  const Text(
                    'Artist variety',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildVarietySegmentedControl(),

                  const SizedBox(height: 36),

                  // Section 2: Song selection
                  const Text(
                    'Song selection',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildSongSelectionRow(),

                  const SizedBox(height: 36),

                  // Section 3: Filters
                  const Text(
                    'Filters',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildFilterChips(),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Bottom Full-width "Done ✓" pill button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: _onDone,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.check_rounded, color: Colors.black, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistAvatarStack() {
    return SizedBox(
      height: 44,
      width: 130,
      child: Stack(
        children: [
          // Plus button circle
          Positioned(
            left: 0,
            top: 2,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            ),
          ),
          // Artist Circle 1
          Positioned(
            left: 28,
            child: _buildAvatarCircle(const Color(0xFFE91E63), 'LN'),
          ),
          // Artist Circle 2
          Positioned(
            left: 56,
            child: _buildAvatarCircle(const Color(0xFF9C27B0), 'DC'),
          ),
          // Artist Circle 3
          Positioned(
            left: 84,
            child: _buildAvatarCircle(const Color(0xFF00BCD4), 'BE'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCircle(Color color, String initials) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: const Color(0xFF030303), width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildVarietySegmentedControl() {
    final options = ['Low', 'Medium', 'High'];

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = _variety == opt;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _variety = opt),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSongSelectionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSelectionItem(
          label: 'Familiar',
          icon: Icons.wifi_tethering_rounded,
          isSelected: _selection == 'Familiar',
          onTap: () => setState(() => _selection = 'Familiar'),
        ),
        _buildSelectionItem(
          label: 'Blend',
          icon: Icons.all_inclusive_rounded,
          isSelected: _selection == 'Blend',
          onTap: () => setState(() => _selection = 'Blend'),
        ),
        _buildSelectionItem(
          label: 'Discover',
          icon: Icons.fingerprint_rounded,
          isSelected: _selection == 'Discover',
          onTap: () => setState(() => _selection = 'Discover'),
        ),
      ],
    );
  }

  Widget _buildSelectionItem({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? const Color(0xFFF2F2F2) : const Color(0xFF181818),
              border: Border.all(
                color: isSelected ? Colors.white : const Color(0x28FFFFFF),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 40,
              color: isSelected ? Colors.black : Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: _availableFilters.map((f) {
        final isSelected = _selectedFilters.contains(f);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedFilters.remove(f);
              } else {
                _selectedFilters.add(f);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2E2E38) : const Color(0xFF141416),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.white38 : const Color(0x18FFFFFF),
                width: 1,
              ),
            ),
            child: Text(
              f,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
