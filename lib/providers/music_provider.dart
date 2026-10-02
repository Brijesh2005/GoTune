import 'package:flutter/foundation.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/home_feed.dart';
import '../models/music_content.dart';
import '../models/playlist.dart';
import '../models/recommendation.dart';
import '../models/search_discovery_result.dart';
import '../models/track.dart';
import '../repositories/track_repository.dart';
import '../services/music_algorithm_service.dart';
import '../services/music_discovery_service.dart';
import '../utils/debouncer.dart';

enum LoadState { initial, loading, success, error }
enum SearchCategory { all, songs, artists, albums, playlists, genres }

/// Main provider managing music discovery, trending streams, progressive dashboard loading,
/// search categorization across all categories, and personalized mixes.
/// Architecturally drives discovery through [MusicDiscoveryService] and [HomeFeed].
class MusicProvider extends ChangeNotifier {
  final TrackRepository _repository;
  late final MusicAlgorithmService _algorithmService;
  late final MusicDiscoveryService _discoveryService;
  final Debouncer _searchDebouncer = Debouncer(delay: const Duration(milliseconds: 400));

  MusicProvider(
    this._repository, {
    MusicAlgorithmService? algorithmService,
    MusicDiscoveryService? discoveryService,
  }) {
    _algorithmService = algorithmService ?? MusicAlgorithmService(repository: _repository);
    _discoveryService = discoveryService ??
        MusicDiscoveryService(
          aggregator: _repository.catalogAggregator,
          algorithmService: _algorithmService,
          storageService: _repository.storageService,
          cache: _repository.cacheService,
        );
    loadHomeData();
    refreshLibraryData();
    loadSearchHistory();
  }

  MusicDiscoveryService get discoveryService => _discoveryService;
  MusicAlgorithmService get algorithmService => _algorithmService;
  TrackRepository get repository => _repository;

  // --- Home / Dashboard States (Unified HomeFeed Architecture) ---
  HomeFeed? _homeFeed;
  HomeFeed? get homeFeed => _homeFeed;

  List<PersonalizedMix> _personalizedMixes = [];
  LoadState _mixesState = LoadState.initial;
  List<PersonalizedMix> get personalizedMixes => _homeFeed?.personalizedMixes ?? _personalizedMixes;
  LoadState get mixesState => _mixesState;

  List<Track> _quickPicks = [];
  List<Track> get quickPicks => _homeFeed?.quickPicks ?? _quickPicks;

  List<Track> _recommendedForYou = [];
  List<Track> get recommendedForYou => _homeFeed?.recommendedSongs ?? _recommendedForYou;

  List<Track> _mostPlayed = [];
  List<Track> get mostPlayed => _homeFeed?.mostPlayed ?? _mostPlayed;

  List<Track> _onRepeat = [];
  List<Track> get onRepeat => _homeFeed?.onRepeat ?? _onRepeat;

  List<Track> _rediscover = [];
  List<Track> get rediscover => _homeFeed?.rediscover ?? _rediscover;

  List<String> _favoriteArtists = [];
  List<String> get favoriteArtists => _homeFeed?.favoriteArtists ?? _favoriteArtists;

  List<Track> _trendingTracks = [];
  LoadState _trendingState = LoadState.initial;
  String _trendingError = '';
  List<Track> get trendingTracks => _homeFeed?.trendingTracks ?? _trendingTracks;
  LoadState get trendingState => _trendingState;
  String get trendingError => _trendingError;

  List<Track> _discoveryTracks = [];
  LoadState _discoveryState = LoadState.initial;
  String _discoveryError = '';
  String _selectedGenre = 'All';
  List<Track> get discoveryTracks => _discoveryTracks.isNotEmpty ? _discoveryTracks : (_homeFeed?.popularNow ?? []);
  LoadState get discoveryState => _discoveryState;
  String get discoveryError => _discoveryError;
  String get selectedGenre => _selectedGenre;

  List<Track> _becauseYouListenedTracks = [];
  String? _becauseYouListenedArtist;
  List<Track> get becauseYouListenedTracks => _homeFeed?.becauseYouListened ?? _becauseYouListenedTracks;
  String? get becauseYouListenedArtist => _homeFeed?.becauseYouListenedSeed ?? _becauseYouListenedArtist;

  /// Genre facets, supplied by the discovery layer instead of a hardcoded list.
  List<MusicGenre> get genres => _homeFeed?.genres ?? const [];

  /// Mood facets, supplied by the discovery layer.
  List<MusicMood> get moods => _homeFeed?.moods ?? const [];

  /// Artist names related to [artistName], for the "Fans also like" shelf on
  /// the artist page.
  ///
  /// Exposed through the provider so screens never reach into the ranking
  /// engine directly.
  List<String> relatedArtistNames(String artistName) {
    return MusicAlgorithmService.getSiblingArtists(artistName, null);
  }

  // --- Search State ---
  String _searchQuery = '';
  SearchCategory _searchCategory = SearchCategory.all;
  String _searchProvider = 'all'; // 'all', 'youtube'
  LoadState _searchState = LoadState.initial;
  String _searchError = '';
  bool _hasSearched = false;

  SearchDiscoveryResult? _searchDiscoveryResult;
  SearchDiscoveryResult? get searchDiscoveryResult => _searchDiscoveryResult;

  List<Track> _searchResults = [];
  List<Artist> _artistResults = [];
  List<Album> _albumResults = [];
  List<Playlist> _playlistResults = [];
  List<MusicGenre> _genreResults = [];
  List<MusicMood> _moodResults = [];

  String get searchQuery => _searchQuery;
  SearchCategory get searchCategory => _searchCategory;
  String get searchProvider => _searchProvider;
  LoadState get searchState => _searchState;
  String get searchError => _searchError;
  bool get hasSearched => _hasSearched;

  List<Track> get searchResults => _searchResults;
  List<Artist> get artistResults => _artistResults;
  List<Album> get albumResults => _albumResults;
  List<Playlist> get playlistResults => _playlistResults;
  List<MusicGenre> get genreResults => _genreResults;
  List<MusicMood> get moodResults => _moodResults;

  List<String> _searchHistory = [];
  List<String> get searchHistory => List.unmodifiable(_searchHistory);

  // --- Library State ---
  List<Track> _favorites = [];
  List<Track> _recentlyPlayed = [];

  List<Track> get favorites => _favorites;
  List<Track> get recentlyPlayed => _recentlyPlayed;

  // --- PROGRESSIVE HOME DATA LOADING (VIA MUSICDISCOVERYSERVICE) ---

  /// Loads home dashboard via unified [HomeFeed] through [MusicDiscoveryService].
  Future<void> loadHomeData({bool forceRefresh = false}) async {
    refreshLibraryData();

    _trendingState = LoadState.loading;
    _discoveryState = LoadState.loading;
    _mixesState = LoadState.loading;
    _trendingError = '';
    _discoveryError = '';
    notifyListeners();

    try {
      final feed = await _discoveryService.getHomeFeed(forceRefresh: forceRefresh);
      _homeFeed = feed;

      _quickPicks = feed.quickPicks;
      _recommendedForYou = feed.recommendedSongs;
      _trendingTracks = feed.trendingTracks;
      _discoveryTracks = feed.popularNow;
      _mostPlayed = feed.mostPlayed;
      _onRepeat = feed.onRepeat;
      _rediscover = feed.rediscover;
      _favoriteArtists = feed.favoriteArtists;
      _personalizedMixes = feed.personalizedMixes;
      _becauseYouListenedTracks = feed.becauseYouListened;
      _becauseYouListenedArtist = feed.becauseYouListenedSeed;

      _trendingState = LoadState.success;
      _discoveryState = LoadState.success;
      _mixesState = LoadState.success;
    } catch (e) {
      debugPrint('[MusicProvider] loadHomeData error: $e');
      _trendingState = LoadState.error;
      _discoveryState = LoadState.error;
      _mixesState = LoadState.error;
      _trendingError = "Couldn't load discovery feed. Check your connection.";
    }
    notifyListeners();
  }

  Future<void> fetchTrendingTracks() async {
    _trendingState = LoadState.loading;
    _trendingError = '';
    notifyListeners();

    try {
      _trendingTracks = await _discoveryService.getTrending(limit: 20);
      _trendingState = LoadState.success;
    } catch (e) {
      _trendingState = LoadState.error;
      _trendingError = "Couldn't load trending music.";
    }
    notifyListeners();
  }

  Future<void> setDiscoveryGenre(String genre) async {
    if (_selectedGenre == genre) return;
    _selectedGenre = genre;
    await fetchDiscoveryTracks();
  }

  Future<void> fetchDiscoveryTracks() async {
    _discoveryState = LoadState.loading;
    _discoveryError = '';
    notifyListeners();

    try {
      _discoveryTracks = await _discoveryService.getTrending(
        genre: _selectedGenre == 'All' ? null : _selectedGenre,
        limit: 15,
      );
      _discoveryState = LoadState.success;
    } catch (e) {
      _discoveryState = LoadState.error;
      _discoveryError = "Couldn't load discoveries.";
    }
    notifyListeners();
  }

  // --- SEARCH METHODS (VIA MUSICDISCOVERYSERVICE) ---

  void setSearchCategory(SearchCategory category) {
    if (_searchCategory == category) return;
    _searchCategory = category;
    notifyListeners();
    if (_searchQuery.trim().isNotEmpty) {
      executeSearch(_searchQuery, addToHistory: false);
    }
  }

  void setSearchProvider(String provider) {
    if (_searchProvider == provider) return;
    _searchProvider = provider;
    notifyListeners();
    if (_searchQuery.trim().isNotEmpty) {
      executeSearch(_searchQuery, addToHistory: false);
    }
  }

  void onSearchQueryChanged(String query) {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      _searchDebouncer.cancel();
      clearSearch();
      return;
    }

    _searchState = LoadState.loading;
    notifyListeners();

    _searchDebouncer.run(() {
      executeSearch(_searchQuery);
    });
  }

  /// Executes centralized search via [MusicDiscoveryService.search],
  /// retrieving normalized, multi-source, deduplicated results across categories.
  Future<void> executeSearch(String query, {bool addToHistory = true}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    if (addToHistory) {
      addSearchQuery(trimmed);
    }

    _searchQuery = trimmed;
    _searchState = LoadState.loading;
    _searchError = '';
    _hasSearched = true;
    notifyListeners();

    try {
      final categoryName = _searchCategory == SearchCategory.all
          ? 'all'
          : _searchCategory.name;

      final result = await _discoveryService.search(
        trimmed,
        category: categoryName,
        providerFilter: _searchProvider,
        limit: 25,
      );

      _searchDiscoveryResult = result;
      _searchResults = result.songs;
      _artistResults = result.artists;
      _albumResults = result.albums;
      _playlistResults = result.playlists;
      _genreResults = result.genres;
      _moodResults = result.moods;

      _searchState = LoadState.success;
    } catch (e) {
      debugPrint('[MusicProvider] executeSearch error: $e');
      _searchState = LoadState.error;
      _searchError = "Couldn't complete search. Check your connection.";
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchDebouncer.cancel();
    _searchQuery = '';
    _searchResults = [];
    _artistResults = [];
    _albumResults = [];
    _playlistResults = [];
    _genreResults = [];
    _moodResults = [];
    _searchDiscoveryResult = null;
    _searchState = LoadState.initial;
    _searchError = '';
    _hasSearched = false;
    notifyListeners();
  }

  // --- CATALOG & CONTENT DETAILS (VIA MUSICDISCOVERYSERVICE) ---

  Future<Artist?> getArtistDetails(String artistId) {
    return _discoveryService.getArtist(artistId);
  }

  Future<Album?> getAlbumDetails(String albumId) {
    return _discoveryService.getAlbum(albumId);
  }

  /// Track search for screens that need a bare result list (e.g. filling an
  /// artist page when the catalog has no artist record). Uses the aggregated
  /// fan-out, so results are deduplicated across catalogs.
  Future<List<Track>> searchTracks(String query, {int limit = 25}) async {
    final result = await _discoveryService.search(query, limit: limit);
    return result.songs;
  }

  /// Related songs for [track], resolved through the unified song-detail
  /// contract so the page's related shelf, artist credit and album credit all
  /// come from one call.
  Future<List<Track>> getRelatedTracks(Track track, {int limit = 15}) async {
    final detail = await _discoveryService.getSongDetail(track, limit: limit);
    return detail.relatedTracks;
  }

  /// Full song-detail bundle: song + related tracks + related artists +
  /// similar albums, resolved in one call.
  Future<SongDetail?> getSongDetail(Track track, {int limit = 15}) {
    return _discoveryService.getSongDetail(track, limit: limit);
  }

  // --- SEARCH HISTORY ---

  void loadSearchHistory() {
    _searchHistory = _repository.getSearchHistory();
    notifyListeners();
  }

  Future<void> addSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    await _repository.addSearchQuery(trimmed);
    _searchHistory = _repository.getSearchHistory();
    notifyListeners();
  }

  Future<void> removeSearchQuery(String query) async {
    await _repository.removeSearchQuery(query);
    _searchHistory = _repository.getSearchHistory();
    notifyListeners();
  }

  Future<void> clearSearchHistory() async {
    await _repository.clearSearchHistory();
    _searchHistory = [];
    notifyListeners();
  }

  // --- LIBRARY STATE ---

  void refreshLibraryData() {
    _favorites = _repository.getFavorites();
    _recentlyPlayed = _repository.getRecentlyPlayed();
    notifyListeners();
  }

  bool isFavorite(String trackId) {
    return _favorites.any((t) => t.id == trackId);
  }

  Future<void> toggleFavorite(Track track) async {
    await _repository.toggleFavorite(track);
    refreshLibraryData();
  }

  Future<void> recordTrackPlayed(Track track) async {
    await _repository.addToRecentlyPlayed(track);
    refreshLibraryData();
  }

  Future<void> clearRecentlyPlayed() async {
    await _repository.clearRecentlyPlayed();
    refreshLibraryData();
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    super.dispose();
  }
}
