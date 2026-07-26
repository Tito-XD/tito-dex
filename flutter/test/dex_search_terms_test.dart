import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_filter.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_search_terms.dart';

PokemonSummary _summary({
  required int id,
  required String nameEn,
  required String nameZh,
  List<String> types = const ['normal'],
  String? genusZh,
  int? generation,
  String? shapeSlug,
  String? colorSlug,
  List<String> tags = const [],
  int? heightDm,
}) => PokemonSummary(
  id: id,
  nameEn: nameEn,
  nameZh: nameZh,
  types: types,
  genusZh: genusZh,
  generation: generation,
  shapeSlug: shapeSlug,
  colorSlug: colorSlug,
  tags: tags,
  heightDm: heightDm,
);

// Field values mirror the smoke build against live PokeAPI data.
final growlithe = _summary(
  id: 58,
  nameEn: 'Growlithe',
  nameZh: '卡蒂狗',
  types: const ['fire'],
  genusZh: '小狗宝可梦',
  generation: 1,
  shapeSlug: 'quadruped',
  colorSlug: 'brown',
  heightDm: 7,
);

// Same body style AND same colour as Growlithe — only size separates them.
final arcanine = _summary(
  id: 59,
  nameEn: 'Arcanine',
  nameZh: '风速狗',
  types: const ['fire'],
  genusZh: '传说宝可梦',
  generation: 1,
  shapeSlug: 'quadruped',
  colorSlug: 'brown',
  heightDm: 19,
);
final dragonite = _summary(
  id: 149,
  nameEn: 'Dragonite',
  nameZh: '快龙',
  types: const ['dragon', 'flying'],
  genusZh: '龙宝可梦',
  generation: 1,
  shapeSlug: 'upright',
  colorSlug: 'brown',
  tags: const ['pseudo-legendary'],
  heightDm: 22,
);
final mew = _summary(
  id: 151,
  nameEn: 'Mew',
  nameZh: '梦幻',
  types: const ['psychic'],
  genusZh: '新种宝可梦',
  generation: 1,
  shapeSlug: 'upright',
  colorSlug: 'pink',
  tags: const ['mythical'],
  heightDm: 4,
);
final pichu = _summary(
  id: 172,
  nameEn: 'Pichu',
  nameZh: '皮丘',
  types: const ['electric'],
  genusZh: '小鼠宝可梦',
  generation: 2,
  shapeSlug: 'quadruped',
  colorSlug: 'yellow',
  tags: const ['baby'],
  heightDm: 3,
);
final lugia = _summary(
  id: 249,
  nameEn: 'Lugia',
  nameZh: '洛奇亚',
  types: const ['psychic', 'flying'],
  genusZh: '潜水宝可梦',
  generation: 2,
  shapeSlug: 'wings',
  colorSlug: 'white',
  tags: const ['legendary'],
  heightDm: 52,
);
final magikarp = _summary(
  id: 129,
  nameEn: 'Magikarp',
  nameZh: '鲤鱼王',
  types: const ['water'],
  genusZh: '鱼宝可梦',
  generation: 1,
  shapeSlug: 'fish',
  colorSlug: 'red',
  heightDm: 9,
);

// #10 — 52poke records a Gen VI reclassification: 蛇形 → 虫形.
final caterpie = _summary(
  id: 10,
  nameEn: 'Caterpie',
  nameZh: '绿毛虫',
  types: const ['bug'],
  genusZh: '芋虫宝可梦',
  generation: 1,
  shapeSlug: 'armor',
  colorSlug: 'green',
  heightDm: 3,
);

final all = [
  caterpie,
  growlithe,
  arcanine,
  magikarp,
  dragonite,
  mew,
  pichu,
  lugia,
];

List<String> _search(String query) {
  final constraints = parseDexSearchQuery(query);
  return all
      .where((s) => dexQueryMatches(constraints, s))
      .map((s) => s.nameZh)
      .toList();
}

void main() {
  group('alias resolution', () {
    test('legendary spellings all reach the same tag', () {
      for (final word in ['传说', '神', '神兽', '传说的宝可梦', 'legendary']) {
        final constraint = resolveDexSearchWord(word);
        expect(
          constraint.kind,
          DexConstraintKind.tag,
          reason: '$word should resolve to a tag',
        );
        expect(constraint.value, 'legendary');
      }
    });

    test('unknown words fall back to text', () {
      expect(resolveDexSearchWord('皮卡').kind, DexConstraintKind.text);
    });

    test('type names resolve to a type constraint', () {
      final constraint = resolveDexSearchWord('火');
      expect(constraint.kind, DexConstraintKind.type);
      expect(constraint.value, 'fire');
    });

    test('generation words resolve to a generation constraint', () {
      final constraint = resolveDexSearchWord('二代');
      expect(constraint.kind, DexConstraintKind.generation);
      expect(constraint.value, '2');
    });
  });

  group('search behaviour', () {
    test('finds legendaries and mythicals separately', () {
      // Arcanine rides along because its genus is literally 传说宝可梦 — the
      // deliberate consequence of an alias never suppressing a text match.
      expect(_search('传说'), ['风速狗', '洛奇亚']);
      expect(_search('幻'), ['梦幻']);
      expect(_search('准神'), ['快龙']);
      expect(_search('幼年'), ['皮丘']);
    });

    test('genus is searchable — this is what "有的在分类里" meant', () {
      expect(_search('鼠'), ['皮丘']);
    });

    test('different kinds are ANDed', () {
      // Body style alone is far too coarse to land on one species.
      expect(_search('四足兽形'), ['卡蒂狗', '风速狗', '皮丘']);
      expect(_search('四足兽形 棕'), ['卡蒂狗', '风速狗']);
    });

    test('the size axis is what actually separates look-alikes', () {
      // Growlithe and Arcanine share body style *and* colour — this is the
      // real 「狗 橙色」 case, and only relative size splits them.
      expect(_search('四足兽形 棕 小'), ['卡蒂狗']);
      expect(_search('四足兽形 棕 大'), ['风速狗']);
    });

    test('two colours OR together, standing in for the missing orange', () {
      // The palette has no orange, so 「棕 红」 must widen, not return nothing.
      expect(_search('棕 红'), ['卡蒂狗', '风速狗', '鲤鱼王', '快龙']);
    });

    test('multi-valued kinds still AND', () {
      // A species really can be both Psychic and Flying.
      expect(_search('超能力 飞行'), ['洛奇亚']);
    });

    test('stacking a third axis narrows further', () {
      expect(_search('二代'), ['皮丘', '洛奇亚']);
      expect(_search('二代 传说'), ['洛奇亚']);
    });

    test('an alias never removes name matches', () {
      // 鱼 is the fish body style, but Magikarp's genus/name must still hit.
      expect(_search('鱼'), contains('鲤鱼王'));
    });

    test('single-word search still behaves like substring search', () {
      expect(_search('快龙'), ['快龙']);
      expect(_search('Lugia'), ['洛奇亚']);
      expect(_search('149'), ['快龙']);
    });

    test('a query with no match returns nothing', () {
      expect(_search('传说 幼年'), isEmpty);
    });
  });

  group('DexFilter species axes', () {
    test('axes stack', () {
      const filter = DexFilter(shapeSlug: 'quadruped', colorSlugs: {'brown'});
      expect(filter.isActive, isTrue);
      expect(filter.hasSpeciesAxis, isTrue);
      expect(filter.matchesSpeciesAxes(growlithe), isTrue);
      expect(filter.matchesSpeciesAxes(pichu), isFalse);
    });

    test('the colour set is an OR', () {
      const filter = DexFilter(colorSlugs: {'brown', 'red'});
      expect(filter.matchesSpeciesAxes(growlithe), isTrue);
      expect(filter.matchesSpeciesAxes(magikarp), isTrue);
      expect(filter.matchesSpeciesAxes(pichu), isFalse);
    });

    test('the size axis splits same-shape same-colour species', () {
      const small = DexFilter(shapeSlug: 'quadruped', sizeSlug: 'small');
      expect(small.matchesSpeciesAxes(growlithe), isTrue);
      expect(small.matchesSpeciesAxes(arcanine), isFalse);
    });

    test('tag and generation axes combine', () {
      const filter = DexFilter(tag: 'legendary', generation: 2);
      expect(filter.matchesSpeciesAxes(lugia), isTrue);
      expect(filter.matchesSpeciesAxes(mew), isFalse);
    });

    test('without() clears one axis', () {
      const filter = DexFilter(shapeSlug: 'quadruped', colorSlugs: {'brown'});
      final relaxed = filter.without(color: true);
      expect(relaxed.colorSlugs, isEmpty);
      expect(relaxed.shapeSlug, 'quadruped');
      expect(relaxed.matchesSpeciesAxes(pichu), isTrue);
    });

    test('a filter with no axis at all is inactive', () {
      expect(const DexFilter().hasSpeciesAxis, isFalse);
      expect(const DexFilter().isActive, isFalse);
    });
  });

  group('pre-Gen VI body styles', () {
    test('the reclassified species are the eight 52poke lists', () {
      expect(kDexPreGen6ShapeSlugs.keys.toSet(), {
        10, 13, 265, 412, 413, 422, 423, 488,
      });
    });

    test('a reclassified species answers to both body styles', () {
      // 双重筛选: HGSS players know Caterpie as 蛇形, PokeAPI says 虫形.
      expect(dexSummaryHasShape(caterpie, 'armor'), isTrue);
      expect(dexSummaryHasShape(caterpie, 'squiggle'), isTrue);
      expect(dexSummaryHasShape(caterpie, 'quadruped'), isFalse);
      expect(_search('蛇形'), contains('绿毛虫'));
      expect(_search('虫形'), contains('绿毛虫'));
    });

    test('unaffected species are unchanged', () {
      expect(dexPreGen6ShapeSlug(growlithe.id), isNull);
      expect(dexSummaryHasShape(growlithe, 'squiggle'), isFalse);
    });

    test('the filter axis honours the historical value too', () {
      const filter = DexFilter(shapeSlug: 'squiggle');
      expect(filter.matchesSpeciesAxes(caterpie), isTrue);
      expect(filter.matchesSpeciesAxes(growlithe), isFalse);
    });
  });

  group('size buckets', () {
    test('buckets cover the real height range without gaps', () {
      for (var dm = 1; dm <= 200; dm++) {
        expect(
          DexSizeBucket.forHeightDm(dm),
          isNotNull,
          reason: '\$dm dm falls in no bucket',
        );
      }
    });

    test('missing or zero height yields no bucket', () {
      expect(DexSizeBucket.forHeightDm(null), isNull);
      expect(DexSizeBucket.forHeightDm(0), isNull);
    });

    test('known species land in the expected bucket', () {
      expect(DexSizeBucket.forHeightDm(7), DexSizeBucket.small);
      expect(DexSizeBucket.forHeightDm(19), DexSizeBucket.large);
      expect(DexSizeBucket.forHeightDm(4), DexSizeBucket.tiny);
      expect(DexSizeBucket.forHeightDm(200), DexSizeBucket.huge);
    });
  });

  _evolutionTriggerTests();

  group('label tables', () {
    test('every shape slug has a Chinese label', () {
      expect(kDexShapeSlugs, hasLength(14));
      for (final slug in kDexShapeSlugs) {
        expect(dexShapeLabelZh(slug), isNotNull, reason: slug);
      }
    });

    test('every colour slug has a Chinese label', () {
      expect(kDexColorSlugs, hasLength(10));
      for (final slug in kDexColorSlugs) {
        expect(dexColorLabelZh(slug), isNotNull, reason: slug);
      }
    });

    test('the palette has no orange — swatches, not words', () {
      expect(kDexColorSlugs, isNot(contains('orange')));
    });

    test('suggestions all resolve to a real constraint', () {
      for (final word in kDexSearchSuggestions) {
        expect(
          resolveDexSearchWord(word).kind,
          isNot(DexConstraintKind.text),
          reason: '$word is offered as a suggestion but resolves to nothing',
        );
      }
    });
  });
}

// Structured evolution triggers — requested by the parallel session so trade
// detection can stop string-matching `triggerZh`.
void _evolutionTriggerTests() {
  group('EvolutionTrigger', () {
    test('trade + held item survives the round trip', () {
      // 巨钳螳螂: triggerZh flattens this to a bare 「交换」.
      const json = {'trigger': 'trade', 'heldItem': 'metal-coat'};
      final trigger = EvolutionTrigger.fromJson(json);
      expect(trigger.isTrade, isTrue);
      expect(trigger.requiresHeldItem, isTrue);
      expect(trigger.heldItem, 'metal-coat');
      expect(trigger.toJson(), json);
    });

    test('a plain trade is distinguishable from an item trade', () {
      final plain = EvolutionTrigger.fromJson(const {'trigger': 'trade'});
      expect(plain.isTrade, isTrue);
      expect(plain.requiresHeldItem, isFalse);
    });

    test('multi-condition entries keep every field', () {
      final espeon = EvolutionTrigger.fromJson(const {
        'trigger': 'level-up',
        'minHappiness': 160,
        'timeOfDay': 'day',
      });
      expect(espeon.isTrade, isFalse);
      expect(espeon.minHappiness, 160);
      expect(espeon.timeOfDay, 'day');
    });

    test('a node without triggers decodes to an empty list', () {
      final node = EvolutionNode.fromJson(const {
        'id': 1,
        'nameEn': 'Bulbasaur',
        'nameZh': '妙蛙种子',
      });
      expect(node.triggers, isEmpty);
    });
  });
}
