import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/album.dart';
import '../providers/unified_playback_controller.dart';
import '../providers/music_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/network_artwork.dart';
import '../widgets/track_tile.dart';

/// Screen displaying album artwork, metadata, and track listing.
class AlbumScreen extends StatefulWidget {
  final String albumId;
  final String albumName;
  final String? artistName;
  final String? initialArtworkUrl;

  const AlbumScreen({
    super.key,
    required this.albumId,
    required this.albumName,
    this.artistName,
    this.initialArtworkUrl,
  });

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  Album? _album;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbumDetails();
  }

  Future<void> _loadAlbumDetails() async {
    final musicProvider = context.read<MusicProvider>();
    final album = await musicProvider.getAlbumDetails(widget.albumId);
    if (mounted) {
      setState(() {
        _album = album;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTitle = _album?.name ?? widget.albumName;
    final effectiveArtist = _album?.artist ?? widget.artistName ?? 'Various Artists';
    final effectiveArtwork = _album?.artworkUrl ?? widget.initialArtworkUrl ?? '';
    final tracks = _album?.tracks ?? [];
    final year = _album?.year;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0x66000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              effectiveTitle,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (tracks.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.queue_music_rounded, color: AppColors.primaryLight),
                  tooltip: 'Queue Album',
                  onPressed: () {
                    context.read<UnifiedPlaybackController>().addPlaylistToQueue(tracks);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added ${tracks.length} songs from "$effectiveTitle" to queue'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
            ],
          ),

          // Header: Album Artwork & Metadata
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  // Center Artwork
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: effectiveArtwork.isNotEmpty
                            ? NetworkArtwork(
                                imageUrl: effectiveArtwork,
                                width: 200,
                                height: 200,
                                borderRadius: 16,
                              )
                            : Container(
                                color: AppColors.surfaceElevated,
                                child: const Center(
                                  child: Icon(Icons.album_rounded, size: 64, color: AppColors.textMuted),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Album Title
                  Text(
                    effectiveTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Artist Name & Details
                  Text(
                    effectiveArtist,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Year & Track Count
                  Text(
                    [
                      'Album',
                      if (year != null) '$year',
                      if (tracks.isNotEmpty) '${tracks.length} songs',
                    ].join(' • '),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Play and Shuffle buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 24),
                          label: const Text(
                            'Play',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          onPressed: tracks.isNotEmpty
                              ? () {
                                  context.read<UnifiedPlaybackController>().playTrack(
                                        tracks.first,
                                        playlist: tracks,
                                        initialIndex: 0,
                                      );
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceElevated,
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.shuffle_rounded, size: 20),
                          label: const Text(
                            'Shuffle',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          onPressed: tracks.isNotEmpty
                              ? () {
                                  final shuffled = List.of(tracks)..shuffle();
                                  context.read<UnifiedPlaybackController>().playTrack(
                                        shuffled.first,
                                        playlist: shuffled,
                                        initialIndex: 0,
                                      );
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Divider
          const SliverToBoxAdapter(
            child: Divider(color: AppColors.border, height: 1),
          ),

          // Track List
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
                ),
              ),
            )
          else if (tracks.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No tracks available for this album.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = tracks[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TrackTile(
                      track: track,
                      playlist: tracks,
                      index: index,
                    ),
                  );
                },
                childCount: tracks.length,
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          ),
        ],
      ),
    );
  }
}
