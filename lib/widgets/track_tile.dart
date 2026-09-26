import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/audio_player_provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_colors.dart';
import 'add_to_playlist_sheet.dart';
import 'animated_equalizer.dart';
import 'network_artwork.dart';

/// Reusable track row with artwork, animated equalizer for active track,
/// duration, quick favorite toggle, and context options for playlist and queue operations.
class TrackTile extends StatelessWidget {
  final Track track;
  final List<Track>? queue;
  final VoidCallback? onTap;

  const TrackTile({
    super.key,
    required this.track,
    this.queue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<AudioPlayerProvider>();
    final libraryProvider = context.watch<LibraryProvider>();

    final isCurrent = playerProvider.currentTrack?.id == track.id;
    final isPlaying = isCurrent && playerProvider.isPlaying;
    final isFav = libraryProvider.isFavorite(track.id);

    return InkWell(
      onTap: onTap ??
          () {
            playerProvider.playTrack(track, playlist: queue);
          },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Artwork with playing indicator overlay
            Stack(
              children: [
                NetworkArtwork(
                  imageUrl: track.thumbnailArtworkUrl,
                  width: 50,
                  height: 50,
                  borderRadius: 10,
                ),
                if (isPlaying)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: AnimatedEqualizer(isPlaying: true, size: 20),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Title & Artist info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? AppColors.primaryLight : AppColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      if (track.isArtistVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          color: AppColors.secondary,
                          size: 13,
                        ),
                      ],
                      if (track.genre.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        const Text(
                          '•',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            track.genre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: track.provider == 'saavn'
                              ? const Color(0xFF00D2C4).withOpacity(0.15)
                              : AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: track.provider == 'saavn'
                                ? const Color(0xFF00D2C4).withOpacity(0.3)
                                : AppColors.primary.withOpacity(0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          track.provider == 'saavn' ? 'Saavn 320k' : 'Audius',
                          style: TextStyle(
                            color: track.provider == 'saavn'
                                ? const Color(0xFF00E5D5)
                                : AppColors.primaryLight,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
            const SizedBox(width: 4),

            // More Options Menu (Add to Playlist, Play Next, Add to Queue, Favorite)
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
              color: AppColors.surfaceElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (value) {
                switch (value) {
                  case 'add_playlist':
                    AddToPlaylistSheet.show(context, track);
                    break;
                  case 'play_next':
                    playerProvider.playNext(track);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Playing next: ${track.title}'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: AppColors.surfaceElevated,
                      ),
                    );
                    break;
                  case 'add_queue':
                    playerProvider.addToQueue(track);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added to queue: ${track.title}'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: AppColors.surfaceElevated,
                      ),
                    );
                    break;
                  case 'favorite':
                    libraryProvider.toggleFavorite(track);
                    break;
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'add_playlist',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add_rounded, color: AppColors.primaryLight, size: 20),
                      SizedBox(width: 12),
                      Text('Add to Playlist', style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'play_next',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_play_rounded, color: AppColors.secondary, size: 20),
                      SizedBox(width: 12),
                      Text('Play Next', style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_queue',
                  child: Row(
                    children: [
                      Icon(Icons.queue_music_rounded, color: AppColors.accentGreen, size: 20),
                      SizedBox(width: 12),
                      Text('Add to Queue', style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'favorite',
                  child: Row(
                    children: [
                      Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFav ? AppColors.accentPink : AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isFav ? 'Remove Favorite' : 'Favorite',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                      ),
                    ],
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
