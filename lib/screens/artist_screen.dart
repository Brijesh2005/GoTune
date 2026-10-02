import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/artist.dart';
import '../providers/unified_playback_controller.dart';
import '../providers/music_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/network_artwork.dart';
import '../widgets/track_tile.dart';

/// Screen displaying artist details, popular songs, and related sibling artists.
class ArtistScreen extends StatefulWidget {
  final String artistId;
  final String artistName;
  final String? initialArtworkUrl;

  const ArtistScreen({
    super.key,
    this.artistId = '',
    required this.artistName,
    this.initialArtworkUrl,
  });

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  Artist? _artist;
  bool _isLoading = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _loadArtistDetails();
  }

  Future<void> _loadArtistDetails() async {
    final musicProvider = context.read<MusicProvider>();
    Artist? artist;
    if (widget.artistId.isNotEmpty) {
      artist = await musicProvider.getArtistDetails(widget.artistId);
    } else {
      final tracks = await musicProvider.searchTracks(widget.artistName);
      if (tracks.isNotEmpty) {
        artist = Artist(
          id: widget.artistId,
          name: widget.artistName,
          artworkUrl: tracks.first.bestArtworkUrl,
          popularTracks: tracks,
        );
      }
    }

    if (mounted) {
      setState(() {
        _artist = artist;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveName = _artist?.name ?? widget.artistName;
    final effectiveArtwork = _artist?.artworkUrl ?? widget.initialArtworkUrl ?? '';
    final popularTracks = _artist?.popularTracks ?? [];
    final siblings = context
        .read<MusicProvider>()
        .relatedArtistNames(effectiveName);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Dynamic Sliver App Bar
          SliverAppBar(
            expandedHeight: 280,
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
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                effectiveName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (effectiveArtwork.isNotEmpty)
                    NetworkArtwork(
                      imageUrl: effectiveArtwork,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 0,
                    )
                  else
                    Container(
                      color: AppColors.surfaceElevated,
                      child: const Center(
                        child: Icon(Icons.person_rounded, size: 80, color: AppColors.textMuted),
                      ),
                    ),
                  // Gradient overlay
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x99000000),
                          AppColors.background,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons: Play, Shuffle, Follow
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  // Play button
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
                      onPressed: popularTracks.isNotEmpty
                          ? () {
                              context.read<UnifiedPlaybackController>().playTrack(
                                    popularTracks.first,
                                    playlist: popularTracks,
                                    initialIndex: 0,
                                  );
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Shuffle button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceElevated,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.shuffle_rounded, size: 20),
                    label: const Text('Shuffle', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: popularTracks.isNotEmpty
                        ? () {
                            final shuffled = List.of(popularTracks)..shuffle();
                            context.read<UnifiedPlaybackController>().playTrack(
                                  shuffled.first,
                                  playlist: shuffled,
                                  initialIndex: 0,
                                );
                          }
                        : null,
                  ),
                  const SizedBox(width: 10),

                  // Artist Radio button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceElevated,
                      foregroundColor: AppColors.primaryLight,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.radio_rounded, size: 20),
                    label: const Text('Radio', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: () {
                      context.read<UnifiedPlaybackController>().startArtistRadio(
                            effectiveName,
                            seedTrack: popularTracks.isNotEmpty ? popularTracks.first : null,
                          );
                    },
                  ),
                  const SizedBox(width: 10),

                  // Follow / Favorite button
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceElevated,
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: Icon(
                      _isFollowing ? Icons.check_rounded : Icons.favorite_border_rounded,
                      color: _isFollowing ? AppColors.primary : AppColors.textPrimary,
                    ),
                    onPressed: () {
                      setState(() {
                        _isFollowing = !_isFollowing;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Popular Songs Header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Text(
                'Popular Songs',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // Popular Songs List
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
                ),
              ),
            )
          else if (popularTracks.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                child: Text(
                  'No tracks available for this artist.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = popularTracks[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: TrackTile(
                      track: track,
                      playlist: popularTracks,
                      index: index,
                    ),
                  );
                },
                childCount: popularTracks.length,
              ),
            ),

          // Similar Artists Section
          if (siblings.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 28, 18, 12),
                child: Text(
                  'Similar Artists',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  itemCount: siblings.length,
                  itemBuilder: (context, index) {
                    final sib = siblings[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        backgroundColor: AppColors.surfaceElevated,
                        label: Text(
                          sib,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        avatar: const Icon(Icons.person_rounded, size: 16, color: AppColors.textMuted),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ArtistScreen(
                                artistId: 'search_${sib.toLowerCase()}',
                                artistName: sib,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          ),
        ],
      ),
    );
  }
}
