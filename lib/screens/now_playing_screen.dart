import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audio_player_provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_colors.dart';
import '../utils/duration_formatter.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/animated_equalizer.dart';
import '../widgets/network_artwork.dart';
import '../widgets/queue_bottom_sheet.dart';
import '../widgets/sleep_timer_sheet.dart';

/// Full-screen now playing modal sheet with high-res cover art, seeker,
/// playback controls, playlist addition, favorite toggle, and queue drawer.
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
    final artSize = (size.width - 64).clamp(240.0, 360.0);

    final positionSeconds = playerProvider.position.inSeconds.toDouble();
    final durationSeconds = playerProvider.duration.inSeconds > 0
        ? playerProvider.duration.inSeconds.toDouble()
        : (track.durationSeconds > 0 ? track.durationSeconds.toDouble() : 1.0);

    final sliderValue = (_dragValue ?? positionSeconds).clamp(0.0, durationSeconds);

    return Container(
      height: size.height * 0.94,
      decoration: const BoxDecoration(
        gradient: AppColors.nowPlayingBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // Top action bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
                    color: AppColors.textPrimary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Column(
                    children: [
                      const Text(
                        'PLAYING FROM AUDIUS',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.genre.isNotEmpty ? track.genre : 'Catalog',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.bedtime_rounded,
                              color: playerProvider.isSleepTimerActive
                                  ? AppColors.primaryLight
                                  : AppColors.textPrimary,
                              size: 22,
                            ),
                            if (playerProvider.isSleepTimerActive)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: AppColors.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        tooltip: playerProvider.isSleepTimerActive
                            ? 'Sleep Timer: ${playerProvider.formattedSleepTimerRemaining}'
                            : 'Sleep Timer',
                        onPressed: () => SleepTimerSheet.show(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.playlist_add_rounded, color: AppColors.textPrimary, size: 24),
                        tooltip: 'Add to Playlist',
                        onPressed: () => AddToPlaylistSheet.show(context, track),
                      ),
                      IconButton(
                        icon: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.queue_music_rounded, color: AppColors.textPrimary, size: 24),
                            if (playerProvider.queue.isNotEmpty)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        tooltip: 'Queue',
                        onPressed: () => QueueBottomSheet.show(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Error banner if any
            if (playerProvider.hasError) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        playerProvider.errorMessage!,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        playerProvider.playTrack(track, playlist: playerProvider.queue);
                      },
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(flex: 1),

            // Large album artwork with glow shadow
            Container(
              width: artSize,
              height: artSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: NetworkArtwork(
                  imageUrl: track.bestArtworkUrl,
                  width: artSize,
                  height: artSize,
                  borderRadius: 22,
                ),
              ),
            ),

            const Spacer(flex: 1),

            // Title, Artist, Equalizer & Favorite heart button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (track.isArtistVerified) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                color: AppColors.secondary,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (playerProvider.isPlaying)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: AnimatedEqualizer(isPlaying: true, size: 22),
                    ),
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? AppColors.accentPink : AppColors.textMuted,
                      size: 26,
                    ),
                    tooltip: isFav ? 'Remove Favorite' : 'Favorite',
                    onPressed: () => libraryProvider.toggleFavorite(track),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Progress Slider & Timestamps
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primaryLight,
                      inactiveTrackColor: AppColors.border,
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 4,
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: sliderValue,
                      min: 0.0,
                      max: durationSeconds,
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          DurationFormatter.formatSeconds(durationSeconds.toInt()),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Main playback controls row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Shuffle
                  IconButton(
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: playerProvider.isShuffle
                          ? AppColors.primaryLight
                          : AppColors.textMuted,
                      size: 24,
                    ),
                    tooltip: 'Shuffle',
                    onPressed: () => playerProvider.toggleShuffle(),
                  ),

                  // Previous
                  IconButton(
                    icon: const Icon(
                      Icons.skip_previous_rounded,
                      color: AppColors.textPrimary,
                      size: 38,
                    ),
                    tooltip: 'Previous',
                    onPressed: () => playerProvider.previous(),
                  ),

                  // Big Glowing Play / Pause button
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: playerProvider.isBuffering
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            )
                          : IconButton(
                              icon: Icon(
                                playerProvider.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 38,
                              ),
                              tooltip: playerProvider.isPlaying ? 'Pause' : 'Play',
                              onPressed: () => playerProvider.togglePlayPause(),
                            ),
                    ),
                  ),

                  // Next
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      color: AppColors.textPrimary,
                      size: 38,
                    ),
                    tooltip: 'Next',
                    onPressed: () => playerProvider.next(),
                  ),

                  // Repeat
                  IconButton(
                    icon: Icon(
                      playerProvider.repeatMode == AudioServiceRepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: playerProvider.repeatMode != AudioServiceRepeatMode.none
                          ? AppColors.primaryLight
                          : AppColors.textMuted,
                      size: 24,
                    ),
                    tooltip: playerProvider.repeatMode == AudioServiceRepeatMode.one
                        ? 'Repeat: Current Track'
                        : (playerProvider.repeatMode == AudioServiceRepeatMode.all
                            ? 'Repeat: Queue'
                            : 'Repeat: Off'),
                    onPressed: () => playerProvider.toggleRepeat(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Bottom quick actions row (Sleep Timer, Add to Playlist, Queue)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Sleep Timer
                  Expanded(
                    child: InkWell(
                      onTap: () => SleepTimerSheet.show(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: playerProvider.isSleepTimerActive
                              ? AppColors.primary.withOpacity(0.15)
                              : AppColors.surfaceElevated.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: playerProvider.isSleepTimerActive
                                ? AppColors.primaryLight.withOpacity(0.6)
                                : AppColors.border.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bedtime_rounded,
                              color: playerProvider.isSleepTimerActive
                                  ? AppColors.primaryLight
                                  : AppColors.textSecondary,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                playerProvider.isSleepTimerActive
                                    ? playerProvider.formattedSleepTimerRemaining
                                    : 'Timer',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: playerProvider.isSleepTimerActive
                                      ? AppColors.primaryLight
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Add to Playlist
                  Expanded(
                    child: InkWell(
                      onTap: () => AddToPlaylistSheet.show(context, track),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border.withOpacity(0.5)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.playlist_add_rounded, color: AppColors.secondary, size: 18),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Playlist',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Queue
                  Expanded(
                    child: InkWell(
                      onTap: () => QueueBottomSheet.show(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.playlist_play_rounded, color: AppColors.primaryLight, size: 18),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Queue (${playerProvider.queue.length})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
