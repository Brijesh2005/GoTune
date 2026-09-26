import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/audio_player_provider.dart';
import '../theme/app_colors.dart';
import 'animated_equalizer.dart';
import 'network_artwork.dart';

/// Modal bottom sheet displaying the current playback queue with reordering,
/// quick track removal, and instant jump-to-track capability.
class QueueBottomSheet extends StatelessWidget {
  const QueueBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QueueBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();
    final queue = player.queue;
    final currentIdx = player.currentIndex;
    final currentTrack = player.currentTrack;

    final upcomingTracks = <_IndexedTrack>[];
    for (int i = 0; i < queue.length; i++) {
      if (i != currentIdx) {
        upcomingTracks.add(_IndexedTrack(index: i, track: queue[i]));
      }
    }

    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Playback Queue',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${queue.length} track${queue.length == 1 ? '' : 's'} loaded',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (queue.length > 1)
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'upcoming') {
                        player.clearQueue();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cleared upcoming queue tracks'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else if (val == 'all') {
                        player.stop();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Queue cleared and playback stopped'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    color: AppColors.surfaceElevated,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: 'upcoming',
                        child: Row(
                          children: [
                            Icon(Icons.clear_all_rounded, color: AppColors.secondary, size: 20),
                            SizedBox(width: 10),
                            Text('Clear Upcoming Tracks', style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'all',
                        child: Row(
                          children: [
                            Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 20),
                            SizedBox(width: 10),
                            Text('Clear Entire Queue', style: TextStyle(color: AppColors.error, fontSize: 13.5)),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cleaning_services_rounded, size: 16, color: AppColors.error),
                          SizedBox(width: 6),
                          Text(
                            'Clear Queue',
                            style: TextStyle(color: AppColors.error, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(color: AppColors.border, height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Now Playing Section
                if (currentTrack != null) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'NOW PLAYING',
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        NetworkArtwork(
                          imageUrl: currentTrack.thumbnailArtworkUrl,
                          width: 48,
                          height: 48,
                          borderRadius: 8,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentTrack.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                currentTrack.artist,
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
                        if (player.isPlaying)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: AnimatedEqualizer(isPlaying: true, size: 18),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 2. Upcoming Tracks Section
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'UP NEXT',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      if (upcomingTracks.isNotEmpty)
                        const Text(
                          'Drag ≡ to reorder',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),

                if (upcomingTracks.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    alignment: Alignment.center,
                    child: const Column(
                      children: [
                        Icon(Icons.queue_music_rounded, color: AppColors.textMuted, size: 36),
                        SizedBox(height: 10),
                        Text(
                          'No upcoming tracks in queue',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Browse Trending or Search to add songs to queue.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: queue.length,
                    onReorder: (oldIndex, newIndex) {
                      player.reorderQueue(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final item = queue[index];
                      final isCurrentlyPlaying = index == currentIdx;

                      return Container(
                        key: ValueKey('queue_${item.id}_$index'),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isCurrentlyPlaying
                              ? AppColors.primary.withOpacity(0.08)
                              : AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrentlyPlaying
                                ? AppColors.primary.withOpacity(0.3)
                                : AppColors.border.withOpacity(0.5),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ReorderableDragStartListener(
                                index: index,
                                child: const Icon(
                                  Icons.drag_handle_rounded,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              NetworkArtwork(
                                imageUrl: item.thumbnailArtworkUrl,
                                width: 40,
                                height: 40,
                                borderRadius: 6,
                              ),
                            ],
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrentlyPlaying ? AppColors.primaryLight : AppColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: isCurrentlyPlaying ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            item.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.formattedDuration,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.textMuted,
                                  size: 18,
                                ),
                                splashRadius: 16,
                                onPressed: () {
                                  player.removeFromQueue(index);
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            player.skipToQueueIndex(index);
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IndexedTrack {
  final int index;
  final Track track;
  _IndexedTrack({required this.index, required this.track});
}
