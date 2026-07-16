import '../../models/journey.dart';

/// User configuration for a single persisted `.sav` document.
class SaveFileConfig {
  const SaveFileConfig({
    this.selectedFileUri,
    this.selectedFileName,
    this.autoLoadOnStartup = true,
    this.lastLoadedModifiedMs,
    this.lastLoadedHash,
    this.lastLoadedFileName,
  });

  final String? selectedFileUri;
  final String? selectedFileName;
  final bool autoLoadOnStartup;
  final int? lastLoadedModifiedMs;
  final String? lastLoadedHash;
  final String? lastLoadedFileName;

  SaveFileConfig copyWith({
    String? selectedFileUri,
    String? selectedFileName,
    bool? autoLoadOnStartup,
    int? lastLoadedModifiedMs,
    String? lastLoadedHash,
    String? lastLoadedFileName,
    bool clearLastLoaded = false,
    bool clearSelectedFile = false,
  }) {
    return SaveFileConfig(
      selectedFileUri: clearSelectedFile
          ? null
          : (selectedFileUri ?? this.selectedFileUri),
      selectedFileName: clearSelectedFile
          ? null
          : (selectedFileName ?? this.selectedFileName),
      autoLoadOnStartup: autoLoadOnStartup ?? this.autoLoadOnStartup,
      lastLoadedModifiedMs: clearLastLoaded
          ? null
          : (lastLoadedModifiedMs ?? this.lastLoadedModifiedMs),
      lastLoadedHash: clearLastLoaded
          ? null
          : (lastLoadedHash ?? this.lastLoadedHash),
      lastLoadedFileName: clearLastLoaded
          ? null
          : (lastLoadedFileName ?? this.lastLoadedFileName),
    );
  }
}

/// Result of reading and parsing the selected save file.
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
