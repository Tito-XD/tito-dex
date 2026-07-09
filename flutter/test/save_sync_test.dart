import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/parser/hgss_parser.dart';
import 'package:titodex/features/save/save_directory_repository.dart';
import 'package:titodex/features/save/save_scanner.dart';
import 'package:titodex/features/save/save_sync_service.dart';
import 'package:titodex/features/save/save_types.dart';
import 'package:titodex/models/journey.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SaveSyncService.syncOnStartup', () {
    late SaveDirectoryRepository repository;
    late SaveSyncService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = SaveDirectoryRepository();
      service = SaveSyncService(
        directoryRepository: repository,
        scanner: const SaveScanner(),
        parser: const HgssParser(),
      );
    });

    test('skips when no save directory is configured', () async {
      final existing = CurrentJourney.mock();

      final result = await service.syncOnStartup(existing: existing);

      expect(result.updated, isFalse);
      expect(result.journey, existing);
    });

    test('attempts sync when a save directory is configured', () async {
      await repository.save(
        const SaveDirectoryConfig(
          directoryPath: '/no/such/folder',
          autoLoadOnStartup: false,
        ),
      );

      final result = await service.syncOnStartup(existing: CurrentJourney.mock());

      expect(result.message, 'no_save_found');
    });
  });
}
