import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audio_player_provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_colors.dart';
import '../utils/duration_formatter.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/network_artwork.dart';
import '../widgets/queue_bottom_sheet.dart';
import '../widgets/sleep_timer_sheet.dart';

/// Full-screen now playing modal sheet matching the Pulse dynamic aesthetic.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NowPlayingScreen(),
    );
  }

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<AudioPlayerProvider>();
    final libraryProvider = context.watch<LibraryProvider>();
    final track = playerProvider.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    final isFav = libraryProvider.isFavorite(track.id);
    final size = MediaQuery.of(context).size;
    final artSize = (size.width - 48).clamp(240.0, 360.0);

    final positionSeconds = playerProvider.position.inSeconds.toDouble();
    final durationSeconds = playerProvider.duration.inSeconds > 0
        ? playerProvider.duration.inSeconds.toDouble()
        : (track.durationSeconds > 0 ? track.durationSeconds.toDouble() : 1.0);

    final sliderValue = (_dragValue ?? positionSeconds).clamp(0.0, durationSeconds);
    final remainingSeconds = (durationSeconds - sliderValue).clamp(0.0, durationSeconds);

    return Container(
      height: size.height * 0.94,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // Top Header Row matching HTML prototype
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back / Minimize Button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textPrimary,
                            size: 26,
                          ),
                        ),
                      ),
                    ),

                    // "NOW PLAYING" Header
                    const Text(
                      'NOW PLAYING',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),

                    // Options button (sleep timer, playlist add)
                    GestureDetector(
                      onTap: () => _showMoreOptions(context, track),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.more_horiz_rounded,
                            color: AppColors.textPrimary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Artwork with Deep Drop Shadow
                Container(
                  width: artSize,
                  height: artSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x73000000),
                        blurRadius: 40,
                        offset: Offset(0, 20),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: track.bestArtworkUrl.isNotEmpty
                        ? NetworkArtwork(
                            imageUrl: track.bestArtworkUrl,
                            width: artSize,
                            height: artSize,
                            borderRadius: 24,
                          )
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: AppColors.artTileGradient,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.music_note_rounded,
                                color: AppColors.primaryLight,
                                size: 80,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 28),

                // Title, Artist, and Like Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Heart Like Button
                    GestureDetector(
                      onTap: () => libraryProvider.toggleFavorite(track),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
                        ),
                        child: Center(
                          child: Icon(
                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFav ? AppColors.primary : AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Range Progress Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.5,
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: const Color(0xFF282E36),
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayColor: AppColors.primarySoft,
                    trackShape: const RectangularSliderTrackShape(),
                  ),
                  child: Slider(
                    value: sliderValue,
                    min: 0.0,
                    max: durationSeconds > 0 ? durationSeconds : 1.0,
                    onChanged: (val) {
                      setState(() {
                        _dragValue = val;
                      });
                    },
                    onChangeEnd: (val) {
                      playerProvider.seek(Duration(seconds: val.toInt()));
                      setState(() {
                        _dragValue = null;
                      });
                    },
                  ),
                ),

                // Elapsed & Remaining Time row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DurationFormatter.formatSeconds(sliderValue.toInt()),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '-${DurationFormatter.formatSeconds(remainingSeconds.toInt())}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Primary Playback Controls Row matching prototype
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Shuffle Button
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: playerProvider.isShuffle
                            ? AppColors.primary
                            : AppColors.textMuted,
                        size: 22,
                      ),
                      onPressed: () => playerProvider.toggleShuffle(),
                    ),

                    // Previous Button
                    GestureDetector(
                      onTap: () => playerProvider.previous(),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.skip_previous_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),

                    // Large 76x76 Play / Pause Button in Electric Blue
                    GestureDetector(
                      onTap: () => playerProvider.togglePlayPause(),
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: playerProvider.isBuffering
                              ? const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  playerProvider.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 38,
                                ),
                        ),
                      ),
                    ),

                    // Next Button
                    GestureDetector(
                      onTap: () => playerProvider.next(),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.skip_next_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),

                    // Repeat Button
                    IconButton(
                      icon: Icon(
                        playerProvider.repeatMode == AudioServiceRepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: playerProvider.repeatMode != AudioServiceRepeatMode.none
                            ? AppColors.primary
                            : AppColors.textMuted,
                        size: 22,
                      ),
                      onPressed: () => playerProvider.toggleRepeat(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // "Open queue" button matching HTML prototype
                GestureDetector(
                  onTap: () => QueueBottomSheet.show(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x14FFFFFF), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.queue_music_rounded, color: AppColors.primaryLight, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Open queue (${playerProvider.queue.length})',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context, dynamic track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded, color: AppColors.primaryLight),
                title: const Text('Add to Playlist', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  AddToPlaylistSheet.show(context, track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bedtime_rounded, color: AppColors.secondary),
                title: const Text('Sleep Timer', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  SleepTimerSheet.show(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
