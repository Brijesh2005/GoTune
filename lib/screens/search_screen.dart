import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_constants.dart';
import '../providers/music_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/error_view.dart';
import '../widgets/track_tile.dart';

/// Search screen with real-time debouncing, active states, and genre quick-filters.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = context.watch<MusicProvider>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Search Input Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search any song, artist, Adele, Bollywood...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primaryLight,
                    size: 22,
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted),
                          onPressed: () {
                            _controller.clear();
                            musicProvider.clearSearch();
                          },
                        )
                      : null,
                ),
                onChanged: (text) {
                  setState(() {});
                  musicProvider.onSearchQueryChanged(text);
                },
                onSubmitted: (text) {
                  musicProvider.executeSearch(text);
                },
              ),
            ),

            // Source Provider Filter Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildProviderChip(
                      label: 'All Sources',
                      providerKey: 'all',
                      icon: Icons.all_inclusive_rounded,
                      activeColor: AppColors.primary,
                      music: musicProvider,
                    ),
                    const SizedBox(width: 8),
                    _buildProviderChip(
                      label: 'YouTube (Universal)',
                      providerKey: 'youtube',
                      icon: Icons.play_circle_filled_rounded,
                      activeColor: const Color(0xFFFF2A2A),
                      music: musicProvider,
                    ),
                    const SizedBox(width: 8),
                    _buildProviderChip(
                      label: 'JioSaavn (Bollywood / Global)',
                      providerKey: 'saavn',
                      icon: Icons.graphic_eq_rounded,
                      activeColor: const Color(0xFF00D2C4),
                      music: musicProvider,
                    ),
                    const SizedBox(width: 8),
                    _buildProviderChip(
                      label: 'Audius (Indie / EDM)',
                      providerKey: 'audius',
                      icon: Icons.music_note_rounded,
                      activeColor: AppColors.secondary,
                      music: musicProvider,
                    ),
                  ],
                ),
              ),
            ),

            // Content Area based on search state
            Expanded(
              child: _buildSearchBody(musicProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderChip({
    required String label,
    required String providerKey,
    required IconData icon,
    required Color activeColor,
    required MusicProvider music,
  }) {
    final isSelected = music.searchProvider == providerKey;
    return InkWell(
      onTap: () => music.setSearchProvider(providerKey),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.18) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.border,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? activeColor : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBody(MusicProvider music) {
    // 1. Initial idle state (no search entered)
    if (!music.hasSearched && music.searchQuery.isEmpty) {
      return _buildIdleExploreView(music);
    }

    // 2. Loading state
    if (music.searchState == LoadState.loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2.5,
            ),
            SizedBox(height: 16),
            Text(
              'Searching music catalog...',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
            ),
          ],
        ),
      );
    }

    // 3. Error state
    if (music.searchState == LoadState.error) {
      return ErrorView(
        message: music.searchError,
        onRetry: () => music.executeSearch(music.searchQuery),
      );
    }

    // 4. Empty state (searched but 0 results)
    if (music.searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.music_off_rounded,
                  color: AppColors.textMuted,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No tracks found for "${music.searchQuery}"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try searching for an artist name, title keyword, or explore different genres.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 5. Success state: Results list
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      itemCount: music.searchResults.length,
      itemBuilder: (context, index) {
        final track = music.searchResults[index];
        return TrackTile(
          track: track,
          queue: music.searchResults,
        );
      },
    );
  }

  Widget _buildIdleExploreView(MusicProvider music) {
    final history = music.searchHistory;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Search History Section (if any exists)
          if (history.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history_rounded, color: AppColors.primaryLight, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Recent Searches',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surfaceElevated,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Clear Search History', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                        content: const Text('Are you sure you want to remove all recent searches?', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              music.clearSearchHistory();
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length > 8 ? 8 : history.length,
              itemBuilder: (context, index) {
                final query = history[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    visualDensity: VisualDensity.compact,
                    leading: const Icon(
                      Icons.history_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    title: Text(
                      query,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                      splashRadius: 18,
                      onPressed: () {
                        music.removeSearchQuery(query);
                      },
                    ),
                    onTap: () {
                      _controller.text = query;
                      _focusNode.unfocus();
                      music.executeSearch(query);
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],

          // 2. Search Suggestions / Trending Tags
          const Row(
            children: [
              Icon(Icons.trending_up_rounded, color: AppColors.secondary, size: 20),
              SizedBox(width: 8),
              Text(
                'Search Suggestions',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              'Hangover',
              'Dhurandhar',
              'Phonk',
              'Brazilian Funk',
              'Top Hindi Hits',
              'Arijit Singh',
              'Sidhu Moose Wala',
              'Chill Lo-Fi',
              'Synthwave',
              'EDM Energy',
            ].map((suggestion) {
              return ActionChip(
                label: Text(suggestion),
                backgroundColor: AppColors.surfaceElevated,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                labelStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                avatar: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primaryLight,
                  size: 15,
                ),
                onPressed: () {
                  _controller.text = suggestion;
                  _focusNode.unfocus();
                  music.executeSearch(suggestion);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          // 3. Explore Categories
          const Text(
            'Explore Popular Categories',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: AppConstants.discoveryGenres.map((genre) {
              return ActionChip(
                label: Text(genre),
                backgroundColor: AppColors.surfaceCard,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
                avatar: const Icon(
                  Icons.explore_rounded,
                  color: AppColors.secondary,
                  size: 15,
                ),
                onPressed: () {
                  _controller.text = genre;
                  _focusNode.unfocus();
                  music.executeSearch(genre);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Audius Network Info Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.tips_and_updates_rounded, color: AppColors.secondary, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audius Open Music Network',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Search through millions of decentralized community tracks with direct lossless & 320kbps streaming.',
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
          ),
        ],
      ),
    );
  }
}
