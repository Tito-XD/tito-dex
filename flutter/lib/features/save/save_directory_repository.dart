import 'package:shared_preferences/shared_preferences.dart';

import 'save_types.dart';

const _directoryPathKey = 'titodex.save_directory_path';
const _autoLoadKey = 'titodex.save_auto_load';
const _lastLoadedPathKey = 'titodex.save_last_loaded_path';
const _lastLoadedModifiedKey = 'titodex.save_last_loaded_modified_ms';
const _lastLoadedHashKey = 'titodex.save_last_loaded_hash';
const _lastLoadedFileNameKey = 'titodex.save_last_loaded_file_name';

class SaveDirectoryRepository {
  Future<SaveDirectoryConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SaveDirectoryConfig(
      directoryPath: prefs.getString(_directoryPathKey),
      autoLoadOnStartup: prefs.getBool(_autoLoadKey) ?? true,
      lastLoadedPath: prefs.getString(_lastLoadedPathKey),
      lastLoadedModifiedMs: prefs.getInt(_lastLoadedModifiedKey),
      lastLoadedHash: prefs.getString(_lastLoadedHashKey),
      lastLoadedFileName: prefs.getString(_lastLoadedFileNameKey),
    );
  }

  Future<void> save(SaveDirectoryConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    if (config.directoryPath == null) {
      await prefs.remove(_directoryPathKey);
    } else {
      await prefs.setString(_directoryPathKey, config.directoryPath!);
    }
    await prefs.setBool(_autoLoadKey, config.autoLoadOnStartup);

    if (config.lastLoadedPath == null) {
      await prefs.remove(_lastLoadedPathKey);
      await prefs.remove(_lastLoadedModifiedKey);
      await prefs.remove(_lastLoadedHashKey);
      await prefs.remove(_lastLoadedFileNameKey);
    } else {
      await prefs.setString(_lastLoadedPathKey, config.lastLoadedPath!);
      await prefs.setInt(
        _lastLoadedModifiedKey,
        config.lastLoadedModifiedMs ?? 0,
      );
      await prefs.setString(_lastLoadedHashKey, config.lastLoadedHash ?? '');
      await prefs.setString(
        _lastLoadedFileNameKey,
        config.lastLoadedFileName ?? '',
      );
    }
  }
}
