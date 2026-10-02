import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/track.dart';
import '../providers/unified_playback_controller.dart';
import '../providers/library_provider.dart';
import '../providers/music_provider.dart';
import '../screens/album_screen.dart';
import '../screens/artist_screen.dart';
import '../theme/app_colors.dart';
import '../utils/duration_formatter.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/network_artwork.dart';
import '../widgets/song_action_sheet.dart';
import '../widgets/track_tile.dart';

/// Content detail screen for an individual Track, conceptually derived from
/// YouTube-clone's watch page (`watch.$id.tsx`) transformed for native audio-only playback.
/// Displays song metadata, playback capabilities & sources, persistent playback controls,
/// and dynamically discovered related tracks via [MusicDiscoveryService].
class SongScreen extends StatefulWidget {
  final Track track;

  const SongScreen({super.key, required this.track});

  static void open(BuildContext context, Track track) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SongScreen(track: track)),
    );
  }

  @override
  State<SongScreen> createState() => _SongScreenState();
}

class _SongScreenState extends State<SongScreen> {
  List<Track> _relatedTracks = [];
  Artist? _artist;
  Album? _album;
  bool _isLoadingRelated = true;

  @override
  void initState() {
    super.initState();
    _fetchRelatedContent();
  }

  /// Loads the unified song-detail bundle: related tracks plus the artist and
  /// album credits, all resolved in a single call.
  Future<void> _fetchRelatedContent() async {
    final musicProvider = context.read<MusicProvider>();
    setState(() => _isLoadingRelated = true);

    try {
      final detail = await musicProvider.getSongDetail(widget.track);
      if (mounted) {
        setState(() {
          _relatedTracks = detail?.relatedTracks ?? const [];
          _artist = detail?.artist;
          _album = detail?.album;
          _isLoadingRelated = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingRelated = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<UnifiedPlaybackController>();
    final libraryProvider = context.watch<LibraryProvider>();
    final isCurrent = playerProvider.currentTrack?.id == widget.track.id;
    final isPlaying = isCurrent && playerProvider.isPlaying;
    final isFav = libraryProvider.isFavorite(widget.track.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Track Info',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? AppColors.accentPink : AppColors.textSecondary,
            ),
            onPressed: () => libraryProvider.toggleFavorite(widget.track),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
            onPressed: () => SongActionSheet.show(context, widget.track),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Hero Artwork & Metadata Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // Centered High-Res Artwork
                  Center(
                    child: Hero(
                      tag: 'song_art_${widget.track.id}',
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: NetworkArtwork(
                          imageUrl: widget.track.bestArtworkUrl,
                          width: 220,
                          height: 220,
                          borderRadius: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Song Title
                  Text(
                    widget.track.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Clickable Artist Name
                  GestureDetector(
                    onTap: () {
                      if (widget.track.artist.isNotEmpty && widget.track.artist != 'Unknown Artist') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ArtistScreen(
                              artistId: widget.track.artistId ?? '',
                              artistName: widget.track.artist,
                              initialArtworkUrl: widget.track.bestArtworkUrl,
                            ),
                          ),
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.track.artist,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.primaryLight,
                        ),
                      ],
                    ),
                  ),

                  // Clickable Album Name if present
                  if (widget.track.albumName != null && widget.track.albumName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        if (widget.track.albumId != null && widget.track.albumId!.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlbumScreen(
                                albumId: widget.track.albumId!,
                                albumName: widget.track.albumName!,
                                artistName: widget.track.artist,
                                initialArtworkUrl: widget.track.bestArtworkUrl,
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        widget.track.albumName!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Metadata Badges (Provider, Duration, Quality)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildChip(
                        icon: Icons.play_circle_fill_rounded,
                        label: 'YOUTUBE',
                        color: AppColors.primary,
                      ),
                      if (widget.track.durationSeconds > 0)
                        _buildChip(
                          icon: Icons.timer_outlined,
                          label: DurationFormatter.formatSeconds(widget.track.durationSeconds),
                          color: AppColors.textSecondary,
                        ),
                      if (widget.track.genre.isNotEmpty && widget.track.genre != 'Music')
                        _buildChip(
                          icon: Icons.music_note_rounded,
                          label: widget.track.genre,
                          color: AppColors.accentBlue,
                        ),
                      if (widget.track.explicit)
                        _buildChip(
                          icon: Icons.explicit_rounded,
                          label: 'EXPLICIT',
                          color: AppColors.accentPink,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Primary Playback Controls Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Play / Pause Main CTA
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 24),
                        label: Text(
                          isPlaying ? 'PAUSE' : 'PLAY',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        onPressed: () {
                          if (isPlaying) {
                            playerProvider.pause();
                          } else if (isCurrent) {
                            playerProvider.play();
                          } else {
                            playerProvider.playTrack(widget.track);
                          }
                        },
                      ),
                      const SizedBox(width: 12),

                      // Start Radio CTA
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        icon: const Icon(Icons.radio_rounded, size: 18, color: AppColors.accentBlue),
                        label: const Text(
                          'Radio',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                        onPressed: () {
                          playerProvider.playWithSmartRadio(widget.track);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Starting smart radio for "${widget.track.title}"'),
                              backgroundColor: AppColors.surfaceElevated,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Secondary Quick Action Icon Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickAction(
                        icon: Icons.playlist_play_rounded,
                        label: 'Play Next',
                        onTap: () {
                          playerProvider.playNext(widget.track);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Playing next: "${widget.track.title}"'),
                              backgroundColor: AppColors.surfaceElevated,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      _buildQuickAction(
                        icon: Icons.queue_music_rounded,
                        label: 'Add to Queue',
                        onTap: () {
                          playerProvider.addToQueue(widget.track);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added to queue: "${widget.track.title}"'),
                              backgroundColor: AppColors.surfaceElevated,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      _buildQuickAction(
                        icon: Icons.playlist_add_rounded,
                        label: 'Add to Playlist',
                        onTap: () => AddToPlaylistSheet.show(context, widget.track),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Divider(color: Color(0x1AFFFFFF), height: 1),
            ),
          ),

          // 2. Artist / Album credits resolved with the same call that produced the
          // related shelf. Tapping either navigates to its detail page.
          if (_artist != null || _album != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (_artist != null)
                      _CreditChip(
                        icon: Icons.person_rounded,
                        label: _artist!.name,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ArtistScreen(
                              artistId: _artist!.id,
                              artistName: _artist!.name,
                              initialArtworkUrl: _artist!.artworkUrl,
                            ),
                          ),
                        ),
                      ),
                    if (_album != null)
                      _CreditChip(
                        icon: Icons.album_rounded,
                        label: _album!.name,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AlbumScreen(
                              albumId: _album!.id,
                              albumName: _album!.name,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // 4. Up Next / Related Tracks (YouTube-clone watch/related concept)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Up Next & Related Tracks',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_isLoadingRelated)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                ],
              ),
            ),
          ),

          if (_isLoadingRelated)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
            )
          else if (_relatedTracks.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Text(
                  'No related tracks found for this seed.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final relatedTrack = _relatedTracks[index];
                  return TrackTile(
                    track: relatedTrack,
                    playlist: _relatedTracks,
                    index: index,
                  );
                },
                childCount: _relatedTracks.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small tappable credit pill used for the artist and album resolved alongside
/// the related shelf.
class _CreditChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CreditChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primaryLight),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
