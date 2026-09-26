import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../providers/audio_player_provider.dart';
import '../providers/library_provider.dart';
import '../providers/music_provider.dart';
import '../screens/now_playing_screen.dart';
import '../screens/playlist_detail_screen.dart';
import '../services/builtin_playlists_service.dart';
import '../theme/app_colors.dart';
import '../widgets/network_artwork.dart';
import '../widgets/track_tile.dart';

/// Redesigned Home screen matching the Pulse modern dark aesthetic,
/// featuring dynamic greetings, quick search jump, recently played history,
/// and instant one-tap built-in playlist playback.
class HomeScreen extends StatelessWidget {
  final VoidCallback onSearchTapped;
  final VoidCallback onProfileTapped;
  final VoidCallback onLibraryTapped;

  const HomeScreen({
    super.key,
    required this.onSearchTapped,
    required this.onProfileTapped,
    required this.onLibraryTapped,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getFormattedDate() {
    return DateFormat('EEEE, d MMMM').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = context.watch<MusicProvider>();
    final libraryProvider = context.watch<LibraryProvider>();
    final audioPlayer = context.read<AudioPlayerProvider>();

    final featuredPlaylist = BuiltinPlaylistsService.getFeaturedPlaylist();
    final builtinPlaylists = BuiltinPlaylistsService.getBuiltinPlaylists();
    final recents = libraryProvider.recentlyPlayed;

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
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
            children: [
              // 1. Header with Date kicker & Profile button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getFormattedDate(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _getGreeting(),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ],
                  ),
                  // Profile button
                  GestureDetector(
                    onTap: onProfileTapped,
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
                          Icons.person_rounded,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. Search Shortcut Field
              GestureDetector(
                onTap: onSearchTapped,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search_rounded, color: AppColors.textMuted, size: 22),
                      SizedBox(width: 12),
                      Text(
                        'Search songs, artists, albums',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // 3. Recently Played Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recently played',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: onLibraryTapped,
                    child: const Text(
                      'Your library',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (recents.isNotEmpty)
                ...recents.take(3).map((item) {
                  return _buildTrackRow(
                    context: context,
                    track: item.track,
                    audioPlayer: audioPlayer,
                  );
                })
              else if (musicProvider.trendingTracks.isNotEmpty)
                ...musicProvider.trendingTracks.take(3).map((track) {
                  return _buildTrackRow(
                    context: context,
                    track: track,
                    audioPlayer: audioPlayer,
                  );
                })
              else
                _buildEmptyRecentPlaceholder(),
              const SizedBox(height: 28),

              // 4. Made For You: Featured Built-in Playlist Card
              const Text(
                'Made for you',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              _buildFeaturedCard(context, featuredPlaylist, audioPlayer),
              const SizedBox(height: 28),

              // 5. Curated Built-in Playlists
              const Text(
                'Curated playlists',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 155,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: builtinPlaylists.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final playlist = builtinPlaylists[index];
                    return _buildCuratedPlaylistCard(context, playlist, audioPlayer);
                  },
                ),
              ),
              const SizedBox(height: 28),

              // 6. Popular & Trending Hits
              const Text(
                'Popular & Trending',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (musicProvider.trendingState == LoadState.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (musicProvider.trendingTracks.isNotEmpty)
                ...musicProvider.trendingTracks.skip(3).take(8).map((track) {
                  return _buildTrackRow(
                    context: context,
                    track: track,
                    audioPlayer: audioPlayer,
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a clean interactive track row matching the HTML prototype
  Widget _buildTrackRow({
    required BuildContext context,
    required Track track,
    required AudioPlayerProvider audioPlayer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            audioPlayer.playTrack(track);
            NowPlayingScreen.show(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Art Tile
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: track.thumbnailArtworkUrl.isNotEmpty
                      ? NetworkArtwork(
                          imageUrl: track.thumbnailArtworkUrl,
                          width: 48,
                          height: 48,
                          borderRadius: 12,
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            gradient: AppColors.artTileGradient,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.music_note_rounded,
                              color: AppColors.primaryLight,
                              size: 22,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 14),

                // Title + Subtitle
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${track.artist} · ${track.genre}',
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

                // Duration
                Text(
                  track.formattedDuration,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyRecentPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Text(
          'Your recently played tracks will show up here.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
    );
  }

  /// Builds the featured "Daily Mix" card matching the HTML prototype
  Widget _buildFeaturedCard(
    BuildContext context,
    Playlist playlist,
    AudioPlayerProvider audioPlayer,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Area with Overlay Text
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
                ),
              );
            },
            child: Stack(
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF0F1A24)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Opacity(
                    opacity: 0.45,
                    child: Image.network(
                      'https://images.pexels.com/photos/11398246/pexels-photo-11398246.jpeg?auto=compress&cs=tinysrgb&w=1280',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.headphones_rounded, size: 70, color: AppColors.primaryLight),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Color(0xCC101215)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  bottom: 16,
                  right: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DAILY MIX',
                        style: TextStyle(
                          color: Color(0xFF93C5FD),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        playlist.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Info & Instant Play Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    playlist.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Play button with immediate queue start
                GestureDetector(
                  onTap: () {
                    if (playlist.tracks.isNotEmpty) {
                      audioPlayer.playTrack(
                        playlist.tracks.first,
                        playlist: playlist.tracks,
                      );
                      NowPlayingScreen.show(context);
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds horizontal cards for additional built-in playlists
  Widget _buildCuratedPlaylistCard(
    BuildContext context,
    Playlist playlist,
    AudioPlayerProvider audioPlayer,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
          ),
        );
      },
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.artTileGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.music_note_rounded, color: AppColors.primaryLight, size: 22),
                  ),
                ),
                // Instant play icon
                GestureDetector(
                  onTap: () {
                    if (playlist.tracks.isNotEmpty) {
                      audioPlayer.playTrack(
                        playlist.tracks.first,
                        playlist: playlist.tracks,
                      );
                      NowPlayingScreen.show(context);
                    }
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFF282E36),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${playlist.tracks.length} tracks · Tap to play',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
