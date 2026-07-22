import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_game_scope.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/type_chart.dart';

void main() {
  test('formatTypeMultiplier covers common defensive values', () {
    expect(formatTypeMultiplier(2), '2');
    expect(formatTypeMultiplier(0.5), '1/2');
    expect(formatTypeMultiplier(0), '0');
    expect(formatTypeMultiplier(1), '1');
  });

  test('johto dex constants include HGSS flavor versions', () {
    expect(hgssFlavorVersions, contains('heartgold'));
    expect(hgssFlavorVersions, contains('soulsilver'));
    expect(johtoPokedexNames, contains('original-johto'));
  });

  test('encounter version groups include DLC and current PokeAPI games', () {
    expect(
      encounterVersionsByVersionGroup['sword-shield'],
      contains('the-crown-tundra-shield'),
    );
    expect(
      encounterVersionsByVersionGroup['scarlet-violet'],
      contains('the-indigo-disk-violet'),
    );
    expect(encounterVersionsByVersionGroup['legends-za'], [
      'legends-za',
      'mega-dimension',
    ]);
    expect(encounterVersionsByVersionGroup['champions'], ['champions']);
  });

  test('computeDefensiveMultipliers returns all 18 types', () {
    const relations = {
      'fire': TypeDamageRelations(
        doubleDamageTo: {'grass'},
        halfDamageTo: {'fire'},
        noDamageTo: {},
      ),
    };
    final multipliers = computeDefensiveMultipliers(['fire'], relations);
    expect(multipliers.length, typeGridOrder.length);
    expect(multipliers['water'], 1);
  });

  test('obtain locations retain exact version encounter details', () {
    final entry = ObtainLocationEntry.fromJson({
      'areaSlug': 'route-3-area',
      'areaLabelZh': '3号道路',
      'pokemonId': 10091,
      'speciesId': 19,
      'formSlug': 'rattata-alola',
      'isDefaultForm': false,
      'minLevel': 3,
      'maxLevel': 7,
      'maxChance': 25,
      'rateKind': 'percentage',
      'rateValue': 25,
      'versions': ['blue', 'red'],
      'methods': ['walk'],
      'conditions': ['time-day'],
    });

    expect(entry.minLevel, 3);
    expect(entry.pokemonId, 10091);
    expect(entry.speciesId, 19);
    expect(entry.formSlug, 'rattata-alola');
    expect(entry.isDefaultForm, isFalse);
    expect(entry.maxLevel, 7);
    expect(entry.versions, ['blue', 'red']);
    expect(entry.methods, ['walk']);
    expect(entry.conditions, ['time-day']);
    expect(entry.toJson()['maxLevel'], 7);
    expect(entry.toJson()['rateValue'], 25);
  });
}
