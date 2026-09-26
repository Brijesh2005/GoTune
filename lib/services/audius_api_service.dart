import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/track.dart';

/// Service for communicating with the official decentralized Audius API.
/// Documentation: https://docs.audius.co/api
class AudiusApiService {
  final http.Client _client;
  String _baseUrl;
  String _appName;
  String? _apiKey;

  AudiusApiService({
    http.Client? client,
    String? baseUrl,
    String? appName,
    String? apiKey,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.defaultBaseUrl,
        _appName = appName ?? ApiConfig.defaultAppName,
        _apiKey = apiKey;

  String get baseUrl => _baseUrl;
  String get appName => _appName;
  String? get apiKey => _apiKey;

  void updateConfiguration({String? baseUrl, String? appName, String? apiKey}) {
    if (baseUrl != null && baseUrl.isNotEmpty) _baseUrl = baseUrl;
    if (appName != null && appName.isNotEmpty) _appName = appName;
    _apiKey = apiKey;
  }

  /// Default headers sent with each request.
  Map<String, String> get _headers {
    final headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent': '$_appName-Android/1.0',
    };
    if (_apiKey != null && _apiKey!.trim().isNotEmpty) {
      headers['x-api-key'] = _apiKey!.trim();
    }
    return headers;
  }

  /// Appends standard query parameters (app_name, api_key).
  Map<String, String> _buildQueryParams(Map<String, String> params) {
    final map = Map<String, String>.from(params);
    map['app_name'] = _appName;
    if (_apiKey != null && _apiKey!.trim().isNotEmpty) {
      map['api_key'] = _apiKey!.trim();
    }
    return map;
  }

  /// Searches for tracks matching [query].
  /// Handles debounced queries, rate limiting, and empty responses.
  Future<List<Track>> searchTracks({
    required String query,
    int limit = ApiConfig.defaultSearchLimit,
    int offset = 0,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return [];
    }

    final queryParams = _buildQueryParams({
      'query': trimmedQuery,
      'limit': limit.toString(),
      'offset': offset.toString(),
    });

    final uri = Uri.parse('$_baseUrl${ApiConfig.searchTracksPath}')
        .replace(queryParameters: queryParams);

    final response = await _executeGet(uri);
    return _parseTracksList(response);
  }

  /// Fetches trending tracks with an optional [genre] filter.
  Future<List<Track>> getTrendingTracks({
    String? genre,
    int limit = ApiConfig.defaultTrendingLimit,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (genre != null && genre.isNotEmpty && genre.toLowerCase() != 'all') {
      params['genre'] = genre;
    }

    final queryParams = _buildQueryParams(params);
    final uri = Uri.parse('$_baseUrl${ApiConfig.trendingTracksPath}')
        .replace(queryParameters: queryParams);

    final response = await _executeGet(uri);
    return _parseTracksList(response);
  }

  /// Fetches complete metadata for a single track by [trackId].
  Future<Track> getTrackById(String trackId) async {
    final queryParams = _buildQueryParams({});
    final uri = Uri.parse('$_baseUrl${ApiConfig.tracksPath}/$trackId')
        .replace(queryParameters: queryParams);

    final response = await _executeGet(uri);
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
    final data = jsonBody['data'];

    if (data == null || data is! Map<String, dynamic>) {
      throw EmptyResultException(message: 'Track $trackId not found on Audius');
    }

    return Track.fromAudiusJson(data);
  }

  /// Resolves the direct streaming URL for a track.
  /// Follows 302 redirects if needed or builds the canonical stream URL.
  Future<String> resolveStreamUrl(String trackId) async {
    final queryParams = _buildQueryParams({});
    final uri = Uri.parse('$_baseUrl${ApiConfig.tracksPath}/$trackId/stream')
        .replace(queryParameters: queryParams);

    try {
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..headers.addAll(_headers);

      final streamedResponse = await _client
          .send(request)
          .timeout(const Duration(seconds: ApiConfig.requestTimeoutSeconds));

      if (streamedResponse.isRedirect) {
        final location = streamedResponse.headers['location'];
        if (location != null && location.isNotEmpty) {
          return location;
        }
      }
      return uri.toString();
    } catch (e) {
      // Fallback directly to canonical stream URI
      return uri.toString();
    }
  }

  /// Tests connectivity to Audius Discovery Node and returns active host.
  Future<String> testConnection() async {
    try {
      final uri = Uri.parse(ApiConfig.hostDiscoveryUrl);
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'];
        if (data is List && data.isNotEmpty) {
          return data.first.toString();
        }
        return 'Connected to Audius ($baseUrl)';
      }
      throw ApiException('Unexpected status code: ${response.statusCode}');
    } catch (e) {
      throw NetworkException(message: 'Could not connect to Audius network: $e');
    }
  }

  /// Executes HTTP GET with timeout, status checking, and node failover.
  Future<http.Response> _executeGet(Uri uri) async {
    try {
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: ApiConfig.requestTimeoutSeconds));

      return _handleHttpResponse(response, uri);
    } on SocketException catch (e) {
      debugPrint('[AudiusApiService] SocketException: $e');
      throw NetworkException(
        message: 'No internet connection or Audius host is unreachable.',
      );
    } on TimeoutException {
      debugPrint('[AudiusApiService] Timeout calling $uri');
      throw NetworkException(
        message: 'Request timed out while contacting Audius network.',
      );
    } on http.ClientException catch (e) {
      debugPrint('[AudiusApiService] ClientException: $e');
      throw NetworkException(message: 'Network error: ${e.message}');
    }
  }

  /// Validates HTTP status code and throws domain exceptions.
  http.Response _handleHttpResponse(http.Response response, Uri uri) {
    final status = response.statusCode;

    if (status == 200) {
      return response;
    }

    if (status == 429) {
      throw RateLimitException(
        message: 'Audius rate limit reached. Please wait a few seconds before searching again.',
      );
    }

    String errorMessage = 'Audius API returned error $status';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body.containsKey('error')) {
        errorMessage = body['error'].toString();
      }
    } catch (_) {}

    if (status >= 400 && status < 500) {
      throw ApiException(errorMessage, statusCode: status);
    }

    if (status >= 500) {
      throw ApiException(
        'Audius node temporarily unavailable ($status). Retrying another node may help.',
        statusCode: status,
      );
    }

    throw ApiException(errorMessage, statusCode: status);
  }

  /// Parses list of tracks from standard `{ "data": [ ... ] }` response.
  List<Track> _parseTracksList(http.Response response) {
    try {
      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final data = jsonBody['data'];

      if (data == null || data is! List) {
        return [];
      }

      final tracks = <Track>[];
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          try {
            tracks.add(Track.fromAudiusJson(item));
          } catch (e) {
            debugPrint('[AudiusApiService] Skipping malformed track item: $e');
          }
        }
      }
      return tracks;
    } on FormatException catch (e) {
      throw ApiException('Invalid JSON response received from Audius: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
