import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_models.dart';

void main() {
  const paldeanStats = PokemonBaseStats(
    hp: 55,
    attack: 45,
    defense: 45,
    specialAttack: 25,
    specialDefense: 25,
    speed: 15,
  );
  const paldeanWooper = PokemonFormDetail(
    key: 'wooper-paldea',
    pokemonId: 10253,
    formId: 10477,
    nameEn: 'Wooper-paldea',
    nameZh: '乌波（帕底亚的样子）',
    formNameZh: '帕底亚的样子',
    kind: PokemonFormKind.regional,
    isDefault: false,
    isBattleOnly: false,
    isMega: false,
    isCosmetic: false,
    types: ['poison', 'ground'],
    heightDm: 4,
    weightHg: 110,
    baseStats: paldeanStats,
    abilities: [
      PokemonAbility(
        nameEn: 'Poison-point',
        nameZh: '毒刺',
        descriptionZh: '有时会让接触到自己的对手中毒。',
      ),
    ],
  );

  test('form JSON round-trip preserves form-specific battle data', () {
    final restored = PokemonFormDetail.fromJson(
      paldeanWooper.toJson(),
      moveLookup: const {},
    );

    expect(restored.kind, PokemonFormKind.regional);
    expect(restored.types, ['poison', 'ground']);
    expect(restored.baseStats?.total, paldeanStats.total);
    expect(restored.abilities.single.nameZh, '毒刺');
  });

  test(
    'selecting a form keeps national number but replaces battle profile',
    () {
      const detail = PokemonDetail(
        summary: PokemonSummary(
          id: 194,
          nameEn: 'Wooper',
          nameZh: '乌波',
          types: ['water', 'ground'],
          formSearchTerms: ['wooper-paldea', '乌波（帕底亚的样子）'],
        ),
        genusZh: '水鱼宝可梦',
        heightDm: 4,
        weightHg: 85,
        weaknesses: [],
        resistances: [],
        immunities: [],
        stabSuperEffective: [],
        evolutionChain: null,
        forms: [paldeanWooper],
      );

      final selected = detail.forForm(paldeanWooper);
      expect(selected.summary.id, 194);
      expect(selected.summary.nameZh, '乌波（帕底亚的样子）');
      expect(selected.summary.types, ['poison', 'ground']);
      expect(selected.weightHg, 110);
      expect(selected.abilities.single.nameZh, '毒刺');
    },
  );

  test('summary form terms survive JSON round-trip for search', () {
    const summary = PokemonSummary(
      id: 157,
      nameEn: 'Typhlosion',
      nameZh: '火暴兽',
      types: ['fire'],
      formSearchTerms: ['typhlosion-hisui', '火暴兽（洗翠的样子）'],
    );
    final restored = PokemonSummary.fromJson(summary.toJson());
    expect(restored.formSearchTerms, contains('typhlosion-hisui'));
    expect(restored.formSearchTerms, contains('火暴兽（洗翠的样子）'));
  });

  test('incomplete battle form never borrows misleading default data', () {
    const unknownMega = PokemonFormDetail(
      key: 'dragonite-mega-new',
      pokemonId: 20000,
      nameEn: 'Dragonite-mega-new',
      nameZh: '快龙（超级进化）',
      kind: PokemonFormKind.mega,
      isDefault: false,
      isBattleOnly: true,
      isMega: true,
      isCosmetic: false,
      types: ['dragon', 'flying'],
      heightDm: 0,
      weightHg: 0,
    );
    const detail = PokemonDetail(
      summary: PokemonSummary(
        id: 149,
        nameEn: 'Dragonite',
        nameZh: '快龙',
        types: ['dragon', 'flying'],
      ),
      genusZh: '龙宝可梦',
      heightDm: 22,
      weightHg: 2100,
      weaknesses: [],
      resistances: [],
      immunities: [],
      stabSuperEffective: [],
      evolutionChain: null,
      baseStats: PokemonBaseStats(
        hp: 91,
        attack: 134,
        defense: 95,
        specialAttack: 100,
        specialDefense: 100,
        speed: 80,
      ),
      abilities: [
        PokemonAbility(nameEn: 'Inner-focus', nameZh: '精神力', descriptionZh: ''),
      ],
    );

    final selected = detail.forForm(unknownMega);
    expect(selected.baseStats, isNull);
    expect(selected.abilities, isEmpty);
    expect(selected.obtainLocationsByGame, isEmpty);
    expect(selected.moveSets, isEmpty);
  });
}
