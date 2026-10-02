/// YouTube and Network API Configuration for GoTune.
class ApiConfig {
  /// Application name identifier
  static const String appName = 'GoTune';

  /// HTTP timeout in seconds for API network calls.
  static const int requestTimeoutSeconds = 15;

  /// Default pagination / query limits.
  static const int defaultTrendingLimit = 25;
  static const int defaultSearchLimit = 25;
}
