import 'package:flutter/foundation.dart';
import '../repositories/track_repository.dart';

/// Provider managing user preferences and app settings.
class SettingsProvider extends ChangeNotifier {
  final TrackRepository _repository;

  String _appName;
  String _audioQuality;

  SettingsProvider(this._repository)
      : _appName = _repository.storageService.getAppName(),
        _audioQuality = _repository.storageService.getAudioQuality();

  String get appName => _appName;
  String get audioQuality => _audioQuality;

  Future<void> updateAppName(String newName) async {
    _appName = newName.trim().isEmpty ? 'GoTune' : newName.trim();
    await _repository.storageService.setAppName(_appName);
    notifyListeners();
  }

  Future<void> updateAudioQuality(String quality) async {
    _audioQuality = quality;
    await _repository.storageService.setAudioQuality(quality);
    notifyListeners();
  }

  void clearCatalogCache() {
    _repository.clearCache();
    notifyListeners();
  }
}
