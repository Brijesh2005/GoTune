import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/unified_playback_controller.dart';
import '../screens/now_playing_screen.dart';
import '../theme/app_colors.dart';
import 'network_artwork.dart';

/// Highly optimized floating mini player positioned above the bottom navigation bar.
/// Uses selective listening and ValueNotifier progress bar to avoid unnecessary rebuilds.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<UnifiedPlaybackController, ({Track? track, bool isPlaying, bool isBuffering})>(
      selector: (_, p) => (track: p.currentTrack, isPlaying: p.isPlaying, isBuffering: p.isBuffering),
      builder: (context, state, _) {
        final track = state.track;
        if (track == null) {
          return const SizedBox.shrink();
        }

        final player = context.read<UnifiedPlaybackController>();
        // Watched so the YouTube badge and buffering spinner react to the live
        // backend, not just to position ticks.
        final isYouTube = player.isYouTubeIframePlayback;

        return Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
          child: GestureDetector(
            onTap: () => NowPlayingScreen.show(context),
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Top progress indicator line using isolated ValueListenableBuilder
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ValueListenableBuilder<Duration>(
                        valueListenable: player.positionNotifier,
                        builder: (context, pos, _) {
                          final durationMs = player.duration.inMilliseconds;
                          final double progress = durationMs > 0
                              ? (pos.inMilliseconds / durationMs).clamp(0.0, 1.0)
                              : 0.0;
                          return LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            minHeight: 2.2,
                          );
                        },
                      ),
                    ),

                    // Player contents
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          // Thumbnail Art Tile (max 150px)
                          //
                          // A YouTube track marks its tile so the listener can
                          // tell at a glance that sound is coming from the
                          // embedded player rather than a direct stream.
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.passthrough,
                              children: [
                                track.thumbnailArtworkUrl.isNotEmpty
                                    ? NetworkArtwork(
                                        imageUrl: track.thumbnailArtworkUrl,
                                        width: 44,
                                        height: 44,
                                        borderRadius: 10,
                                      )
                                    : Container(
                                        width: 44,
                                        height: 44,
                                        color: AppColors.surfaceElevated,
                                        child: const Center(
                                          child: Icon(
                                            Icons.music_note_rounded,
                                            color: AppColors.primary,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                if (isYouTube)
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.smart_display_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Title & Artist
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
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

                          // Play / Pause button
                          GestureDetector(
                            onTap: () => player.togglePlayPause(),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFF282E36),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: state.isBuffering
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        state.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                              ),
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
      },
    );
  }
}
