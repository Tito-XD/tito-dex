import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/location_index.dart';
import 'package:titodex/features/game/game_edition.dart';

void main() {
  final index = LocationIndex.fromJson({
    'version': 1,
    'byVersion': {
      'heartgold': {
        'route-1': {
          'labelZh': '1号道路',
          'entries': [
            {
              'speciesId': 1,
              'methods': ['walk'],
            },
          ],
        },
      },
      'soulsilver': {
        'route-1': {
          'labelZh': '1号道路',
          'entries': [
            {
              'speciesId': 1,
              'methods': ['walk'],
            },
            {
              'speciesId': 2,
              'pokemonId': 10002,
              'formKey': 'ivysaur-special',
              'teraType': 'grass',
              'isRaid': true,
              'isFixedEncounter': true,
              'methods': ['surf'],
              'maxChance': 25,
              'rateKind': 'weight',
              'rateValue': 7,
            },
          ],
        },
      },
    },
  });

  test('merged editions deduplicate encounters across flavors', () {
    final areas = index.areasForEdition(GameEdition.hgss);
    expect(areas.single.speciesCount, 2);
    expect(areas.single.caughtCount({2}), 1);
  });

  test('exact flavor only exposes that version', () {
    final areas = index.areasForEdition(
      GameEdition.hgss.withFlavor('heartgold'),
    );
    expect(areas.single.entries.map((entry) => entry.speciesId), [1]);
  });

  test('preserves form-aware and special encounter metadata', () {
    final entry = index
        .areasForEdition(GameEdition.hgss.withFlavor('soulsilver'))
        .single
        .entries
        .last;
    expect(entry.pokemonId, 10002);
    expect(entry.formKey, 'ivysaur-special');
    expect(entry.teraType, 'grass');
    expect(entry.isRaid, isTrue);
    expect(entry.isFixedEncounter, isTrue);
    expect(entry.maxChance, 25);
    expect(entry.rateKind, 'weight');
    expect(entry.rateValue, 7);
  });

  test('rejects unsupported schema versions', () {
    expect(
      () => LocationIndex.fromJson({'version': 2, 'byVersion': {}}),
      throwsFormatException,
    );
  });
}
