/// Audius API Configuration and Endpoints.
///
/// Follows official Audius API standards:
/// Developer documentation: https://docs.audius.co/api
/// OpenAPI spec: https://api.audius.co/v1
class ApiConfig {
  /// Default base URL for the Audius Discovery Node API v1.
  static const String defaultBaseUrl = 'https://api.audius.co/v1';

  /// Primary host resolution URL.
  static const String hostDiscoveryUrl = 'https://api.audius.co';

  /// Default application identifier registered with Audius API.
  static const String defaultAppName = 'GoTune';

  /// Fallback discovery node endpoints for resilience.
  static const List<String> fallbackDiscoveryNodes = [
    'https://api.audius.co/v1',
    'https://audius-discovery-1.cultur3stake.com/v1',
    'https://discoveryprovider.audius.co/v1',
  ];

  /// HTTP timeout in seconds for API network calls.
  static const int requestTimeoutSeconds = 15;

  /// Default pagination limits.
  static const int defaultTrendingLimit = 25;
  static const int defaultSearchLimit = 25;

  // Endpoint paths
  static const String trendingTracksPath = '/tracks/trending';
  static const String searchTracksPath = '/tracks/search';
  static const String tracksPath = '/tracks';
}
