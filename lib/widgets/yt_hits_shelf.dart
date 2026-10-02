import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../providers/unified_playback_controller.dart';
import '../screens/playlist_detail_screen.dart';
import '../theme/app_colors.dart';
import 'network_artwork.dart';

/// Shelf representing "MUSIC THAT'S HOT AND HAPPENING! / India's biggest hits"
/// matching the YouTube Music desktop layout.
class YtHitsShelf extends StatefulWidget {
  final List<Playlist> playlists;

  const YtHitsShelf({
    super.key,
    required this.playlists,
  });

  @override
  State<YtHitsShelf> createState() => _YtHitsShelfState();
}

class _YtHitsShelfState extends State<YtHitsShelf> {
  final ScrollController _scrollController = ScrollController();

  void _scroll(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.playlists.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kicker + Title + Left/Right arrows
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "MUSIC THAT'S HOT AND HAPPENING!",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "India's biggest hits",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () => _scroll(-360),
                  icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  splashRadius: 18,
                ),
                IconButton(
                  onPressed: () => _scroll(360),
                  icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  splashRadius: 18,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Horizontal list of cards
        SizedBox(
          height: 240,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.playlists.length,
            itemBuilder: (context, index) {
              final playlist = widget.playlists[index];
              return _HitPlaylistCard(playlist: playlist);
            },
          ),
        ),
      ],
    );
  }
}

class _HitPlaylistCard extends StatefulWidget {
  final Playlist playlist;

  const _HitPlaylistCard({required this.playlist});

  @override
  State<_HitPlaylistCard> createState() => _HitPlaylistCardState();
}

class _HitPlaylistCardState extends State<_HitPlaylistCard> {
  bool _isHovered = false;

  String _getCoverArtwork(Playlist playlist) {
    if (playlist.tracks.isNotEmpty) {
      final firstArt = playlist.tracks.first.bestArtworkUrl;
      if (firstArt.isNotEmpty) return firstArt;
    }
    // High quality themed fallbacks
    final name = playlist.name.toLowerCase();
    if (name.contains('punjab')) {
      return 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop';
    }
    if (name.contains('arijit')) {
      return 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop';
    }
    if (name.contains('pop') || name.contains('i-pop')) {
      return 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop';
    }
    return 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&auto=format&fit=crop';
  }

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlist;
    final cover = _getCoverArtwork(playlist);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        width: 172,
        margin: const EdgeInsets.only(right: 18),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlaylistDetailScreen(playlist: playlist),
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Artwork container with hover play button
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: NetworkArtwork(
                      imageUrl: cover,
                      width: 172,
                      height: 172,
                    ),
                  ),

                  // Top-left or center play button badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _isHovered ? 1.0 : 0.85,
                      child: GestureDetector(
                        onTap: () {
                          if (playlist.tracks.isNotEmpty) {
                            context.read<UnifiedPlaybackController>().playTrack(
                                  playlist.tracks.first,
                                  playlist: playlist.tracks,
                                  initialIndex: 0,
                                );
                          }
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),

              // Description
              Text(
                playlist.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
