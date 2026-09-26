import 'package:flutter/foundation.dart';
import '../repositories/track_repository.dart';

enum ConnectionTestStatus { idle, testing, success, error }

/// Provider managing user settings, Audius API credentials, and connectivity testing.
class SettingsProvider extends ChangeNotifier {
  final TrackRepository _repository;

  String _appName;
  String? _apiKey;
  String? _customBaseUrl;
  String _audioQuality;

  ConnectionTestStatus _testStatus = ConnectionTestStatus.idle;
  String _testMessage = '';

  SettingsProvider(this._repository)
      : _appName = _repository.storageService.getAppName(),
        _apiKey = _repository.storageService.getApiKey(),
        _customBaseUrl = _repository.storageService.getCustomBaseUrl(),
        _audioQuality = _repository.storageService.getAudioQuality();

  String get appName => _appName;
  String? get apiKey => _apiKey;
  String? get customBaseUrl => _customBaseUrl;
  String get audioQuality => _audioQuality;
  ConnectionTestStatus get testStatus => _testStatus;
  String get testMessage => _testMessage;

  Future<void> updateAppName(String newName) async {
    _appName = newName.trim().isEmpty ? 'GoTune' : newName.trim();
    await _repository.storageService.setAppName(_appName);
    _repository.apiService.updateConfiguration(appName: _appName);
    notifyListeners();
  }

  Future<void> updateApiKey(String? newKey) async {
    _apiKey = (newKey != null && newKey.trim().isNotEmpty) ? newKey.trim() : null;
    await _repository.storageService.setApiKey(_apiKey);
    _repository.apiService.updateConfiguration(apiKey: _apiKey);
    notifyListeners();
  }

  Future<void> updateCustomBaseUrl(String? newUrl) async {
    _customBaseUrl = (newUrl != null && newUrl.trim().isNotEmpty) ? newUrl.trim() : null;
    await _repository.storageService.setCustomBaseUrl(_customBaseUrl);
    _repository.apiService.updateConfiguration(baseUrl: _customBaseUrl);
    notifyListeners();
  }

  Future<void> updateAudioQuality(String quality) async {
    _audioQuality = quality;
    await _repository.storageService.setAudioQuality(quality);
    notifyListeners();
  }

  /// Tests live connectivity to Audius Discovery Network.
  Future<void> testAudiusConnection() async {
    _testStatus = ConnectionTestStatus.testing;
    _testMessage = 'Connecting to Audius Discovery Node...';
    notifyListeners();

    try {
      final host = await _repository.apiService.testConnection();
      _testStatus = ConnectionTestStatus.success;
      _testMessage = 'Online: $host';
    } catch (e) {
      _testStatus = ConnectionTestStatus.error;
      _testMessage = e.toString().replaceAll('Exception: ', '');
    }
    notifyListeners();
  }
}
