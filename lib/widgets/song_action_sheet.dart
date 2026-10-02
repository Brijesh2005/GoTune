import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/unified_playback_controller.dart';
import '../providers/library_provider.dart';
import '../screens/album_screen.dart';
import '../screens/artist_screen.dart';
import '../screens/song_screen.dart';
import '../theme/app_colors.dart';
import 'add_to_playlist_sheet.dart';
import 'network_artwork.dart';

/// Comprehensive modal action sheet for any Track in GoTune.
/// Provides: Play, Play Next, Add to Queue, Favorite, Add to Playlist,
/// Start Song Radio, View Artist, View Album, and Metadata Details.
class SongActionSheet extends StatelessWidget {
  final Track track;

  const SongActionSheet({super.key, required this.track});

  static Future<void> show(BuildContext context, Track track) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SongActionSheet(track: track),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.read<UnifiedPlaybackController>();
    final libraryProvider = context.watch<LibraryProvider>();
    final isFav = libraryProvider.isFavorite(track.id);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Track Header Preview
                Row(
                  children: [
                    NetworkArtwork(
                      imageUrl: track.bestArtworkUrl,
                      width: 52,
                      height: 52,
                      borderRadius: 10,
                    ),
                    const SizedBox(width: 14),
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
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFav ? AppColors.accentPink : AppColors.textMuted,
                        size: 22,
                      ),
                      onPressed: () {
                        libraryProvider.toggleFavorite(track);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: Color(0x14FFFFFF), height: 1),
                const SizedBox(height: 8),

                // Action: Play Now
                _buildActionTile(
                  icon: Icons.play_arrow_rounded,
                  iconColor: AppColors.primary,
                  title: 'Play Now',
                  onTap: () {
                    Navigator.pop(context);
                    playerProvider.playTrack(track);
                  },
                ),

                // Action: Start Radio
                _buildActionTile(
                  icon: Icons.radio_rounded,
                  iconColor: AppColors.accentBlue,
                  title: 'Start Radio',
                  subtitle: 'Continuous mix based on this track',
                  onTap: () {
                    Navigator.pop(context);
                    playerProvider.playWithSmartRadio(track);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Starting radio for "${track.title}"'),
                        backgroundColor: AppColors.surfaceElevated,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),

                // Action: Play Next
                _buildActionTile(
                  icon: Icons.playlist_play_rounded,
                  iconColor: AppColors.secondary,
                  title: 'Play Next',
                  onTap: () {
                    Navigator.pop(context);
                    playerProvider.playNext(track);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Playing next: "${track.title}"'),
                        backgroundColor: AppColors.surfaceElevated,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),

                // Action: Add to Queue
                _buildActionTile(
                  icon: Icons.queue_music_rounded,
                  iconColor: AppColors.accentGreen,
                  title: 'Add to Queue',
                  onTap: () {
                    Navigator.pop(context);
                    playerProvider.addToQueue(track);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added to queue: "${track.title}"'),
                        backgroundColor: AppColors.surfaceElevated,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),

                // Action: Add to Playlist
                _buildActionTile(
                  icon: Icons.playlist_add_rounded,
                  iconColor: AppColors.primaryLight,
                  title: 'Add to Playlist',
                  onTap: () {
                    Navigator.pop(context);
                    AddToPlaylistSheet.show(context, track);
                  },
                ),

                // Action: View Artist
                if (track.artist.isNotEmpty && track.artist != 'Unknown Artist')
                  _buildActionTile(
                    icon: Icons.person_rounded,
                    iconColor: AppColors.textSecondary,
                    title: 'View Artist (${track.artist})',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArtistScreen(
                            artistId: track.artistId ?? track.artist,
                            artistName: track.artist,
                            initialArtworkUrl: track.bestArtworkUrl,
                          ),
                        ),
                      );
                    },
                  ),

                // Action: View Album
                if (track.albumName != null && track.albumName!.isNotEmpty)
                  _buildActionTile(
                    icon: Icons.album_rounded,
                    iconColor: AppColors.textSecondary,
                    title: 'View Album (${track.albumName})',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AlbumScreen(
                            albumId: track.albumId ?? track.albumName!,
                            albumName: track.albumName!,
                            artistName: track.artist,
                            initialArtworkUrl: track.bestArtworkUrl,
                          ),
                        ),
                      );
                    },
                  ),

                // Action: Track Metadata info / Content Detail Page
                _buildActionTile(
                  icon: Icons.info_outline_rounded,
                  iconColor: AppColors.primaryLight,
                  title: 'Song Details & Related',
                  subtitle: '${track.genre} • ${track.formattedDuration} • Provider: ${track.provider.toUpperCase()}',
                  onTap: () {
                    Navigator.pop(context);
                    SongScreen.open(context, track);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
