import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_constants.dart';
import '../models/playlist.dart';
import '../models/recently_played_item.dart';
import '../models/track.dart';
import '../providers/audio_player_provider.dart';
import '../providers/library_provider.dart';
import '../providers/music_provider.dart';
import '../screens/playlist_detail_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/error_view.dart';
import '../widgets/network_artwork.dart';
import '../widgets/section_header.dart';
import '../widgets/track_card.dart';
import '../widgets/track_tile.dart';

/// Modern dark Home screen featuring dynamic greetings, quick search jump,
/// horizontal scrolling sections for Trending, Playlists, Favorites, and Recently Played,
/// plus interactive genre discovery.
class HomeScreen extends StatelessWidget {
  final VoidCallback onSearchTapped;

  const HomeScreen({super.key, required this.onSearchTapped});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = context.watch<MusicProvider>();
    final libraryProvider = context.watch<LibraryProvider>();

    return Scaffold(
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
          child: CustomScrollView(
            slivers: [
              // Top Bar with Greeting & Logo
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Gojo Music',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: AppColors.secondary, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Saavn & Audius',
                              style: TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Quick Search jump bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: InkWell(
                    onTap: onSearchTapped,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Search songs, Bollywood, artists, Phonk...',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // SECTION 1: Trending Tracks Carousel
              const SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Trending on Audius',
                  subtitle: 'Top tracks streaming right now',
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 215,
                  child: _buildTrendingContent(musicProvider),
                ),
              ),

              // SECTION 2: User Playlists (Horizontal Carousel)
              if (libraryProvider.playlists.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: SectionHeader(
                      title: 'Your Playlists',
                      subtitle: 'Personal curated music collections',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 195,
                    child: _buildPlaylistsCarousel(context, libraryProvider.playlists),
                  ),
                ),
              ],

              // SECTION 3: Favorites (Horizontal Carousel)
              if (libraryProvider.favorites.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: SectionHeader(
                      title: 'Favorite Tracks',
                      subtitle: 'Songs you love and saved',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 215,
                    child: _buildFavoritesCarousel(libraryProvider.favorites),
                  ),
                ),
              ],

              // SECTION 4: Recently Played (Horizontal Carousel)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: SectionHeader(
                    title: 'Recently Played',
                    subtitle: 'Jump back into your recent history',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildRecentlyPlayed(context, libraryProvider.recentlyPlayed),
              ),

              // SECTION 5: Popular & Discovery
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const SectionHeader(
                      title: 'Popular & Discovery',
                      subtitle: 'Explore fresh soundscapes by genre',
                    ),
                    _buildGenreFilterChips(musicProvider),
                    const SizedBox(height: 6),
                  ],
                ),
              ),

              // Discovery Tracks List
              _buildDiscoveryContent(musicProvider),

              // Bottom padding so contents are not hidden behind MiniPlayer & Nav
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SECTION WIDGETS ---

  Widget _buildTrendingContent(MusicProvider music) {
    if (music.trendingState == LoadState.loading && music.trendingTracks.isEmpty) {
      return ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        itemBuilder: (context, index) => Container(
          width: 145,
          margin: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }

    if (music.trendingState == LoadState.error && music.trendingTracks.isEmpty) {
      return ErrorView(
        message: music.trendingError,
        onRetry: () => music.fetchTrendingTracks(),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: music.trendingTracks.length,
      itemBuilder: (context, index) {
        final track = music.trendingTracks[index];
        return TrackCard(
          track: track,
          queue: music.trendingTracks,
        );
      },
    );
  }

  Widget _buildPlaylistsCarousel(BuildContext context, List<Playlist> playlists) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return Container(
          width: 140,
          margin: const EdgeInsets.only(right: 14),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
                ),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: playlist.coverArtworkUrl.isNotEmpty
                      ? NetworkArtwork(
                          imageUrl: playlist.coverArtworkUrl,
                          width: 140,
                          height: 140,
                          borderRadius: 14,
                        )
                      : Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            gradient: AppColors.cardGradient,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.queue_music_rounded,
                              color: AppColors.primaryLight,
                              size: 40,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${playlist.trackCount} track${playlist.trackCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavoritesCarousel(List<Track> favorites) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final track = favorites[index];
        return TrackCard(
          track: track,
          queue: favorites,
        );
      },
    );
  }

  Widget _buildRecentlyPlayed(BuildContext context, List<RecentlyPlayedItem> recents) {
    if (recents.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, color: AppColors.primaryLight, size: 24),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No recently played tracks yet',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Play any track from Trending or Search to see your listening history here.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final tracksQueue = recents.map((item) => item.track).toList();

    return SizedBox(
      height: 215,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: recents.length > 15 ? 15 : recents.length,
        itemBuilder: (context, index) {
          final item = recents[index];
          final track = item.track;

          return Container(
            width: 145,
            margin: const EdgeInsets.only(right: 14),
            child: InkWell(
              onTap: () {
                context.read<AudioPlayerProvider>().playTrack(track, playlist: tracksQueue);
              },
              borderRadius: BorderRadius.circular(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      NetworkArtwork(
                        imageUrl: track.bestArtworkUrl,
                        width: 145,
                        height: 145,
                        borderRadius: 14,
                      ),
                      // Time badge on top-left
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.relativeTime,
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      // Play icon on bottom-right
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
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
          );
        },
      ),
    );
  }

  Widget _buildGenreFilterChips(MusicProvider music) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: AppConstants.discoveryGenres.length,
        itemBuilder: (context, index) {
          final genre = AppConstants.discoveryGenres[index];
          final isSelected = music.selectedGenre == genre;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(genre),
              selected: isSelected,
              showCheckmark: false,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              backgroundColor: AppColors.surfaceElevated,
              selectedColor: AppColors.primary,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              onSelected: (_) {
                music.setDiscoveryGenre(genre);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiscoveryContent(MusicProvider music) {
    if (music.discoveryState == LoadState.loading && music.discoveryTracks.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    if (music.discoveryState == LoadState.error && music.discoveryTracks.isEmpty) {
      return SliverToBoxAdapter(
        child: ErrorView(
          message: music.discoveryError,
          onRetry: () => music.fetchDiscoveryTracks(),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final track = music.discoveryTracks[index];
          return TrackTile(
            track: track,
            queue: music.discoveryTracks,
          );
        },
        childCount: music.discoveryTracks.length,
      ),
    );
  }
}
