import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/playlist.dart';
import '../providers/music_provider.dart';
import '../screens/album_screen.dart';
import '../screens/artist_screen.dart';
import '../screens/playlist_detail_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/error_view.dart';
import '../widgets/network_artwork.dart';
import '../widgets/track_tile.dart';

/// Redesigned Search screen featuring category filters ([All], [Songs], [Artists], [Albums], [Playlists], [Genres]),
/// 400ms debouncing, search history chips, and browse categories grid.
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Search Input Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, albums, playlists...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14.5),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
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
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
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

            // Category Filter Tabs: [All] [Songs] [Artists] [Albums] [Playlists] [Genres]
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip(
                      label: 'All',
                      category: SearchCategory.all,
                      icon: Icons.grid_view_rounded,
                      music: musicProvider,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                      label: 'Songs',
                      category: SearchCategory.songs,
                      icon: Icons.music_note_rounded,
                      music: musicProvider,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                      label: 'Artists',
                      category: SearchCategory.artists,
                      icon: Icons.person_rounded,
                      music: musicProvider,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                      label: 'Albums',
                      category: SearchCategory.albums,
                      icon: Icons.album_rounded,
                      music: musicProvider,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                      label: 'Playlists',
                      category: SearchCategory.playlists,
                      icon: Icons.playlist_play_rounded,
                      music: musicProvider,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                      label: 'Genres',
                      category: SearchCategory.genres,
                      icon: Icons.category_rounded,
                      music: musicProvider,
                    ),
                  ],
                ),
              ),
            ),

            // Main Content Area
            Expanded(
              child: _buildSearchBody(musicProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required SearchCategory category,
    required IconData icon,
    required MusicProvider music,
  }) {
    final isSelected = music.searchCategory == category;
    return InkWell(
      onTap: () => music.setSearchCategory(category),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Runs a new search for a tapped genre or mood facet.
  void _searchForFacet(String title) {
    final music = context.read<MusicProvider>();
    _controller.text = title;
    music.setSearchCategory(SearchCategory.songs);
    music.executeSearch(title);
  }

  Widget _facetChip({required String label, required VoidCallback onPressed}) {
    return ActionChip(
      backgroundColor: AppColors.surfaceElevated,
      side: const BorderSide(color: AppColors.border),
      label: Text(
        label,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      ),
      onPressed: onPressed,
    );
  }


  Widget _buildSearchBody(MusicProvider music) {
    if (music.searchState == LoadState.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
      );
    }

    if (music.searchState == LoadState.error) {
      return ErrorView(
        message: music.searchError,
        onRetry: () => music.executeSearch(music.searchQuery),
      );
    }

    if (!music.hasSearched && music.searchQuery.isEmpty) {
      return _buildSearchLanding(music);
    }

    // Results view based on active category
    final songs = music.searchResults;
    final artists = music.artistResults;
    final albums = music.albumResults;
    final playlists = music.playlistResults;
    final genres = music.genreResults;
    final moods = music.moodResults;

    final isEmptyAll = songs.isEmpty &&
        artists.isEmpty &&
        albums.isEmpty &&
        playlists.isEmpty &&
        genres.isEmpty &&
        moods.isEmpty;

    if (isEmptyAll) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'No results found for "${music.searchQuery}"',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [

        // Artist results section
        if (artists.isNotEmpty &&
            (music.searchCategory == SearchCategory.all ||
                music.searchCategory == SearchCategory.artists)) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Artists',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...artists.map((artist) => _buildArtistCard(artist)),
          const SizedBox(height: 12),
        ],

        // Album results section
        if (albums.isNotEmpty &&
            (music.searchCategory == SearchCategory.all ||
                music.searchCategory == SearchCategory.albums)) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Albums',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...albums.map((album) => _buildAlbumCard(album)),
          const SizedBox(height: 12),
        ],

        // Playlists results section
        if (playlists.isNotEmpty &&
            (music.searchCategory == SearchCategory.all ||
                music.searchCategory == SearchCategory.playlists)) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Playlists',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...playlists.map((playlist) => _buildPlaylistCard(playlist)),
          const SizedBox(height: 12),
        ],

        // Genres & Moods results section
        if ((genres.isNotEmpty || moods.isNotEmpty) &&
            (music.searchCategory == SearchCategory.all ||
                music.searchCategory == SearchCategory.genres)) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Genres & Moods',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...genres.map(
                (genre) => _facetChip(
                  label: genre.title,
                  onPressed: () => _searchForFacet(genre.title),
                ),
              ),
              ...moods.map(
                (mood) => _facetChip(
                  label: mood.title,
                  onPressed: () => _searchForFacet(mood.title),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],

        // Songs section
        if (songs.isNotEmpty &&
            (music.searchCategory == SearchCategory.all ||
                music.searchCategory == SearchCategory.songs)) ...[
          if (music.searchCategory == SearchCategory.all)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Songs',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ...songs.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: TrackTile(
                track: entry.value,
                playlist: songs,
                index: entry.key,
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildArtistCard(Artist artist) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: ClipOval(
          child: SizedBox(
            width: 48,
            height: 48,
            child: artist.artworkUrl != null && artist.artworkUrl!.isNotEmpty
                ? NetworkArtwork(
                    imageUrl: artist.artworkUrl!,
                    width: 48,
                    height: 48,
                    borderRadius: 24,
                  )
                : Container(
                    color: AppColors.surfaceCard,
                    child: const Icon(Icons.person_rounded, color: AppColors.textMuted),
                  ),
          ),
        ),
        title: Text(
          artist.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: const Text(
          'Artist',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ArtistScreen(
                artistId: artist.id,
                artistName: artist.name,
                initialArtworkUrl: artist.artworkUrl,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlbumCard(Album album) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 48,
            height: 48,
            child: album.artworkUrl != null && album.artworkUrl!.isNotEmpty
                ? NetworkArtwork(
                    imageUrl: album.artworkUrl!,
                    width: 48,
                    height: 48,
                    borderRadius: 8,
                  )
                : Container(
                    color: AppColors.surfaceCard,
                    child: const Icon(Icons.album_rounded, color: AppColors.textMuted),
                  ),
          ),
        ),
        title: Text(
          album.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [album.artist, if (album.year != null) '${album.year}'].join(' • '),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AlbumScreen(
                albumId: album.id,
                albumName: album.name,
                artistName: album.artist,
                initialArtworkUrl: album.artworkUrl,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistCard(Playlist playlist) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.playlist_play_rounded, color: AppColors.primary, size: 28),
          ),
        ),
        title: Text(
          playlist.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${playlist.trackCount} songs',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlaylistDetailScreen(playlist: playlist),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchLanding(MusicProvider music) {
    final history = music.searchHistory;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (history.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () => music.clearSearchHistory(),
                child: const Text('Clear', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: history.map((query) {
              return Chip(
                backgroundColor: AppColors.surfaceElevated,
                side: const BorderSide(color: AppColors.border),
                label: GestureDetector(
                  onTap: () {
                    _controller.text = query;
                    music.executeSearch(query);
                  },
                  child: Text(
                    query,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  ),
                ),
                deleteIcon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                onDeleted: () => music.removeSearchQuery(query),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // Popular Searches
        const Text(
          'Popular Searches',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'Arijit Singh',
            'Adele',
            'Sidhu Moose Wala',
            'The Weeknd',
            'Diljit Dosanjh',
            'Coldplay',
            'Taylor Swift',
            'Lo-Fi Chill Beats',
            'Phonk Drift',
            'Bollywood Hits',
          ].map((tag) {
            return ActionChip(
              backgroundColor: AppColors.surfaceCard,
              side: const BorderSide(color: AppColors.border),
              label: Text(tag, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              onPressed: () {
                _controller.text = tag;
                music.executeSearch(tag);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 28),

        // Browse Categories Grid
        const Text(
          'Browse Categories',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            _buildGenreCard('Bollywood', const [Color(0xFFE50914), Color(0xFF8B0000)]),
            _buildGenreCard('Pop', const [Color(0xFF00B0FF), Color(0xFF005B9F)]),
            _buildGenreCard('Punjabi', const [Color(0xFF1DB954), Color(0xFF0D5E29)]),
            _buildGenreCard('EDM & Dance', const [Color(0xFFFF9800), Color(0xFFB26A00)]),
            _buildGenreCard('Lo-Fi & Chill', const [Color(0xFF9C27B0), Color(0xFF4A148C)]),
            _buildGenreCard('Hip-Hop & Rap', const [Color(0xFF673AB7), Color(0xFF311B92)]),
            _buildGenreCard('Rock', const [Color(0xFFD32F2F), Color(0xFF5D1010)]),
            _buildGenreCard('Romance', const [Color(0xFFE91E63), Color(0xFF880E4F)]),
          ],
        ),
      ],
    );
  }

  Widget _buildGenreCard(String genre, List<Color> colors) {
    return InkWell(
      onTap: () {
        _controller.text = genre;
        final music = context.read<MusicProvider>();
        music.setSearchCategory(SearchCategory.songs);
        music.executeSearch(genre);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            genre,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
