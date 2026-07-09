import 'dart:io';
import 'dart:typed_data';

import '../../models/journey.dart';
import '../parser/hgss_parser.dart';
import 'save_directory_repository.dart';
import 'save_scanner.dart';
import 'save_types.dart';

class SaveSyncService {
  SaveSyncService({
    SaveDirectoryRepository? directoryRepository,
    SaveScanner? scanner,
    HgssParser? parser,
  })  : _directoryRepository =
            directoryRepository ?? SaveDirectoryRepository(),
        _scanner = scanner ?? const SaveScanner(),
        _parser = parser ?? const HgssParser();

  final SaveDirectoryRepository _directoryRepository;
  final SaveScanner _scanner;
  final HgssParser _parser;

  Future<SaveDirectoryConfig> loadConfig() => _directoryRepository.load();

  Future<SaveDirectoryConfig> updateDirectory(String? directoryPath) async {
    final current = await _directoryRepository.load();
    final next = current.copyWith(
      directoryPath: directoryPath,
      autoLoadOnStartup:
          directoryPath != null ? true : current.autoLoadOnStartup,
      clearLastLoaded: directoryPath != current.directoryPath,
    );
    await _directoryRepository.save(next);
    return next;
  }

  Future<SaveDirectoryConfig> setAutoLoadOnStartup(bool enabled) async {
    final current = await _directoryRepository.load();
    final next = current.copyWith(autoLoadOnStartup: enabled);
    await _directoryRepository.save(next);
    return next;
  }

  Future<SaveSyncResult> syncLatest({
    required CurrentJourney existing,
    bool force = false,
  }) async {
    final config = await _directoryRepository.load();
    final directoryPath = config.directoryPath;
    if (directoryPath == null || directoryPath.isEmpty) {
      return SaveSyncResult(
        journey: existing,
        updated: false,
        message: 'no_directory',
      );
    }

    final file = await _scanner.findNewestSave(directoryPath);
    if (file == null) {
      return SaveSyncResult(
        journey: existing,
        updated: false,
        message: 'no_save_found',
      );
    }

    final stat = await file.stat();
    final modifiedMs = stat.modified.millisecondsSinceEpoch;
    final path = file.path;
    final fileName = path.split(Platform.pathSeparator).last;

    if (!force &&
        config.lastLoadedPath == path &&
        config.lastLoadedModifiedMs == modifiedMs) {
      return SaveSyncResult(
        journey: existing,
        updated: false,
        fileName: fileName,
        filePath: path,
        message: 'unchanged',
      );
    }

    final bytes = Uint8List.fromList(await file.readAsBytes());
    if (!_parser.canParse(bytes)) {
      return SaveSyncResult(
        journey: existing,
        updated: false,
        fileName: fileName,
        filePath: path,
        message: 'unsupported_save',
      );
    }

    final summary = _parser.parseSummary(bytes);
    final journey = _parser.toJourney(summary, existing: existing);
    final nextConfig = config.copyWith(
      lastLoadedPath: path,
      lastLoadedModifiedMs: modifiedMs,
      lastLoadedHash: summary.saveHash,
      lastLoadedFileName: fileName,
    );
    await _directoryRepository.save(nextConfig);

    return SaveSyncResult(
      journey: journey,
      updated: true,
      fileName: fileName,
      filePath: path,
      message: 'loaded',
    );
  }

  Future<SaveSyncResult> syncOnStartup({required CurrentJourney existing}) async {
    final config = await _directoryRepository.load();
    final directoryPath = config.directoryPath;
    if (directoryPath == null || directoryPath.isEmpty) {
      return SaveSyncResult(journey: existing, updated: false);
    }
    return syncLatest(existing: existing);
  }
}
