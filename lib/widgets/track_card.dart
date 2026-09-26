import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/audio_player_provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_colors.dart';
import 'add_to_playlist_sheet.dart';
import 'animated_equalizer.dart';
import 'network_artwork.dart';

/// Featured square card for trending carousel and horizontal discovery lists.
class TrackCard extends StatelessWidget {
  final Track track;
  final List<Track>? queue;
  final VoidCallback? onTap;

  const TrackCard({
    super.key,
    required this.track,
    this.queue,
    this.onTap,
  });

  void _showTrackMenu(BuildContext context) {
    final playerProvider = context.read<AudioPlayerProvider>();
    final libraryProvider = context.read<LibraryProvider>();
    final isFav = libraryProvider.isFavorite(track.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: NetworkArtwork(imageUrl: track.thumbnailArtworkUrl, width: 44, height: 44),
                title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded, color: AppColors.primaryLight),
                title: const Text('Add to Playlist'),
                onTap: () {
                  Navigator.pop(ctx);
                  AddToPlaylistSheet.show(context, track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_play_rounded, color: AppColors.secondary),
                title: const Text('Play Next'),
                onTap: () {
                  Navigator.pop(ctx);
                  playerProvider.playNext(track);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Playing next: ${track.title}'), duration: const Duration(seconds: 2)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music_rounded, color: AppColors.accentGreen),
                title: const Text('Add to Queue'),
                onTap: () {
                  Navigator.pop(ctx);
                  playerProvider.addToQueue(track);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added to queue: ${track.title}'), duration: const Duration(seconds: 2)),
                  );
                },
              ),
              ListTile(
                leading: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFav ? AppColors.accentPink : AppColors.textPrimary),
                title: Text(isFav ? 'Remove from Favorites' : 'Add to Favorites'),
                onTap: () {
                  Navigator.pop(ctx);
                  libraryProvider.toggleFavorite(track);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<AudioPlayerProvider>();
    final isCurrent = playerProvider.currentTrack?.id == track.id;
    final isPlaying = isCurrent && playerProvider.isPlaying;

    return Container(
      width: 145,
      margin: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: onTap ??
            () {
              if (queue != null && queue!.isNotEmpty) {
                playerProvider.playTrack(track, playlist: queue);
              } else {
                playerProvider.playWithSmartRadio(track);
              }
            },
        onLongPress: () => _showTrackMenu(context),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Artwork with play button overlay
            Stack(
              children: [
                NetworkArtwork(
                  imageUrl: track.bestArtworkUrl,
                  width: 145,
                  height: 145,
                  borderRadius: 14,
                ),
                // Genre badge top left
                if (track.genre.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        track.genre,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                // Play / Pause / Equalizer button bottom right
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isPlaying
                          ? const AnimatedEqualizer(
                              isPlaying: true,
                              color: Colors.white,
                              size: 14,
                            )
                          : const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Track title
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isCurrent ? AppColors.primaryLight : AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),

            // Artist name
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
  }
}
