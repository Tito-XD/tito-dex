import '../../models/journey.dart';
import '../parser/pokemon_save_parser.dart';
import 'save_document_source.dart';
import 'save_file_repository.dart';
import 'save_types.dart';

/// Reads exactly one user-selected save document. Android keeps persisted URI
/// permission for this file, so startup sync never scans a directory.
class SaveSyncService {
  SaveSyncService({
    SaveFileRepository? fileRepository,
    PokemonSaveParser? parser,
    SaveDocumentSource? documentSource,
  }) : _fileRepository = fileRepository ?? SaveFileRepository(),
       _parser = parser ?? const PokemonSaveParser(),
       _documentSource = documentSource ?? PlatformSaveDocumentSource();

  final SaveFileRepository _fileRepository;
  final PokemonSaveParser _parser;
  final SaveDocumentSource _documentSource;

  Future<SaveFileConfig> loadConfig() => _fileRepository.load();

  Future<SaveDocument?> pickSaveDocument() => _documentSource.pick();

  Future<SaveSyncResult> selectSaveDocument({
    required SaveDocument document,
    required CurrentJourney existing,
  }) async {
    final current = await _fileRepository.load();
    if (!_parser.canParse(document.bytes)) {
      if (document.uri != current.selectedFileUri) {
        await _documentSource.release(document.uri);
      }
      return SaveSyncResult(
        journey: existing,
        updated: false,
        fileName: document.fileName,
        filePath: document.uri,
        message: 'unsupported_save',
      );
    }
    if (current.selectedFileUri != null &&
        current.selectedFileUri != document.uri) {
      await _documentSource.release(current.selectedFileUri!);
    }
    final selectedConfig = current.copyWith(
      selectedFileUri: document.uri,
      selectedFileName: document.fileName,
      clearLastLoaded: true,
      autoLoadOnStartup: true,
    );
    return _syncDocument(
      config: selectedConfig,
      document: document,
      existing: existing,
      force: true,
    );
  }

  Future<SaveFileConfig> clearFile() async {
    final current = await _fileRepository.load();
    if (current.selectedFileUri != null) {
      await _documentSource.release(current.selectedFileUri!);
    }
    final next = current.copyWith(
      clearSelectedFile: true,
      clearLastLoaded: true,
    );
    await _fileRepository.save(next);
    return next;
  }

  Future<SaveFileConfig> setAutoLoadOnStartup(bool enabled) async {
    final current = await _fileRepository.load();
    final next = current.copyWith(autoLoadOnStartup: enabled);
    await _fileRepository.save(next);
    return next;
  }

  Future<SaveSyncResult> syncSelected({
    required CurrentJourney existing,
    bool force = false,
  }) async {
    final config = await _fileRepository.load();
    final uri = config.selectedFileUri;
    if (uri == null || uri.isEmpty) {
      return SaveSyncResult(
        journey: existing,
        updated: false,
        message: 'no_file',
      );
    }
    final document = await _documentSource.read(uri);
    if (document == null) {
      return SaveSyncResult(
        journey: existing,
        updated: false,
        fileName: config.selectedFileName,
        filePath: uri,
        message: 'selected_file_unavailable',
      );
    }
    return _syncDocument(
      config: config,
      document: document,
      existing: existing,
      force: force,
    );
  }

  Future<SaveSyncResult> _syncDocument({
    required SaveFileConfig config,
    required SaveDocument document,
    required CurrentJourney existing,
    required bool force,
  }) async {
    if (!_parser.canParse(document.bytes)) {
      return SaveSyncResult(
        journey: existing,
        updated: false,
        fileName: document.fileName,
        filePath: document.uri,
        message: 'unsupported_save',
      );
    }

    final summary = _parser.parseSummary(
      document.bytes,
      sourceModifiedAt: document.modifiedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(document.modifiedMs!),
    );
    if (!force && config.lastLoadedHash == summary.saveHash) {
      return SaveSyncResult(
        journey: existing,
        updated: false,
        fileName: document.fileName,
        filePath: document.uri,
        message: 'unchanged',
      );
    }

    final journey = _parser.toJourney(summary, existing: existing);
    final nextConfig = config.copyWith(
      selectedFileUri: document.uri,
      selectedFileName: document.fileName,
      lastLoadedModifiedMs: document.modifiedMs ?? 0,
      lastLoadedHash: summary.saveHash,
      lastLoadedFileName: document.fileName,
    );
    await _fileRepository.save(nextConfig);
    return SaveSyncResult(
      journey: journey,
      updated: true,
      fileName: document.fileName,
      filePath: document.uri,
      message: 'loaded',
    );
  }

  Future<SaveSyncResult> syncOnStartup({
    required CurrentJourney existing,
  }) async {
    final config = await _fileRepository.load();
    if (!config.autoLoadOnStartup || config.selectedFileUri == null) {
      return SaveSyncResult(journey: existing, updated: false);
    }
    return syncSelected(existing: existing);
  }
}
