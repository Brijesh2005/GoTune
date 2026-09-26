import 'package:flutter/foundation.dart';
import '../models/api_response.dart';
import '../models/track.dart';
import '../repositories/track_repository.dart';
import '../utils/debouncer.dart';

enum LoadState { initial, loading, success, error }

/// Main provider managing music discovery, trending streams, search, and library state.
class MusicProvider extends ChangeNotifier {
  final TrackRepository _repository;
  final Debouncer _searchDebouncer = Debouncer(delay: const Duration(milliseconds: 400));

  MusicProvider(this._repository) {
    loadHomeData();
    refreshLibraryData();
    loadSearchHistory();
  }

  // --- Home / Trending State ---
  List<Track> _trendingTracks = [];
  LoadState _trendingState = LoadState.initial;
  String _trendingError = '';

  List<Track> get trendingTracks => _trendingTracks;
  LoadState get trendingState => _trendingState;
  String get trendingError => _trendingError;

  // --- Discovery State ---
  List<Track> _discoveryTracks = [];
  LoadState _discoveryState = LoadState.initial;
  String _discoveryError = '';
  String _selectedGenre = 'All';

  List<Track> get discoveryTracks => _discoveryTracks;
  LoadState get discoveryState => _discoveryState;
  String get discoveryError => _discoveryError;
  String get selectedGenre => _selectedGenre;

  // --- Search State ---
  String _searchQuery = '';
  List<Track> _searchResults = [];
  LoadState _searchState = LoadState.initial;
  String _searchError = '';
  bool _hasSearched = false;
  String _searchProvider = 'all'; // 'all', 'youtube', 'saavn', 'audius'

  String get searchQuery => _searchQuery;
  List<Track> get searchResults => _searchResults;
  LoadState get searchState => _searchState;
  String get searchError => _searchError;
  bool get hasSearched => _hasSearched;
  String get searchProvider => _searchProvider;

  void setSearchProvider(String provider) {
    if (_searchProvider == provider) return;
    _searchProvider = provider;
    notifyListeners();
    if (_searchQuery.trim().isNotEmpty) {
      executeSearch(_searchQuery, addToHistory: false);
    }
  }

  List<String> _searchHistory = [];
  List<String> get searchHistory => List.unmodifiable(_searchHistory);

  // --- Library State ---
  List<Track> _favorites = [];
  List<Track> _recentlyPlayed = [];

  List<Track> get favorites => _favorites;
  List<Track> get recentlyPlayed => _recentlyPlayed;

  // --- Methods ---

  /// Loads initial home data (trending + discovery tracks).
  Future<void> loadHomeData() async {
    await Future.wait([
      fetchTrendingTracks(),
      fetchDiscoveryTracks(),
    ]);
  }

  /// Fetches trending tracks across sources.
  Future<void> fetchTrendingTracks() async {
    _trendingState = LoadState.loading;
    _trendingError = '';
    notifyListeners();

    try {
      _trendingTracks = await _repository.getTrendingTracks(limit: 25, provider: 'all');
      _trendingState = LoadState.success;
    } on RateLimitException catch (e) {
      _trendingState = LoadState.error;
      _trendingError = e.message;
    } on NetworkException catch (e) {
      _trendingState = LoadState.error;
      _trendingError = e.message;
    } on ApiException catch (e) {
      _trendingState = LoadState.error;
      _trendingError = e.message;
    } catch (e) {
      _trendingState = LoadState.error;
      _trendingError = 'Unexpected error fetching trending tracks: $e';
    }
    notifyListeners();
  }

  /// Selects a genre filter and reloads discovery tracks.
  Future<void> setDiscoveryGenre(String genre) async {
    if (_selectedGenre == genre) return;
    _selectedGenre = genre;
    await fetchDiscoveryTracks();
  }

  /// Fetches popular / discovery tracks for the currently selected genre.
  Future<void> fetchDiscoveryTracks() async {
    _discoveryState = LoadState.loading;
    _discoveryError = '';
    notifyListeners();

    try {
      _discoveryTracks = await _repository.getTrendingTracks(
        genre: _selectedGenre == 'All' ? null : _selectedGenre,
        limit: 25,
        provider: 'all',
      );
      _discoveryState = LoadState.success;
    } on RateLimitException catch (e) {
      _discoveryState = LoadState.error;
      _discoveryError = e.message;
    } on NetworkException catch (e) {
      _discoveryState = LoadState.error;
      _discoveryError = e.message;
    } on ApiException catch (e) {
      _discoveryState = LoadState.error;
      _discoveryError = e.message;
    } catch (e) {
      _discoveryState = LoadState.error;
      _discoveryError = 'Unexpected error fetching discovery tracks: $e';
    }
    notifyListeners();
  }

  /// Debounced search trigger.
  void onSearchQueryChanged(String query) {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      _searchDebouncer.cancel();
      _searchResults = [];
      _searchState = LoadState.initial;
      _hasSearched = false;
      notifyListeners();
      return;
    }

    _searchState = LoadState.loading;
    notifyListeners();

    _searchDebouncer.run(() {
      executeSearch(_searchQuery);
    });
  }

  /// Executes track search immediately.
  Future<void> executeSearch(
    String query, {
    bool addToHistory = true,
    String? provider,
  }) async {
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
      _searchResults = await _repository.searchTracks(
        trimmed,
        limit: 30,
        provider: provider ?? _searchProvider,
      );
      _searchState = LoadState.success;
    } on RateLimitException catch (e) {
      _searchState = LoadState.error;
      _searchError = e.message;
    } on NetworkException catch (e) {
      _searchState = LoadState.error;
      _searchError = e.message;
    } on ApiException catch (e) {
      _searchState = LoadState.error;
      _searchError = e.message;
    } catch (e) {
      _searchState = LoadState.error;
      _searchError = 'Error during search: $e';
    }
    notifyListeners();
  }

  /// Clears active search.
  void clearSearch() {
    _searchDebouncer.cancel();
    _searchQuery = '';
    _searchResults = [];
    _searchState = LoadState.initial;
    _searchError = '';
    _hasSearched = false;
    notifyListeners();
  }

  // --- Search History Methods ---

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

  // --- Library Methods ---

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
