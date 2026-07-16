import 'package:shared_preferences/shared_preferences.dart';

import 'save_types.dart';

const _selectedFileUriKey = 'titodex.save_file_uri';
const _selectedFileNameKey = 'titodex.save_file_name';
const _autoLoadKey = 'titodex.save_auto_load';
const _lastLoadedModifiedKey = 'titodex.save_last_loaded_modified_ms';
const _lastLoadedHashKey = 'titodex.save_last_loaded_hash';
const _lastLoadedFileNameKey = 'titodex.save_last_loaded_file_name';

// Removed directory-mode preferences. Clean them up when the new repository
// is first read so an old inaccessible path can never re-enter the flow.
const _legacyDirectoryPathKey = 'titodex.save_directory_path';
const _legacyLastLoadedPathKey = 'titodex.save_last_loaded_path';

class SaveFileRepository {
  Future<SaveFileConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyDirectoryPathKey);
    await prefs.remove(_legacyLastLoadedPathKey);
    return SaveFileConfig(
      selectedFileUri: prefs.getString(_selectedFileUriKey),
      selectedFileName: prefs.getString(_selectedFileNameKey),
      autoLoadOnStartup: prefs.getBool(_autoLoadKey) ?? true,
      lastLoadedModifiedMs: prefs.getInt(_lastLoadedModifiedKey),
      lastLoadedHash: prefs.getString(_lastLoadedHashKey),
      lastLoadedFileName: prefs.getString(_lastLoadedFileNameKey),
    );
  }

  Future<void> save(SaveFileConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    if (config.selectedFileUri == null) {
      await prefs.remove(_selectedFileUriKey);
      await prefs.remove(_selectedFileNameKey);
    } else {
      await prefs.setString(_selectedFileUriKey, config.selectedFileUri!);
      await prefs.setString(
        _selectedFileNameKey,
        config.selectedFileName ?? '',
      );
    }
    await prefs.setBool(_autoLoadKey, config.autoLoadOnStartup);

    if (config.lastLoadedHash == null) {
      await prefs.remove(_lastLoadedModifiedKey);
      await prefs.remove(_lastLoadedHashKey);
      await prefs.remove(_lastLoadedFileNameKey);
    } else {
      await prefs.setInt(
        _lastLoadedModifiedKey,
        config.lastLoadedModifiedMs ?? 0,
      );
      await prefs.setString(_lastLoadedHashKey, config.lastLoadedHash!);
      await prefs.setString(
        _lastLoadedFileNameKey,
        config.lastLoadedFileName ?? '',
      );
    }
  }
}
