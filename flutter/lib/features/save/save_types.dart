import '../../models/journey.dart';

/// User configuration for automatic save directory syncing.
class SaveDirectoryConfig {
  const SaveDirectoryConfig({
    this.directoryPath,
    this.autoLoadOnStartup = true,
    this.lastLoadedPath,
    this.lastLoadedModifiedMs,
    this.lastLoadedHash,
    this.lastLoadedFileName,
  });

  final String? directoryPath;
  final bool autoLoadOnStartup;
  final String? lastLoadedPath;
  final int? lastLoadedModifiedMs;
  final String? lastLoadedHash;
  final String? lastLoadedFileName;

  SaveDirectoryConfig copyWith({
    String? directoryPath,
    bool? autoLoadOnStartup,
    String? lastLoadedPath,
    int? lastLoadedModifiedMs,
    String? lastLoadedHash,
    String? lastLoadedFileName,
    bool clearLastLoaded = false,
  }) {
    return SaveDirectoryConfig(
      directoryPath: directoryPath ?? this.directoryPath,
      autoLoadOnStartup: autoLoadOnStartup ?? this.autoLoadOnStartup,
      lastLoadedPath:
          clearLastLoaded ? null : (lastLoadedPath ?? this.lastLoadedPath),
      lastLoadedModifiedMs: clearLastLoaded
          ? null
          : (lastLoadedModifiedMs ?? this.lastLoadedModifiedMs),
      lastLoadedHash:
          clearLastLoaded ? null : (lastLoadedHash ?? this.lastLoadedHash),
      lastLoadedFileName: clearLastLoaded
          ? null
          : (lastLoadedFileName ?? this.lastLoadedFileName),
    );
  }
}

/// Result of scanning/parsing the newest save in a folder.
class SaveSyncResult {
  const SaveSyncResult({
    required this.journey,
    required this.updated,
    this.fileName,
    this.filePath,
    this.message,
  });

  final CurrentJourney journey;
  final bool updated;
  final String? fileName;
  final String? filePath;
  final String? message;
}
