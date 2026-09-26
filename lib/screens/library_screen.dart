import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../providers/audio_player_provider.dart';
import '../providers/library_provider.dart';
import '../screens/now_playing_screen.dart';
import '../screens/playlist_detail_screen.dart';
import '../services/builtin_playlists_service.dart';
import '../theme/app_colors.dart';

/// Redesigned Library Screen matching the Pulse aesthetic,
/// featuring tabbed navigation for Playlists (including built-ins), Albums, and Artists.
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
    final audioPlayer = context.read<AudioPlayerProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your library',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_rounded, color: AppColors.primaryLight, size: 28),
                          tooltip: 'Create Playlist',
                          onPressed: () => _showCreatePlaylistDialog(context, library),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Custom Tab Bar matching the Pulse design
                    TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 2.5,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      dividerColor: const Color(0x1AFFFFFF),
                      tabs: const [
                        Tab(text: 'Playlists'),
                        Tab(text: 'Albums'),
                        Tab(text: 'Artists'),
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
              _buildPlaylistsTab(context, library, audioPlayer),
              _buildAlbumsTab(context, library, audioPlayer),
              _buildArtistsTab(context, library, audioPlayer),
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
    AudioPlayerProvider audioPlayer,
  ) {
    final favorites = library.favorites;
    final userPlaylists = library.playlists;
    final builtinPlaylists = library.builtinPlaylists;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
      children: [
        // 1. Liked Songs tile matching prototype
        _buildSurfaceRow(
          iconWidget: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
            ),
          ),
          title: 'Liked Songs',
          subtitle: '${favorites.length} songs',
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          onTap: () {
            if (favorites.isNotEmpty) {
              audioPlayer.playTrack(favorites.first, playlist: favorites);
              NowPlayingScreen.show(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No liked songs yet! Tap the heart on any song.')),
              );
            }
          },
        ),
        const SizedBox(height: 18),

        // 2. Built-in Curated Playlists Section
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'BUILT-IN PLAYLISTS',
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.artTileGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(Icons.waves_rounded, color: AppColors.primaryLight, size: 24),
                ),
              ),
              title: playlist.name,
              subtitle: 'Curated · ${playlist.tracks.length} songs',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 28),
                    onPressed: () {
                      if (playlist.tracks.isNotEmpty) {
                        audioPlayer.playTrack(playlist.tracks.first, playlist: playlist.tracks);
                        NowPlayingScreen.show(context);
                      }
                    },
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
                  ),
                );
              },
            ),
          );
        }),
        const SizedBox(height: 18),

        // 3. User Custom Playlists
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'MY PLAYLISTS',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _showCreatePlaylistDialog(context, library),
              child: const Text(
                '+ New Playlist',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (userPlaylists.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: const Center(
              child: Text(
                'No custom playlists yet. Tap + New Playlist to make one!',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          )
        else
          ...userPlaylists.map((playlist) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _buildSurfaceRow(
                iconWidget: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.queue_music_rounded, color: AppColors.textPrimary, size: 24),
                  ),
                ),
                title: playlist.name,
                subtitle: '${playlist.tracks.length} songs',
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                onTap: () {
                  Navigator.push(
                    context,
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
  // ALBUMS TAB
  // ==========================================
  Widget _buildAlbumsTab(
    BuildContext context,
    LibraryProvider library,
    AudioPlayerProvider audioPlayer,
  ) {
    // Collect distinct albums from recents & favorites
    final allTracks = <Track>[
      ...library.favorites,
      ...library.recentlyPlayed.map((r) => r.track),
    ];
    final albums = <String, List<Track>>{};
    for (final t in allTracks) {
      if (t.genre.isNotEmpty) {
        albums.putIfAbsent(t.genre, () => []).add(t);
      }
    }

    if (albums.isEmpty) {
      return const Center(
        child: Text(
          'Play or like tracks to see albums here.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
      children: albums.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildSurfaceRow(
            iconWidget: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.artTileGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Icon(Icons.album_rounded, color: AppColors.primaryLight, size: 24),
              ),
            ),
            title: entry.key,
            subtitle: '${entry.value.first.artist} · Collection (${entry.value.length} tracks)',
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            onTap: () {
              audioPlayer.playTrack(entry.value.first, playlist: entry.value);
              NowPlayingScreen.show(context);
            },
          ),
        );
      }).toList(),
    );
  }

  // ==========================================
  // ARTISTS TAB
  // ==========================================
  Widget _buildArtistsTab(
    BuildContext context,
    LibraryProvider library,
    AudioPlayerProvider audioPlayer,
  ) {
    final allTracks = <Track>[
      ...library.favorites,
      ...library.recentlyPlayed.map((r) => r.track),
    ];
    final artists = <String, List<Track>>{};
    for (final t in allTracks) {
      if (t.artist.isNotEmpty && t.artist != 'Unknown Artist') {
        artists.putIfAbsent(t.artist, () => []).add(t);
      }
    }

    if (artists.isEmpty) {
      return const Center(
        child: Text(
          'Play or like tracks to see artists here.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
      children: artists.entries.map((entry) {
        final initial = entry.key.isNotEmpty ? entry.key[0].toUpperCase() : 'A';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildSurfaceRow(
            iconWidget: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFF27313C),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            title: entry.key,
            subtitle: 'Artist · ${entry.value.length} songs in library',
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            onTap: () {
              audioPlayer.playTrack(entry.value.first, playlist: entry.value);
              NowPlayingScreen.show(context);
            },
          ),
        );
      }).toList(),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                iconWidget,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
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
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
