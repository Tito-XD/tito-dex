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

  test('sprite resolution preserves species-level reference fields', () {
    const detail = PokemonDetail(
      summary: PokemonSummary(
        id: 1,
        nameEn: 'Bulbasaur',
        nameZh: '妙蛙种子',
        types: ['grass', 'poison'],
      ),
      genusZh: '种子宝可梦',
      heightDm: 7,
      weightHg: 69,
      weaknesses: [],
      resistances: [],
      immunities: [],
      stabSuperEffective: [],
      evolutionChain: null,
      growthRateSlug: 'medium-slow',
      habitatSlug: 'grassland',
      hasGenderDifferences: true,
      heldItems: [PokemonHeldItem(slug: 'oran-berry', maxRarity: 5)],
      baseExperience: 64,
    );
    const resolvedSummary = PokemonSummary(
      id: 1,
      nameEn: 'Bulbasaur',
      nameZh: '妙蛙种子',
      types: ['grass', 'poison'],
      localSpritePath: '/data/dex_offline/sprites/1.png',
    );
    const chain = EvolutionNode(id: 1, nameEn: 'Bulbasaur', nameZh: '妙蛙种子');

    final resolved = detail.withResolvedSprites(
      summary: resolvedSummary,
      evolutionChain: chain,
      forms: const [],
    );

    expect(resolved.summary, same(resolvedSummary));
    expect(resolved.evolutionChain, same(chain));
    expect(resolved.growthRateSlug, detail.growthRateSlug);
    expect(resolved.habitatSlug, detail.habitatSlug);
    expect(resolved.hasGenderDifferences, detail.hasGenderDifferences);
    expect(resolved.heldItems, same(detail.heldItems));
    expect(resolved.baseExperience, detail.baseExperience);
  });

  test('obtain locations retain exact version encounter details', () {
    final entry = ObtainLocationEntry.fromJson({
      'areaSlug': 'route-3-area',
      'areaLabelZh': '3号道路',
      'pokemonId': 10091,
      'speciesId': 19,
      'formKey': 'rattata-alola',
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
    expect(entry.formKey, 'rattata-alola');
    expect(entry.isDefaultForm, isFalse);
    expect(entry.maxLevel, 7);
    expect(entry.versions, ['blue', 'red']);
    expect(entry.methods, ['walk']);
    expect(entry.conditions, ['time-day']);
    expect(entry.toJson()['maxLevel'], 7);
    expect(entry.toJson()['rateValue'], 25);
    expect(entry.toJson()['formKey'], 'rattata-alola');
    expect(entry.toJson().containsKey('formSlug'), isFalse);

    final legacy = ObtainLocationEntry.fromJson({
      'areaSlug': 'route-3-area',
      'areaLabelZh': '3号道路',
      'pokemonId': 10091,
      'formSlug': 'rattata-alola',
    });
    expect(legacy.formKey, 'rattata-alola');
    expect(legacy.formAmbiguous, isFalse);

    final ambiguous = ObtainLocationEntry.fromJson({
      'areaSlug': 'unknown-area',
      'areaLabelZh': '未知区域',
      'speciesId': 194,
      'teraType': 'water',
      'isFixedEncounter': true,
    });
    expect(ambiguous.formAmbiguous, isTrue);
    expect(ambiguous.teraType, 'water');
    expect(ambiguous.isFixedEncounter, isTrue);
  });
}
