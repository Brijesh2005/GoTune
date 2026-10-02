import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/unified_playback_controller.dart';
import '../screens/now_playing_screen.dart';
import '../services/playback/playback_backend.dart';
import '../theme/app_colors.dart';
import '../utils/duration_formatter.dart';
import 'network_artwork.dart';
import 'queue_bottom_sheet.dart';
import 'song_action_sheet.dart';

/// Full-width desktop/tablet/web YouTube Music bottom player bar.
class YtBottomPlayerBar extends StatefulWidget {
  const YtBottomPlayerBar({super.key});

  @override
  State<YtBottomPlayerBar> createState() => _YtBottomPlayerBarState();
}

class _YtBottomPlayerBarState extends State<YtBottomPlayerBar> {
  double? _dragPosition;
  double _volume = 100;
  bool _isMuted = false;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<UnifiedPlaybackController>();
    final library = context.watch<LibraryProvider>();
    final track = player.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    final isFav = library.isFavorite(track.id);
    final duration = player.duration;
    final position = player.position;
    final isPlaying = player.isPlaying;

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: Color(0xFF212121),
        border: Border(
          top: BorderSide(color: Color(0xFF333333), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Thin Scrub Bar at the very top of the player
          _buildScrubBar(context, player, position, duration),

          // Main Controls Row
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // --- LEFT: Track metadata & actions ---
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        // Artwork with click-to-expand
                        GestureDetector(
                          onTap: () => NowPlayingScreen.show(context),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: NetworkArtwork(
                              imageUrl: track.thumbnailArtworkUrl,
                              width: 44,
                              height: 44,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Title & Artist
                        Expanded(
                          child: GestureDetector(
                            onTap: () => NowPlayingScreen.show(context),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Like/Favorite button
                        IconButton(
                          icon: Icon(
                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFav ? AppColors.youtubeRed : Colors.white70,
                            size: 20,
                          ),
                          onPressed: () => library.toggleFavorite(track),
                          tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
                        ),
                        // 3-dots more menu
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
                          onPressed: () => SongActionSheet.show(context, track),
                          tooltip: 'More actions',
                        ),
                      ],
                    ),
                  ),

                  // --- CENTER: Transport controls & time ---
                  Expanded(
                    flex: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Previous
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 28),
                          onPressed: player.skipToPrevious,
                          tooltip: 'Previous',
                        ),
                        const SizedBox(width: 8),

                        // Play/Pause circular button
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 26,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              if (isPlaying) {
                                player.pause();
                              } else {
                                player.play();
                              }
                            },
                            tooltip: isPlaying ? 'Pause' : 'Play',
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Next
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
                          onPressed: player.skipToNext,
                          tooltip: 'Next',
                        ),
                        const SizedBox(width: 16),

                        // Time display
                        Text(
                          '${DurationFormatter.format(position)} / ${DurationFormatter.format(duration)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- RIGHT: Volume, Repeat, Shuffle, Queue, Expand ---
                  Expanded(
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Repeat
                        IconButton(
                          icon: Icon(
                            player.repeatMode == PlaybackRepeatMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            color: player.repeatMode != PlaybackRepeatMode.none
                                ? Colors.white
                                : Colors.white38,
                            size: 20,
                          ),
                          onPressed: player.toggleRepeatMode,
                          tooltip: 'Repeat',
                        ),

                        // Shuffle
                        IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded,
                            color: player.isShuffle ? Colors.white : Colors.white38,
                            size: 20,
                          ),
                          onPressed: player.toggleShuffle,
                          tooltip: 'Shuffle',
                        ),

                        // Volume Icon & Slider
                        IconButton(
                          icon: Icon(
                            _isMuted || _volume == 0
                                ? Icons.volume_off_rounded
                                : (_volume < 50 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                            color: Colors.white70,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _isMuted = !_isMuted;
                              player.setVolume(_isMuted ? 0 : _volume.round());
                            });
                          },
                        ),
                        SizedBox(
                          width: 80,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: const Color(0x33FFFFFF),
                              thumbColor: Colors.white,
                              overlayColor: Colors.transparent,
                            ),
                            child: Slider(
                              value: _isMuted ? 0 : _volume,
                              min: 0,
                              max: 100,
                              onChanged: (val) {
                                setState(() {
                                  _volume = val;
                                  _isMuted = false;
                                  player.setVolume(val.round());
                                });
                              },
                            ),
                          ),
                        ),

                        // Queue button
                        IconButton(
                          icon: const Icon(Icons.queue_music_rounded, color: Colors.white70, size: 20),
                          onPressed: () => QueueBottomSheet.show(context),
                          tooltip: 'Queue',
                        ),

                        // Expand Now Playing / Video
                        IconButton(
                          icon: const Icon(Icons.expand_less_rounded, color: Colors.white70, size: 24),
                          onPressed: () => NowPlayingScreen.show(context),
                          tooltip: 'Open player',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrubBar(
    BuildContext context,
    UnifiedPlaybackController player,
    Duration position,
    Duration duration,
  ) {
    final totalMs = duration.inMilliseconds;
    final currentMs = _dragPosition != null
        ? (_dragPosition! * totalMs).round()
        : position.inMilliseconds;

    final double progress = (totalMs > 0) ? (currentMs / totalMs).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.size.width > 0) {
          final frac = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
          setState(() => _dragPosition = frac);
        }
      },
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.size.width > 0) {
          final frac = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
          setState(() => _dragPosition = frac);
        }
      },
      onHorizontalDragEnd: (_) {
        if (_dragPosition != null && totalMs > 0) {
          final target = Duration(milliseconds: (_dragPosition! * totalMs).round());
          player.seek(target);
        }
        setState(() => _dragPosition = null);
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.size.width > 0) {
          final frac = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
          if (totalMs > 0) {
            player.seek(Duration(milliseconds: (frac * totalMs).round()));
          }
        }
      },
      child: Container(
        height: 4,
        color: const Color(0x33FFFFFF),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              color: AppColors.youtubeRed,
            ),
          ),
        ),
      ),
    );
  }
}
