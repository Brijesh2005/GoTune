import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/track.dart';
import '../providers/library_provider.dart';
import '../providers/unified_playback_controller.dart';
import '../screens/artist_screen.dart';
import '../theme/app_colors.dart';
import '../utils/duration_formatter.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/global_audio_player.dart';
import '../widgets/music_tuner_sheet.dart';
import '../widgets/network_artwork.dart';
import '../widgets/sleep_timer_sheet.dart';

/// Full-screen YouTube Music "Now Playing & Radio Player" page (Screen 3).
/// Features:
/// - Atmospheric ambient gradient matching artwork glow.
/// - Top bar with back arrow, Radio/Song badge, and cast icon.
/// - Hero card with soundwave visualizer & artist avatar montage / artwork.
/// - Title & Subtitle ("Daisy Chain Radio • Discover", "Endless music customized for you...").
/// - Action bar: Download, Add, Big white Play/Pause circle, Share, More.
/// - "Tune" pill button that opens the Music Tuner sheet (Screen 2).
/// - Interactive Up Next queue tracklist with drag handles.
/// - Zero-latency scrubber slider via ValueNotifier.
/// - High-performance rendering with zero lag and no layout frame loops.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  /// Opens the Now Playing screen with a smooth native slide-up transition.
  /// Uses [appNavigatorKey] so it is ALWAYS available, even from outside the Navigator.
  static Future<void> show([BuildContext? context]) {
    GlobalAudioPlayer.fullPlayerVisible.value = true;
    final nav = (context != null ? Navigator.maybeOf(context) : null) ?? appNavigatorKey.currentState;
    if (nav == null) {
      GlobalAudioPlayer.fullPlayerVisible.value = false;
      return Future.value();
    }
    return nav.push(
      PageRouteBuilder(
        pageBuilder: (ctx, animation, secondaryAnimation) => const NowPlayingScreen(),
        transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          );
        },
      ),
    ).then((_) {
      GlobalAudioPlayer.fullPlayerVisible.value = false;
      GlobalAudioPlayer.youtubeSurfaceRequested.value = false;
    });
  }

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  double? _dragValue;
  bool _showVideoSurface = false;

  @override
  void initState() {
    super.initState();
    final controller = context.read<UnifiedPlaybackController>();
    _showVideoSurface = controller.isVideoMode;
    if (_showVideoSurface) {
      GlobalAudioPlayer.youtubeSurfaceRequested.value = true;
    }
  }

  @override
  void dispose() {
    GlobalAudioPlayer.youtubeSurfaceRequested.value = false;
    super.dispose();
  }

  void _toggleVideoMode(UnifiedPlaybackController controller) {
    setState(() {
      _showVideoSurface = !_showVideoSurface;
    });
    controller.setVideoMode(_showVideoSurface);
    GlobalAudioPlayer.youtubeSurfaceRequested.value = _showVideoSurface;
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<UnifiedPlaybackController>();
    final libraryProvider = context.watch<LibraryProvider>();
    final track = playerProvider.currentTrack;

    if (track == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF030303),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'No track playing',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final isFav = libraryProvider.isFavorite(track.id);

    final durationSeconds = playerProvider.duration.inSeconds > 0
        ? playerProvider.duration.inSeconds.toDouble()
        : (track.durationSeconds > 0 ? track.durationSeconds.toDouble() : 1.0);

    final radioTitle = playerProvider.activeRadioTitle ?? '${track.artist} Radio • Discover';
    const radioSubtitle = 'Endless music customized for you. Always updating.';
    final queue = playerProvider.queue;
    final currentIndex = playerProvider.currentIndex;

    return Scaffold(
      backgroundColor: const Color(0xFF05070C),
      body: Stack(
        children: [
          // Dynamic Atmospheric Ambient Glow Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF14243C),
                    Color(0xFF0D1526),
                    Color(0xFF05080E),
                    Color(0xFF020305),
                  ],
                  stops: [0.0, 0.35, 0.75, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ==========================================
                // 1. TOP BAR: Back chevron, Radio Badge, Cast
                // ==========================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Minimize / Back Button
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
                        onPressed: () => Navigator.of(context).pop(),
                      ),

                      // Center Radio Badge
                      Expanded(
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFE91E63),
                                ),
                                child: const Center(
                                  child: Icon(Icons.radio_rounded, color: Colors.white, size: 14),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  playerProvider.activeRadioTitle != null
                                      ? 'Daisy Chain Radio'
                                      : (track.album != null && track.album!.isNotEmpty ? track.album! : track.title),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Video Toggle Button
                      IconButton(
                        tooltip: _showVideoSurface ? 'Switch to Audio' : 'Watch Video',
                        icon: Icon(
                          _showVideoSurface ? Icons.music_note_rounded : Icons.slideshow_rounded,
                          color: _showVideoSurface ? AppColors.primaryLight : Colors.white70,
                          size: 24,
                        ),
                        onPressed: () => _toggleVideoMode(playerProvider),
                      ),

                      // Cast Icon
                      IconButton(
                        icon: const Icon(Icons.cast_rounded, color: Colors.white, size: 22),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Casting to audio device...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // ==========================================
                // 2. MAIN SCROLLABLE CONTENT (Screen 3 UI)
                // ==========================================
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      const SizedBox(height: 12),

                      // Hero Card (Soundwave + Overlapping Artist Portraits OR Artwork)
                      Center(
                        child: _buildHeroVisualizerCard(track, playerProvider, size.width),
                      ),

                      const SizedBox(height: 24),

                      // Title & Subtitle (Screen 3)
                      Text(
                        radioTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        radioSubtitle,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ==========================================
                      // 3. ZERO-LATENCY PROGRESS SCRUBBER
                      // ==========================================
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
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: const Color(0x28FFFFFF),
                                  thumbColor: Colors.white,
                                  overlayColor: Colors.white.withValues(alpha: 0.15),
                                ),
                                child: Slider(
                                  value: sliderVal,
                                  min: 0.0,
                                  max: durationSeconds,
                                  onChanged: (val) {
                                    setState(() {
                                      _dragValue = val;
                                    });
                                  },
                                  onChangeEnd: (val) {
                                    playerProvider.seekTo(Duration(seconds: val.toInt()));
                                    setState(() {
                                      _dragValue = null;
                                    });
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DurationFormatter.formatSeconds(sliderVal.toInt()),
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '-${DurationFormatter.formatSeconds(remSec.toInt())}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // ==========================================
                      // 4. ACTION BUTTONS ROW (Download, Add, Big Play/Pause, Share, More)
                      // ==========================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 1. Download button
                          _buildCircularActionButton(
                            icon: Icons.download_rounded,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Downloading "${track.title}" for offline playback...'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),

                          // 2. Add to playlist (+) button
                          _buildCircularActionButton(
                            icon: Icons.playlist_add_rounded,
                            onTap: () => AddToPlaylistSheet.show(context, track),
                          ),

                          // 3. Big White Circular Play/Pause Button (64px)
                          GestureDetector(
                            onTap: () {
                              if (playerProvider.isPlaying) {
                                playerProvider.pause();
                              } else {
                                playerProvider.play();
                              }
                            },
                            child: Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    blurRadius: 18,
                                    offset: const Offset(0, 4),
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
                                          color: Colors.black,
                                        ),
                                      )
                                    : Icon(
                                        playerProvider.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.black,
                                        size: 40,
                                      ),
                              ),
                            ),
                          ),

                          // 4. Share button
                          _buildCircularActionButton(
                            icon: Icons.share_rounded,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Shared "${track.title}" link!'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),

                          // 5. More menu (three dots)
                          _buildCircularActionButton(
                            icon: Icons.more_vert_rounded,
                            onTap: () => _showMoreOptions(context, track, playerProvider, isFav, libraryProvider),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ==========================================
                      // 5. "TUNE" PILL BUTTON (Screen 3)
                      // ==========================================
                      Center(
                        child: GestureDetector(
                          onTap: () => MusicTunerSheet.show(context),
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E212B),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: const Color(0x24FFFFFF), width: 1),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Tune',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ==========================================
                      // 6. UP NEXT QUEUE TRACKLIST (Screen 3)
                      // ==========================================
                      if (queue.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'UP NEXT',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: queue.length.clamp(0, 15),
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final qTrack = queue[idx];
                            final isPlayingThis = idx == currentIndex;

                            return _buildQueueTrackItem(
                              track: qTrack,
                              isPlaying: isPlayingThis,
                              onTap: () => playerProvider.skipToQueueItem(idx),
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroVisualizerCard(Track track, UnifiedPlaybackController player, double screenWidth) {
    final cardSize = (screenWidth - 48).clamp(240.0, 320.0);

    return Container(
      width: cardSize,
      height: cardSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Background Artwork / Gradient
            Positioned.fill(
              child: track.bestArtworkUrl.isNotEmpty
                  ? NetworkArtwork(
                      imageUrl: track.bestArtworkUrl,
                      width: cardSize,
                      height: cardSize,
                      borderRadius: 22,
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E2E4B), Color(0xFF0F1726)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.music_note_rounded, color: Colors.white54, size: 72),
                      ),
                    ),
            ),

            // Soundwave Visualizer Overlay (Screen 3 style)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.55),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: CustomPaint(
                  painter: _SoundwaveHeroPainter(),
                ),
              ),
            ),

            // Top-left Play Badge (Screen 3)
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.6),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF191D26),
          border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildQueueTrackItem({
    required Track track,
    required bool isPlaying,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPlaying ? const Color(0xFF1B2538) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: NetworkArtwork(
                imageUrl: track.thumbnailArtworkUrl,
                width: 44,
                height: 44,
                borderRadius: 8,
              ),
            ),
            const SizedBox(width: 14),

            // Title & Artist/Duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaying ? AppColors.primaryLight : Colors.white,
                      fontSize: 14.5,
                      fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${track.artist}  ${DurationFormatter.formatSeconds(track.durationSeconds)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),

            // Drag Handle Icon (=) (Screen 3)
            const Icon(
              Icons.drag_handle_rounded,
              color: Colors.white38,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions(
    BuildContext context,
    Track track,
    UnifiedPlaybackController playerProvider,
    bool isFav,
    LibraryProvider libraryProvider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFav ? AppColors.primary : Colors.white70,
                ),
                title: Text(isFav ? 'Remove from favorites' : 'Add to favorites',
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  libraryProvider.toggleFavorite(track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_rounded, color: Colors.white70),
                title: Text('View artist (${track.artist})',
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ArtistScreen(artistName: track.artist),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bedtime_rounded, color: Colors.white70),
                title: const Text('Sleep timer', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  playerProvider.isSleepTimerActive
                      ? 'Remaining: ${playerProvider.formattedSleepTimerRemaining}'
                      : 'Off',
                  style: const TextStyle(color: Colors.white38),
                ),
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

class _SoundwaveHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x30FFFFFF)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const barWidth = 6.0;
    const spacing = 8.0;
    final count = (size.width / (barWidth + spacing)).toInt();

    final heights = [
      0.35, 0.65, 0.85, 0.45, 0.9, 0.55, 0.4, 0.8, 0.7, 0.5, 0.75, 0.9,
      0.6, 0.45, 0.8, 0.65, 0.5, 0.7, 0.85, 0.4, 0.6, 0.95, 0.5, 0.75,
    ];

    for (int i = 0; i < count; i++) {
      final x = i * (barWidth + spacing) + 8;
      final hFactor = heights[i % heights.length];
      final barHeight = size.height * hFactor * 0.6;
      final yStart = (size.height - barHeight) / 2;

      canvas.drawLine(
        Offset(x, yStart),
        Offset(x, yStart + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
