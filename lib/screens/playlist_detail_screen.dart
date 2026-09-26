import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../providers/audio_player_provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/network_artwork.dart';

/// Screen displaying tracks within a custom playlist with reordering,
/// playback actions, renaming, and removal.
class PlaylistDetailScreen extends StatelessWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  void _showRenameDialog(BuildContext context, LibraryProvider library, Playlist playlist) {
    final nameController = TextEditingController(text: playlist.name);
    final descController = TextEditingController(text: playlist.description);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Edit Playlist', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Playlist name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Description'),
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
              library.renamePlaylist(playlist.id, nameController.text.trim(), newDescription: descController.text.trim());
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, LibraryProvider library, Playlist playlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Playlist', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${playlist.name}"? This action cannot be undone.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              library.deletePlaylist(playlist.id);
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Go back to Library
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final player = context.read<AudioPlayerProvider>();
    final playlist = library.getPlaylist(playlistId);

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Playlist not found', style: TextStyle(color: AppColors.textMuted))),
      );
    }

    final tracks = playlist.tracks;

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              if (val == 'rename') {
                _showRenameDialog(context, library, playlist);
              } else if (val == 'delete') {
                _showDeleteDialog(context, library, playlist);
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: AppColors.textPrimary, size: 20),
                    SizedBox(width: 12),
                    Text('Rename', style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                    SizedBox(width: 12),
                    Text('Delete Playlist', style: TextStyle(color: AppColors.error, fontSize: 13.5)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Header banner with artwork & play actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: playlist.coverArtworkUrl.isNotEmpty
                        ? NetworkArtwork(imageUrl: playlist.coverArtworkUrl, width: 140, height: 140, borderRadius: 18)
                        : const Center(
                            child: Icon(Icons.queue_music_rounded, color: Colors.white, size: 54),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    playlist.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (playlist.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      playlist.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${playlist.trackCount} tracks • ${playlist.formattedTotalDuration}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),

                  // Play & Shuffle buttons
                  if (tracks.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            player.playTrack(tracks.first, playlist: tracks, initialIndex: 0);
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 22),
                          label: const Text('Play All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            final shuffled = List<Track>.from(tracks)..shuffle();
                            player.playTrack(shuffled.first, playlist: shuffled, initialIndex: 0);
                          },
                          icon: const Icon(Icons.shuffle_rounded, size: 20),
                          label: const Text('Shuffle'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Reorderable track list
          if (tracks.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.music_off_rounded, color: AppColors.textMuted, size: 42),
                      SizedBox(height: 14),
                      Text(
                        'This playlist is empty',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Browse Trending or Search Audius, tap "..." on any track and select "Add to Playlist".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 120),
              sliver: SliverReorderableList(
                itemCount: tracks.length,
                onReorder: (oldIndex, newIndex) {
                  library.reorderPlaylistTracks(playlist.id, oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey('playlist_${playlist.id}_${track.id}_$index'),
                    index: index,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border.withOpacity(0.5)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.drag_handle_rounded, color: AppColors.textMuted, size: 20),
                            const SizedBox(width: 8),
                            NetworkArtwork(imageUrl: track.thumbnailArtworkUrl, width: 44, height: 44, borderRadius: 8),
                          ],
                        ),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(track.formattedDuration, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.textMuted, size: 20),
                              splashRadius: 18,
                              onPressed: () {
                                library.removeTrackFromPlaylist(playlist.id, track.id);
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          player.playTrack(track, playlist: tracks, initialIndex: index);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
