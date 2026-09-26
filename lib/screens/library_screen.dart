import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../providers/audio_player_provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/network_artwork.dart';
import '../widgets/track_tile.dart';
import 'playlist_detail_screen.dart';

/// Complete Library Screen displaying Favorites, Custom Playlists,
/// and Recently Played listening history with persistent storage.
class LibraryScreen extends StatefulWidget {
  final VoidCallback onExploreTapped;

  const LibraryScreen({super.key, required this.onExploreTapped});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreatePlaylistDialog(BuildContext context, LibraryProvider library) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('New Playlist', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Playlist name',
                prefixIcon: Icon(Icons.queue_music_rounded, color: AppColors.primaryLight),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Optional description',
                prefixIcon: Icon(Icons.notes_rounded, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                library.createPlaylist(name, description: descController.text.trim());
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog(BuildContext context, LibraryProvider library) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Clear Listening History', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to clear your recently played history?', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              library.clearRecentlyPlayed();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final player = context.read<AudioPlayerProvider>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              // Top Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Library',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${library.favorites.length} Liked • ${library.playlists.length} Playlists',
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tab Bar (Favorites, Playlists, Recently Played)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textMuted,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
                    tabs: const [
                      Tab(text: 'Favorites'),
                      Tab(text: 'Playlists'),
                      Tab(text: 'Recently Played'),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildFavoritesTab(library, player),
              _buildPlaylistsTab(library),
              _buildRecentlyPlayedTab(library, player),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: FAVORITES
  // ==========================================

  Widget _buildFavoritesTab(LibraryProvider library, AudioPlayerProvider player) {
    final favorites = library.favorites;

    if (favorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_border_rounded, color: AppColors.accentPink, size: 42),
              ),
              const SizedBox(height: 18),
              const Text(
                'No favorite tracks yet',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the heart icon on any song to save it here for fast offline access and replay.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: widget.onExploreTapped,
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: const Text('Explore Music'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 120),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${favorites.length} Songs Saved',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  player.playTrack(favorites.first, playlist: favorites, initialIndex: 0);
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Play All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        ...favorites.map((track) {
          return TrackTile(
            track: track,
            queue: favorites,
          );
        }),
      ],
    );
  }

  // ==========================================
  // TAB 2: PLAYLISTS
  // ==========================================

  Widget _buildPlaylistsTab(LibraryProvider library) {
    final playlists = library.playlists;

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 120),
      children: [
        // "New Playlist" create button tile
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: InkWell(
            onTap: () => _showCreatePlaylistDialog(context, library),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.add_rounded, color: Colors.white, size: 24),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create Playlist', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text('Build your personal music collection', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
                ],
              ),
            ),
          ),
        ),

        if (playlists.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.queue_music_rounded, color: AppColors.textMuted, size: 40),
                  SizedBox(height: 12),
                  Text('No custom playlists yet', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Tap "Create Playlist" above to start curating songs.', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                ],
              ),
            ),
          )
        else
          ...playlists.map((playlist) => _buildPlaylistTile(library, playlist)),
      ],
    );
  }

  Widget _buildPlaylistTile(LibraryProvider library, Playlist playlist) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: playlist.coverArtworkUrl.isNotEmpty
            ? NetworkArtwork(imageUrl: playlist.coverArtworkUrl, width: 48, height: 48, borderRadius: 10)
            : Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.queue_music_rounded, color: AppColors.primaryLight, size: 24),
              ),
        title: Text(
          playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${playlist.trackCount} track${playlist.trackCount == 1 ? '' : 's'} • ${playlist.formattedTotalDuration}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => PlaylistDetailScreen(playlistId: playlist.id),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 3: RECENTLY PLAYED
  // ==========================================

  Widget _buildRecentlyPlayedTab(LibraryProvider library, AudioPlayerProvider player) {
    final recentItems = library.recentlyPlayed;

    if (recentItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, color: AppColors.textMuted, size: 40),
              SizedBox(height: 14),
              Text(
                'No listening history yet',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Tracks you stream will automatically appear here with exact playback timestamps.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
    }

    final recentTracks = recentItems.map((i) => i.track).toList();

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 120),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${recentItems.length} Tracks Listened',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              TextButton.icon(
                onPressed: () => _showClearHistoryDialog(context, library),
                icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 18),
                label: const Text(
                  'Clear History',
                  style: TextStyle(color: AppColors.error, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        ...recentItems.map((item) {
          return InkWell(
            onTap: () {
              player.playTrack(item.track, playlist: recentTracks);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  NetworkArtwork(imageUrl: item.track.thumbnailArtworkUrl, width: 48, height: 48, borderRadius: 10),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                            const SizedBox(width: 6),
                            Text(
                              item.relativeTime,
                              style: const TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(item.track.formattedDuration, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
