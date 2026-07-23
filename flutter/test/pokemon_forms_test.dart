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
    spriteUrlsByVersion: {
      'scarlet-violet': 'https://example.invalid/wooper-paldea-sv.png',
    },
    animatedSpriteUrl: 'https://example.invalid/wooper-paldea.gif',
    baseStats: paldeanStats,
    typeMultipliers: {'water': 2, 'grass': 0.25, 'electric': 0},
    dataCompleteness: 'complete',
    sources: ['https://pokeapi.co/api/v2/pokemon/10253/'],
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
    expect(restored.dataCompleteness, 'complete');
    expect(restored.sources, hasLength(1));
    expect(
      restored.spriteUrlsByVersion['scarlet-violet'],
      endsWith('wooper-paldea-sv.png'),
    );
    expect(restored.animatedSpriteUrl, endsWith('wooper-paldea.gif'));
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
      expect(selected.summary.spriteResourceId, 10253);
      expect(selected.summary.nameZh, '乌波（帕底亚的样子）');
      expect(selected.summary.types, ['poison', 'ground']);
      expect(
        selected.summary.spriteUrlsByVersion?['scarlet-violet'],
        endsWith('wooper-paldea-sv.png'),
      );
      expect(selected.weightHg, 110);
      expect(selected.abilities.single.nameZh, '毒刺');
      expect(selected.weaknesses, ['水']);
      expect(selected.resistances, ['草']);
      expect(selected.immunities, ['电']);
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

  test('default and regional forms keep separate exact-version locations', () {
    const defaultForm = PokemonFormDetail(
      key: 'wooper',
      pokemonId: 194,
      nameEn: 'Wooper',
      nameZh: '乌波',
      kind: PokemonFormKind.form,
      isDefault: true,
      isBattleOnly: false,
      isMega: false,
      isCosmetic: false,
      types: ['water', 'ground'],
      heightDm: 4,
      weightHg: 85,
      obtainLocationsByVersion: {
        'crystal': [
          ObtainLocationEntry(
            areaSlug: 'route-32-area',
            areaLabelZh: '32号道路',
            pokemonId: 194,
            formKey: 'wooper',
          ),
        ],
      },
    );
    const paldeaWithLocation = PokemonFormDetail(
      key: 'wooper-paldea',
      pokemonId: 10253,
      nameEn: 'Wooper-paldea',
      nameZh: '乌波（帕底亚的样子）',
      kind: PokemonFormKind.regional,
      isDefault: false,
      isBattleOnly: false,
      isMega: false,
      isCosmetic: false,
      types: ['poison', 'ground'],
      heightDm: 4,
      weightHg: 110,
      obtainLocationsByVersion: {
        'scarlet': [
          ObtainLocationEntry(
            areaSlug: 'south-province-area-one',
            areaLabelZh: '南第1区',
            pokemonId: 10253,
            formKey: 'wooper-paldea',
          ),
        ],
      },
    );
    const detail = PokemonDetail(
      summary: PokemonSummary(
        id: 194,
        nameEn: 'Wooper',
        nameZh: '乌波',
        types: ['water', 'ground'],
      ),
      genusZh: '水鱼宝可梦',
      heightDm: 4,
      weightHg: 85,
      weaknesses: [],
      resistances: [],
      immunities: [],
      stabSuperEffective: [],
      evolutionChain: null,
      obtainLocationsByVersion: {
        'crystal': [
          ObtainLocationEntry(areaSlug: 'route-32-area', areaLabelZh: '32号道路'),
        ],
        'scarlet': [
          ObtainLocationEntry(
            areaSlug: 'south-province-area-one',
            areaLabelZh: '南第1区',
          ),
        ],
      },
      forms: [defaultForm, paldeaWithLocation],
    );

    expect(detail.forForm(defaultForm).obtainLocationsByVersion.keys, [
      'crystal',
    ]);
    expect(detail.forForm(paldeaWithLocation).obtainLocationsByVersion.keys, [
      'scarlet',
    ]);
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
        spriteUrl: 'https://example.invalid/dragonite.png',
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
      abilitiesByGame: {
        'scarlet-violet': [
          PokemonAbility(
            nameEn: 'Inner-focus',
            nameZh: '精神力',
            descriptionZh: '',
          ),
        ],
      },
      obtainLocationsByVersion: {
        'violet': [ObtainLocationEntry(areaSlug: 'test', areaLabelZh: '测试地点')],
      },
    );

    final selected = detail.forForm(unknownMega);
    expect(selected.baseStats, isNull);
    expect(selected.abilities, isEmpty);
    expect(selected.obtainLocationsByGame, isEmpty);
    expect(selected.obtainLocationsByVersion, isEmpty);
    expect(selected.moveSets, isEmpty);
    expect(selected.abilitiesByGame, isEmpty);
    expect(selected.evolutionChain, isNull);
    expect(selected.summary.spriteUrl, isNull);
  });
}
