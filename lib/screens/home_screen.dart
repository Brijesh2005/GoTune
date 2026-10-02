import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/unified_playback_controller.dart';
import '../providers/library_provider.dart';
import '../providers/music_provider.dart';
import '../services/builtin_playlists_service.dart';
import '../theme/app_colors.dart';
import '../screens/artist_screen.dart';
import '../widgets/mix_card.dart';
import '../widgets/track_card.dart';
import '../widgets/yt_filter_chips.dart';
import '../widgets/yt_hits_shelf.dart';
import '../widgets/yt_quick_picks_grid.dart';

/// Modern YouTube-Music personal music discovery dashboard.
/// Features filter chips (Podcasts, Romance, Relax, etc.),
/// Quick Picks 4-row grid, India's biggest hits shelf, Made For You mixes,
/// Recommended Songs, Favorite Artists, and Trending tracks.
class HomeScreen extends StatefulWidget {
  final VoidCallback onSearchTapped;
  final VoidCallback? onProfileTapped;
  final VoidCallback onLibraryTapped;

  const HomeScreen({
    super.key,
    required this.onSearchTapped,
    this.onProfileTapped,
    required this.onLibraryTapped,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final musicProvider = context.watch<MusicProvider>();
    final libraryProvider = context.watch<LibraryProvider>();
    final audioPlayer = context.read<UnifiedPlaybackController>();

    final recents = libraryProvider.recentlyPlayed;
    final mixes = musicProvider.personalizedMixes;
    final quickPicks = musicProvider.quickPicks.isNotEmpty
        ? musicProvider.quickPicks
        : BuiltinPlaylistsService.curatedQuickPicks;
    final recommended = musicProvider.recommendedForYou;
    final trending = musicProvider.trendingTracks;
    final builtinPlaylists = BuiltinPlaylistsService.getBuiltinPlaylists();
    final becauseTracks = musicProvider.becauseYouListenedTracks;
    final becauseArtist = musicProvider.becauseYouListenedArtist;
    final favoriteArtists = musicProvider.favoriteArtists;
    final mostPlayed = musicProvider.mostPlayed;
    final onRepeat = musicProvider.onRepeat;
    final rediscover = musicProvider.rediscover;
    final discovery = musicProvider.discoveryTracks;
    final genreFacets = musicProvider.genres;
    final genres = genreFacets.isNotEmpty
        ? genreFacets.map((g) => g.title).toList()
        : const <String>[
            'Bollywood',
            'Pop',
            'Hip Hop',
            'Punjabi',
            'Rock',
            'Indie',
            'Electronic',
            'R&B',
            'Classical',
            'Jazz',
          ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceElevated,
          onRefresh: () async {
            await Future.wait([
              musicProvider.loadHomeData(),
              Future.sync(() => libraryProvider.loadLibrary()),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              // 1. YouTube Music Filter Chips Row
              YtFilterChips(
                selectedChip: _selectedFilter,
                onChipSelected: (chip) {
                  setState(() => _selectedFilter = chip);
                  if (chip != null) {
                    musicProvider.setDiscoveryGenre(chip);
                  }
                },
              ),
              const SizedBox(height: 28),

              // 2. Section 1: "Quick picks" 4-row grid matching YouTube Music
              YtQuickPicksGrid(
                tracks: quickPicks,
                onPlayAll: () {
                  if (quickPicks.isNotEmpty) {
                    audioPlayer.playTrack(
                      quickPicks.first,
                      playlist: quickPicks,
                      initialIndex: 0,
                    );
                  }
                },
              ),
              const SizedBox(height: 38),

              // 3. Section 2: "MUSIC THAT'S HOT AND HAPPENING! / India's biggest hits"
              YtHitsShelf(playlists: builtinPlaylists),
              const SizedBox(height: 38),

              // 4. Recently Played Shelf
              if (recents.isNotEmpty) ...[
                _buildSectionHeader(
                  'Recently Played',
                  actionLabel: 'See all',
                  onAction: widget.onLibraryTapped,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 215,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: recents.length,
                    itemBuilder: (context, index) {
                      final item = recents[index];
                      return TrackCard(
                        track: item.track,
                        queue: recents.map((r) => r.track).toList(),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // 5. Made For You / Personalized Mixes Carousel
              if (mixes.isNotEmpty) ...[
                _buildSectionHeader('Made For You', subtitle: 'Personalized blends updated daily'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 130,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: mixes.length,
                    itemBuilder: (context, index) {
                      final mix = mixes[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: MixCard(
                          mix: mix,
                          onTap: () {
                            if (mix.tracks.isNotEmpty) {
                              audioPlayer.playTrack(
                                mix.tracks.first,
                                playlist: mix.tracks,
                                initialIndex: 0,
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // 6. Because You Listened To [Artist]
              if (becauseTracks.isNotEmpty && becauseArtist != null) ...[
                _buildSectionHeader(
                  'Because You Listened To $becauseArtist',
                  subtitle: 'Similar artists and compatible songs',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 215,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: becauseTracks.length,
                    itemBuilder: (context, index) {
                      final track = becauseTracks[index];
                      return TrackCard(
                        track: track,
                        queue: becauseTracks,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // 7. Recommended Songs Shelf
              if (recommended.isNotEmpty) ...[
                _buildSectionHeader('Recommended Songs', subtitle: 'Ranked for your music taste'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 215,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: recommended.length,
                    itemBuilder: (context, index) {
                      final track = recommended[index];
                      return TrackCard(
                        track: track,
                        queue: recommended,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // 8. Favorite Artists Shelf
              if (favoriteArtists.isNotEmpty) ...[
                _buildSectionHeader('Favorite Artists', subtitle: 'Tap to open artist or start radio'),
                const SizedBox(height: 14),
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: favoriteArtists.length,
                    itemBuilder: (context, index) {
                      final artistName = favoriteArtists[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArtistScreen(
                                artistId: artistName,
                                artistName: artistName,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 85,
                          margin: const EdgeInsets.only(right: 14),
                          child: Column(
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.primarySoft,
                                      AppColors.surfaceElevated,
                                    ],
                                  ),
                                  border: Border.all(color: AppColors.border, width: 1.5),
                                ),
                                child: const Center(
                                  child: Icon(Icons.person_rounded, color: AppColors.primary, size: 32),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 9. Quick Radio Stations
              _buildSectionHeader('Radio Stations', subtitle: 'Endless autoplay tuned to your vibe'),
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildRadioChip(
                      icon: Icons.radio_rounded,
                      label: 'Bollywood Radio',
                      color: const Color(0xFFE50914),
                      onTap: () => audioPlayer.startGenreRadio('Bollywood'),
                    ),
                    _buildRadioChip(
                      icon: Icons.graphic_eq_rounded,
                      label: 'Pop Hits Radio',
                      color: const Color(0xFF00B0FF),
                      onTap: () => audioPlayer.startGenreRadio('Pop'),
                    ),
                    _buildRadioChip(
                      icon: Icons.bolt_rounded,
                      label: 'EDM Party Radio',
                      color: const Color(0xFFFF9800),
                      onTap: () => audioPlayer.startGenreRadio('EDM'),
                    ),
                    _buildRadioChip(
                      icon: Icons.nightlife_rounded,
                      label: 'Punjabi Radio',
                      color: const Color(0xFF1DB954),
                      onTap: () => audioPlayer.startGenreRadio('Punjabi'),
                    ),
                    _buildRadioChip(
                      icon: Icons.spa_rounded,
                      label: 'Lofi Chill Radio',
                      color: const Color(0xFF9C27B0),
                      onTap: () => audioPlayer.startGenreRadio('Lofi'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 10. Trending & Popular Now
              _buildSectionHeader('Trending', subtitle: 'Most popular songs right now'),
              const SizedBox(height: 12),
              if (musicProvider.trendingState == LoadState.loading && trending.isEmpty)
                _buildShimmerLoader()
              else if (trending.isNotEmpty)
                SizedBox(
                  height: 215,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: trending.length,
                    itemBuilder: (context, index) {
                      final track = trending[index];
                      return TrackCard(
                        track: track,
                        queue: trending,
                      );
                    },
                  ),
                )
              else if (musicProvider.trendingState == LoadState.error)
                _buildErrorCard("Couldn't load trending tracks.", () {
                  musicProvider.fetchTrendingTracks();
                }),
              const SizedBox(height: 28),

              // 11. Most Played Shelf
              if (mostPlayed.isNotEmpty) ...[
                _buildSectionHeader('Most Played', subtitle: 'Your top heavy-rotation songs'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 215,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: mostPlayed.length,
                    itemBuilder: (context, index) {
                      final track = mostPlayed[index];
                      return TrackCard(
                        track: track,
                        queue: mostPlayed,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // 12. On Repeat Shelf
              if (onRepeat.isNotEmpty) ...[
                _buildSectionHeader('On Repeat', subtitle: 'Songs you keep coming back to'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 215,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: onRepeat.length,
                    itemBuilder: (context, index) {
                      final track = onRepeat[index];
                      return TrackCard(
                        track: track,
                        queue: onRepeat,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // 13. Rediscover Shelf
              if (rediscover.isNotEmpty) ...[
                _buildSectionHeader('Rediscover', subtitle: 'Past favorites to rekindle'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 215,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: rediscover.length,
                    itemBuilder: (context, index) {
                      final track = rediscover[index];
                      return TrackCard(
                        track: track,
                        queue: rediscover,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // 14. New / Discovery Section
              _buildSectionHeader('New & Discoveries', subtitle: 'Explore fresh releases'),
              const SizedBox(height: 12),
              if (musicProvider.discoveryState == LoadState.loading && discovery.isEmpty)
                _buildShimmerLoader()
              else if (discovery.isNotEmpty)
                SizedBox(
                  height: 215,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: discovery.length,
                    itemBuilder: (context, index) {
                      final track = discovery[index];
                      return TrackCard(
                        track: track,
                        queue: discovery,
                      );
                    },
                  ),
                )
              else if (musicProvider.discoveryState == LoadState.error)
                _buildErrorCard("Couldn't load discovery tracks.", () {
                  musicProvider.fetchDiscoveryTracks();
                }),
              const SizedBox(height: 28),

              // 15. Explore Genres Chips
              _buildSectionHeader('Genres & Moods', subtitle: 'Browse by mood and style'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: genres.map((genre) {
                  final isSelected = musicProvider.selectedGenre == genre;
                  return ActionChip(
                    backgroundColor: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceElevated,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: 1,
                      ),
                    ),
                    label: Text(
                      genre,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    onPressed: () {
                      musicProvider.setDiscoveryGenre(genre);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? subtitle, String? actionLabel, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(
                color: AppColors.primaryLight,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildShimmerLoader() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            width: 145,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorCard(String message, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
