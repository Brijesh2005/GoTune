import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/unified_playback_controller.dart';
import '../services/playback/playback_backend.dart';
import '../providers/library_provider.dart';
import '../screens/artist_screen.dart';
import '../screens/song_screen.dart';
import '../theme/app_colors.dart';
import '../utils/duration_formatter.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/global_audio_player.dart';
import '../widgets/network_artwork.dart';
import '../widgets/queue_bottom_sheet.dart';
import '../widgets/sleep_timer_sheet.dart';

/// Full-screen now playing modal sheet inspired by modern music apps.
/// Features selective listening for zero-overhead scrubbing, lyrics interface,
/// and instant artist navigation.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  static Future<void> show(BuildContext context) {
    // The global mini player lives above the Navigator, so it must be told when
    // this full-screen sheet covers it.
    GlobalAudioPlayer.fullPlayerVisible.value = true;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NowPlayingScreen(),
    ).whenComplete(() {
      GlobalAudioPlayer.fullPlayerVisible.value = false;
    });
  }

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  double? _dragValue;
  bool _showLyrics = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncYouTubeSurface();
  }

  @override
  void dispose() {
    // The sheet is gone: hand the player back to the audio-first views. The
    // WebView itself is never destroyed, so playback continues uninterrupted.
    GlobalAudioPlayer.youtubeSurfaceRequested.value = false;
    super.dispose();
  }

  /// Reveals the one global IFrame surface while a YouTube track is loaded.
  void _syncYouTubeSurface() {
    final controller = context.read<UnifiedPlaybackController>();
    GlobalAudioPlayer.youtubeSurfaceRequested.value =
        controller.isYouTubeIframePlayback;
  }

  @override
  Widget build(BuildContext context) {
final playerProvider = context.watch<UnifiedPlaybackController>();
    final libraryProvider = context.watch<LibraryProvider>();
    final track = playerProvider.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;

    // A YouTube track is really playing inside the embedded IFrame player, so
    // this screen reveals that one global surface (created once, above the
    // Navigator) and insets its own layout to make room for it. No second
    // WebView is created and playback is never interrupted.
    final isYouTube = playerProvider.isYouTubeIframePlayback;
    final youtubeSurfaceHeight = GlobalAudioPlayer.youtubeSurfaceHeight(size.width);

    final isFav = libraryProvider.isFavorite(track.id);
    final artSize = (size.width - 48).clamp(240.0, 340.0);

    final durationSeconds = playerProvider.duration.inSeconds > 0
        ? playerProvider.duration.inSeconds.toDouble()
        : (track.durationSeconds > 0 ? track.durationSeconds.toDouble() : 1.0);

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
            // Reserve the exact band the global IFrame surface occupies.
            padding: EdgeInsets.fromLTRB(24, isYouTube ? youtubeSurfaceHeight + 8 : 16, 24, 16),
            child: Column(
              children: [
                // Top Header Row
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
                const SizedBox(height: 20),

                // Autoplay refusal is a real browser outcome, so it gets a
                // clear recovery affordance: one tap replays through the
                // user's own gesture, which browsers always allow.
                if (playerProvider.youtubeAutoplayBlocked)
                  _buildAutoplayBlockedNotice(context),

                // Player or Artwork / Lyrics View.
                //
                // For a YouTube track the embedded video occupies the band
                // reserved above, so the cover art would be redundant.
                if (isYouTube)
                  const SizedBox.shrink()
                else if (_showLyrics)
                  _buildLyricsView(track, artSize)
                else
                  _buildArtworkView(track, artSize),
                SizedBox(height: isYouTube ? 0 : 24),

                // Title, Artist (tap to open ArtistScreen), and Like Button
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
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ArtistScreen(
                                    artistId: track.artistId ?? 'search_${track.artist.toLowerCase()}',
                                    artistName: track.artist,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Favorite Button
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
                const SizedBox(height: 18),

                // Range Progress Slider isolated via ValueListenableBuilder
                ValueListenableBuilder<Duration>(
                  valueListenable: playerProvider.positionNotifier,
                  builder: (context, pos, _) {
                    final currentPosSec = pos.inSeconds.toDouble();
                    final sliderVal = (_dragValue ?? currentPosSec).clamp(0.0, durationSeconds);
                    final remSec = (durationSeconds - sliderVal).clamp(0.0, durationSeconds);

                    return Column(
                      children: [
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
                            value: sliderVal,
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DurationFormatter.formatSeconds(sliderVal.toInt()),
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                              Text(
                                '-${DurationFormatter.formatSeconds(remSec.toInt())}',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),

                // Primary Playback Controls Row
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
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        child: const Center(
                          child: Icon(Icons.skip_previous_rounded, color: Colors.white, size: 30),
                        ),
                      ),
                    ),

                    // Large Play / Pause Button
                    GestureDetector(
                      onTap: () => playerProvider.togglePlayPause(),
                      child: Container(
                        width: 72,
                        height: 72,
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
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        child: const Center(
                          child: Icon(Icons.skip_next_rounded, color: Colors.white, size: 30),
                        ),
                      ),
                    ),

                    // Repeat Button
                    IconButton(
                      icon: Icon(
                        playerProvider.repeatMode == PlaybackRepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: playerProvider.repeatMode != PlaybackRepeatMode.none
                            ? AppColors.primary
                            : AppColors.textMuted,
                        size: 22,
                      ),
                      onPressed: () => playerProvider.toggleRepeat(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Lyrics Toggle & Queue Button
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _showLyrics ? AppColors.primary : AppColors.textSecondary,
                          side: BorderSide(
                            color: _showLyrics ? AppColors.primary : const Color(0x14FFFFFF),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.lyrics_rounded, size: 18),
                        label: Text(
                          _showLyrics ? 'Close Lyrics' : 'Lyrics',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        onPressed: () {
                          setState(() {
                            _showLyrics = !_showLyrics;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.textPrimary,
                          elevation: 0,
                          side: const BorderSide(color: Color(0x14FFFFFF)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.queue_music_rounded, color: AppColors.primaryLight, size: 18),
                        label: Text(
                          'Queue (${playerProvider.queue.length})',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        onPressed: () => QueueBottomSheet.show(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkView(Track track, double artSize) {
    return Container(
      width: artSize,
      height: artSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 36,
            offset: Offset(0, 16),
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
                decoration: const BoxDecoration(gradient: AppColors.artTileGradient),
                child: const Center(
                  child: Icon(Icons.music_note_rounded, color: AppColors.primaryLight, size: 80),
                ),
              ),
      ),
    );
  }

  /// One-tap recovery when the embedded player refused to autoplay.
  Widget _buildAutoplayBlockedNotice(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => context.read<UnifiedPlaybackController>().retryYouTubeAutoplay(),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
          ),
          child: const Row(
            children: [
              Icon(Icons.play_circle_outline_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tap to start playback',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsView(Track track, double artSize) {
    return Container(
      width: artSize,
      height: artSize,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lyrics_rounded, size: 36, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            'Lyrics for "${track.title}"',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'by ${track.artist}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            '♪ Synchronized lyrics are being processed for this track. Enjoy the music!',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
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
                leading: const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight),
                title: const Text('Song Details & Related', style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('View metadata, playback sources & related tracks', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  SongScreen.open(context, track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.radio_rounded, color: AppColors.primary),
                title: const Text('Start Song Radio', style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('Generate endless dynamic mix from this track', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<UnifiedPlaybackController>().startSongRadio(track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_rounded, color: AppColors.primaryLight),
                title: Text('View Artist (${track.artist})', style: const TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ArtistScreen(artistName: track.artist)),
                  );
                },
              ),
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
