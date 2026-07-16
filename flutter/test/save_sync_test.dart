import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/parser/pokemon_save_parser.dart';
import 'package:titodex/features/save/save_document_source.dart';
import 'package:titodex/features/save/save_file_repository.dart';
import 'package:titodex/features/save/save_sync_service.dart';
import 'package:titodex/models/journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('single-file save configuration', () {
    test('removes legacy directory preferences', () async {
      SharedPreferences.setMockInitialValues({
        'titodex.save_directory_path': '/legacy/folder',
        'titodex.save_last_loaded_path': '/legacy/folder/old.sav',
      });
      final repository = SaveFileRepository();

      final config = await repository.load();
      final prefs = await SharedPreferences.getInstance();

      expect(config.selectedFileUri, isNull);
      expect(prefs.getString('titodex.save_directory_path'), isNull);
      expect(prefs.getString('titodex.save_last_loaded_path'), isNull);
    });

    test('manual sync asks for a file when none is selected', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SaveSyncService(
        fileRepository: SaveFileRepository(),
        parser: const PokemonSaveParser(),
        documentSource: _FakeSaveDocumentSource(null),
      );

      final result = await service.syncSelected(
        existing: CurrentJourney.mock(),
      );

      expect(result.updated, isFalse);
      expect(result.message, 'no_file');
    });

    test('startup skips when no file is selected', () async {
      SharedPreferences.setMockInitialValues({});
      final existing = CurrentJourney.mock();
      final service = SaveSyncService(
        fileRepository: SaveFileRepository(),
        parser: const PokemonSaveParser(),
        documentSource: _FakeSaveDocumentSource(null),
      );

      final result = await service.syncOnStartup(existing: existing);

      expect(result.updated, isFalse);
      expect(result.journey, existing);
    });
  });

  group('selected save document', () {
    late SaveFileRepository repository;
    late _FakeSaveDocumentSource source;
    late SaveSyncService service;
    late SaveDocument document;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final fixture = await rootBundle.load('assets/fixtures/PKMSS.sav');
      document = SaveDocument(
        uri: 'content://test/PKMSS.sav',
        fileName: 'PKMSS.sav',
        bytes: Uint8List.sublistView(fixture),
        modifiedMs: 1234,
      );
      repository = SaveFileRepository();
      source = _FakeSaveDocumentSource(document);
      service = SaveSyncService(
        fileRepository: repository,
        parser: const PokemonSaveParser(),
        documentSource: source,
      );
    });

    test('persists URI and parses the selected save immediately', () async {
      final result = await service.selectSaveDocument(
        document: document,
        existing: CurrentJourney.mock(),
      );
      final config = await repository.load();

      expect(result.updated, isTrue);
      expect(config.selectedFileUri, document.uri);
      expect(config.selectedFileName, 'PKMSS.sav');
      expect(config.lastLoadedHash, isNotEmpty);
    });

    test('re-reads only the persisted URI during startup sync', () async {
      final first = await service.selectSaveDocument(
        document: document,
        existing: CurrentJourney.mock(),
      );

      final second = await service.syncOnStartup(existing: first.journey);

      expect(source.readUris, [document.uri]);
      expect(second.updated, isFalse);
      expect(second.message, 'unchanged');
    });

    test('startup respects the auto-load switch', () async {
      final first = await service.selectSaveDocument(
        document: document,
        existing: CurrentJourney.mock(),
      );
      await service.setAutoLoadOnStartup(false);

      final result = await service.syncOnStartup(existing: first.journey);

      expect(result.updated, isFalse);
      expect(source.readUris, isEmpty);
    });

    test('clearFile releases URI permission and clears file state', () async {
      await service.selectSaveDocument(
        document: document,
        existing: CurrentJourney.mock(),
      );

      final config = await service.clearFile();

      expect(source.releasedUris, [document.uri]);
      expect(config.selectedFileUri, isNull);
      expect(config.lastLoadedHash, isNull);
    });
  });
}

class _FakeSaveDocumentSource implements SaveDocumentSource {
  _FakeSaveDocumentSource(this.document);

  SaveDocument? document;
  final readUris = <String>[];
  final releasedUris = <String>[];

  @override
  Future<SaveDocument?> pick() async => document;

  @override
  Future<SaveDocument?> read(String uri) async {
    readUris.add(uri);
    return document;
  }

  @override
  Future<void> release(String uri) async {
    releasedUris.add(uri);
  }
}
