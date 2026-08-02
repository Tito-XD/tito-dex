import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_progress.dart';
import 'package:titodex/features/dex/dex_repository.dart';
import 'package:titodex/features/dex/dex_version_availability_index.dart';
import 'package:titodex/features/game/game_edition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'availability index resolves exact and merged edition selections',
    () async {
      final index = DexVersionAvailabilityIndex(
        loadAsset: () async => '''
        {"version":1,"bySelection":{
          "soulsilver":[75,76],
          "@heartgold-soulsilver":[75,76,216]
        }}
      ''',
      );

      expect(
        await index.idsForEdition(GameEdition.hgss.withFlavor('soulsilver')),
        {75, 76},
      );
      expect(await index.idsForEdition(GameEdition.hgss), {75, 76, 216});
    },
  );

  test('bundled availability index is readable', () async {
    final ids = await DexVersionAvailabilityIndex().idsForEdition(
      GameEdition.hgss.withFlavor('soulsilver'),
    );

    expect(ids, containsAll([2, 3]));
    expect(ids.length, greaterThan(100));
  });

  test('repository removes caught ids from the precomputed bucket', () async {
    final index = DexVersionAvailabilityIndex(
      loadAsset: () async => '''
        {"version":1,"bySelection":{"soulsilver":[75,76,99,100]}}
      ''',
    );
    final repository = DexRepository(versionAvailabilityIndex: index);

    final result = await repository.evolutionOrTradeMissingIds(
      progress: const DexProgress(
        caughtIds: {74, 100},
        seenIds: {74, 75, 76, 100, 101},
      ),
      edition: GameEdition.hgss.withFlavor('soulsilver'),
    );

    expect(result, {75, 76, 99});
  });
}
