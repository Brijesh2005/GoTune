/// Application-wide constants and persistent storage keys.
class AppConstants {
  static const String appName = 'Gojo Music';
  static const String appVersion = '1.0.0';
  static const String appSubtitle = 'Personal Audius Music Experience';

  // Storage keys for SharedPreferences
  static const String keyAppName = 'gotune_api_app_name';
  static const String keyApiKey = 'gotune_api_key';
  static const String keyCustomBaseUrl = 'gotune_custom_base_url';
  static const String keyFavorites = 'gotune_favorite_tracks_v1';
  static const String keyRecentTracks = 'gotune_recent_tracks_v1';
  static const String keyAudioQuality = 'gotune_audio_quality_pref';
  static const String keyThemeMode = 'gotune_theme_mode';

  // Popular music genres supported on Audius
  static const List<String> discoveryGenres = [
    'All',
    'Electronic',
    'Hip-Hop/Rap',
    'Pop',
    'Rock',
    'R&B/Soul',
    'Ambient',
    'Alternative',
    'Jazz',
    'Classical',
    'Metal',
    'Lo-Fi',
  ];
}
