import 'package:shared_preferences/shared_preferences.dart';
import 'local_storage_service.dart';

/// Legacy adapter maintaining backwards-compatibility with [LocalStorageService].
class StorageService extends LocalStorageService {
  StorageService(super.prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }
}
