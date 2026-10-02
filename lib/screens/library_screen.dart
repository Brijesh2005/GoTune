import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../providers/unified_playback_controller.dart';
import '../providers/library_provider.dart';
import '../providers/music_provider.dart';
import '../screens/playlist_detail_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/track_tile.dart';

/// Redesigned Library Screen matching modern music app aesthetics,
/// featuring tabbed navigation for Playlists, Favorites, Recents, and Device Audio.
/// Supports automated built-in playlists (Liked Songs, Recently Played, Most Played, On Repeat, Rediscover),
/// and local device grouping by Songs, Albums, and Artists.
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'New Playlist',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final audioPlayer = context.read<UnifiedPlaybackController>();
    final music = context.watch<MusicProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Library',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_rounded, color: AppColors.primaryLight, size: 28),
                              tooltip: 'Create Playlist',
                              onPressed: () => _showCreatePlaylistDialog(context, library),
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings_rounded, color: AppColors.textPrimary, size: 22),
                              tooltip: 'Settings',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Custom Tab Bar: Playlists, Favorites, Recents
                    TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 2.5,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppColors.textMuted,
                      labelStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
                      dividerColor: const Color(0x1AFFFFFF),
                      tabs: const [
                        Tab(text: 'Playlists'),
                        Tab(text: 'Favorites'),
                        Tab(text: 'Recents'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPlaylistsTab(context, library, audioPlayer, music),
              _buildFavoritesTab(context, library, audioPlayer),
              _buildRecentsTab(context, library, audioPlayer),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // PLAYLISTS TAB
  // ==========================================
  Widget _buildPlaylistsTab(
    BuildContext context,
    LibraryProvider library,
    UnifiedPlaybackController audioPlayer,
    MusicProvider music,
  ) {
    final userPlaylists = library.playlists;
    final builtinPlaylists = library.builtinPlaylists;
    final favorites = library.favorites;
    final recents = library.recentlyPlayed.map((r) => r.track).toList();
    final mostPlayed = music.mostPlayed;
    final onRepeat = music.onRepeat;
    final rediscover = music.rediscover;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        // 1. Auto-Generated Smart Playlists
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'AUTO PLAYLISTS',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),

        // Liked Songs Auto Playlist
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildSurfaceRow(
            iconWidget: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE50914), Color(0xFF6B0E1A)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
              ),
            ),
            title: 'Liked Songs',
            subtitle: '${favorites.length} favorite songs',
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            onTap: () {
              final autoPl = Playlist(
                id: 'auto_liked',
                name: 'Liked Songs',
                description: 'Your favorite tracks in one place',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                tracks: favorites,
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailScreen(playlist: autoPl),
                ),
              );
            },
          ),
        ),

        // Recently Played Auto Playlist
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildSurfaceRow(
            iconWidget: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1DB954), Color(0xFF0F5A29)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.history_rounded, color: Colors.white, size: 24),
              ),
            ),
            title: 'Recently Played',
            subtitle: '${recents.length} played tracks',
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            onTap: () {
              final autoPl = Playlist(
                id: 'auto_recents',
                name: 'Recently Played',
                description: 'Your recent listening history',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                tracks: recents,
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailScreen(playlist: autoPl),
                ),
              );
            },
          ),
        ),

        // Most Played Auto Playlist
        if (mostPlayed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _buildSurfaceRow(
              iconWidget: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00B0FF), Color(0xFF005B9F)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.bar_chart_rounded, color: Colors.white, size: 24),
                ),
              ),
              title: 'Most Played',
              subtitle: '${mostPlayed.length} top rotation tracks',
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: () {
                final autoPl = Playlist(
                  id: 'auto_most_played',
                  name: 'Most Played',
                  description: 'Your highest rotation tracks',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  tracks: mostPlayed,
                );
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlaylistDetailScreen(playlist: autoPl),
                  ),
                );
              },
            ),
          ),

        // On Repeat Auto Playlist
        if (onRepeat.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _buildSurfaceRow(
              iconWidget: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9800), Color(0xFFB26A00)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.repeat_rounded, color: Colors.white, size: 24),
                ),
              ),
              title: 'On Repeat',
              subtitle: '${onRepeat.length} tracks on loop',
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: () {
                final autoPl = Playlist(
                  id: 'auto_on_repeat',
                  name: 'On Repeat',
                  description: 'Songs you keep coming back to',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  tracks: onRepeat,
                );
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlaylistDetailScreen(playlist: autoPl),
                  ),
                );
              },
            ),
          ),

        // Rediscover Auto Playlist
        if (rediscover.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _buildSurfaceRow(
              iconWidget: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9C27B0), Color(0xFF4A148C)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                ),
              ),
              title: 'Rediscover',
              subtitle: '${rediscover.length} past favorites to rekindle',
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: () {
                final autoPl = Playlist(
                  id: 'auto_rediscover',
                  name: 'Rediscover',
                  description: 'Treasures from your past rotation',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  tracks: rediscover,
                );
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlaylistDetailScreen(playlist: autoPl),
                  ),
                );
              },
            ),
          ),

        const SizedBox(height: 16),

        // 2. User Playlists Section
        if (userPlaylists.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'YOUR PLAYLISTS',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          ...userPlaylists.map((playlist) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _buildSurfaceRow(
                iconWidget: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.queue_music_rounded, color: AppColors.primary, size: 24),
                  ),
                ),
                title: playlist.name,
                subtitle: '${playlist.tracks.length} songs',
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
                    ),
                  );
                },
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        // 3. Built-in Curated Playlists
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'CURATED PLAYLISTS',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        ...builtinPlaylists.map((playlist) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _buildSurfaceRow(
              iconWidget: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.waves_rounded, color: Colors.white, size: 24),
                ),
              ),
              title: playlist.name,
              subtitle: '${playlist.tracks.length} songs',
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }

  // ==========================================
  // FAVORITES TAB
  // ==========================================
  Widget _buildFavoritesTab(
    BuildContext context,
    LibraryProvider library,
    UnifiedPlaybackController audioPlayer,
  ) {
    final favorites = library.favorites;

    if (favorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_border_rounded, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              const Text(
                'No favorites yet',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap the heart icon on any song to save it here for instant offline playback.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: widget.onExploreTapped,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.explore_rounded),
                label: const Text('Discover Music'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${favorites.length} songs',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 28),
                  tooltip: 'Play All',
                  onPressed: () {
                    audioPlayer.playTrack(favorites.first, playlist: favorites, initialIndex: 0);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.shuffle_rounded, color: AppColors.textMuted, size: 22),
                  tooltip: 'Shuffle',
                  onPressed: () {
                    final shuffled = List.of(favorites)..shuffle();
                    audioPlayer.playTrack(shuffled.first, playlist: shuffled, initialIndex: 0);
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        ...favorites.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TrackTile(
              track: entry.value,
              playlist: favorites,
              index: entry.key,
            ),
          );
        }),
      ],
    );
  }

  // ==========================================
  // RECENTS TAB
  // ==========================================
  Widget _buildRecentsTab(
    BuildContext context,
    LibraryProvider library,
    UnifiedPlaybackController audioPlayer,
  ) {
    final recents = library.recentlyPlayed;

    if (recents.isEmpty) {
      return const Center(
        child: Text('No listening history yet', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final recentTracks = recents.map((r) => r.track).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${recents.length} played tracks',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            TextButton(
              onPressed: () => library.clearRecentlyPlayed(),
              child: const Text('Clear History', style: TextStyle(color: AppColors.primary, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ...recents.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TrackTile(
              track: entry.value.track,
              playlist: recentTracks,
              index: entry.key,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSurfaceRow({
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: iconWidget,
        title: Text(
          title,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
