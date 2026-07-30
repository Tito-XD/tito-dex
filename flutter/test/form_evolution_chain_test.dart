import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/form_evolution_targets.dart';

/// Chains as the bundle ships them: species-level, with every form's branch
/// merged into one tree.
EvolutionNode _node(
  int id,
  String nameEn,
  String nameZh, {
  List<EvolutionNode> children = const [],
}) => EvolutionNode(
  id: id,
  nameEn: nameEn,
  nameZh: nameZh,
  localSpritePath: 'sprites/$id.png',
  children: children,
);

PokemonFormDetail _form(
  String key,
  int pokemonId, {
  required bool isDefault,
  bool isCosmetic = false,
  String? spritePath,
}) => PokemonFormDetail(
  key: key,
  pokemonId: pokemonId,
  nameEn: key,
  nameZh: key,
  kind: isDefault ? PokemonFormKind.form : PokemonFormKind.regional,
  isDefault: isDefault,
  isBattleOnly: false,
  isMega: false,
  isCosmetic: isCosmetic,
  types: const ['water'],
  heightDm: 4,
  weightHg: 85,
  localSpritePath: spritePath,
);

PokemonDetail _detail(
  int id,
  String nameEn,
  String nameZh, {
  required EvolutionNode chain,
  required List<PokemonFormDetail> forms,
}) => PokemonDetail(
  summary: PokemonSummary(
    id: id,
    nameEn: nameEn,
    nameZh: nameZh,
    types: const ['water'],
  ),
  genusZh: '水鱼宝可梦',
  heightDm: 4,
  weightHg: 85,
  weaknesses: const [],
  resistances: const [],
  immunities: const [],
  stabSuperEffective: const [],
  evolutionChain: chain,
  forms: forms,
);

void main() {
  final wooperChain = _node(
    194,
    'Wooper',
    '乌波',
    children: [
      _node(195, 'Quagsire', '沼王'),
      _node(980, 'Clodsire', '土王'),
    ],
  );
  final growlitheChain = _node(
    58,
    'Growlithe',
    '卡蒂狗',
    children: [_node(59, 'Arcanine', '风速狗')],
  );

  group('non-default forms fall back to the species chain', () {
    test('a regional form no longer renders an empty evolution card', () {
      final paldeanWooper = _form('wooper-paldea', 10253, isDefault: false);
      final detail = _detail(
        194,
        'Wooper',
        '乌波',
        chain: wooperChain,
        forms: [_form('wooper', 194, isDefault: true), paldeanWooper],
      );

      expect(detail.forForm(paldeanWooper).evolutionChain, isNotNull);
    });

    test('a form-specific chain from the bundle still wins', () {
      final bundled = _node(194, 'Wooper', '乌波（帕底亚的样子）');
      final paldeanWooper = PokemonFormDetail(
        key: 'wooper-paldea',
        pokemonId: 10253,
        nameEn: 'Wooper-paldea',
        nameZh: '乌波（帕底亚的样子）',
        kind: PokemonFormKind.regional,
        isDefault: false,
        isBattleOnly: false,
        isMega: false,
        isCosmetic: false,
        types: const ['poison', 'ground'],
        heightDm: 4,
        weightHg: 110,
        evolutionChain: bundled,
      );
      final detail = _detail(
        194,
        'Wooper',
        '乌波',
        chain: wooperChain,
        forms: [_form('wooper', 194, isDefault: true), paldeanWooper],
      );

      expect(detail.forForm(paldeanWooper).evolutionChain, same(bundled));
    });
  });

  group('filteredForForm splits the branches', () {
    test('帕底亚乌波 keeps only 土王', () {
      final filtered = wooperChain.filteredForForm('wooper-paldea');
      expect(filtered.children.map((c) => c.id), [980]);
      expect(filtered.nameZh, '乌波（帕底亚的样子）');
    });

    test('the default 乌波 keeps only 沼王', () {
      expect(
        wooperChain.filteredForForm('wooper').children.map((c) => c.id),
        [195],
      );
    });

    test('洗翠卡蒂狗 evolves into the Hisuian 风速狗, not the ordinary one', () {
      final filtered = growlitheChain.filteredForForm('growlithe-hisui');
      final child = filtered.children.single;
      expect(child.id, 59);
      expect(child.nameZh, '风速狗（洗翠的样子）');
      expect(child.formKey, 'arcanine-hisui');
      expect(filtered.nameZh, '卡蒂狗（洗翠的样子）');
    });

    test('the default 卡蒂狗 line is left in Chinese species names', () {
      final filtered = growlitheChain.filteredForForm('growlithe');
      expect(filtered.nameZh, '卡蒂狗');
      expect(filtered.children.single.nameZh, '风速狗');
    });

    test('the selected form sprite is used for the root node only', () {
      final filtered = growlitheChain.filteredForForm(
        'growlithe-hisui',
        rootSpritePath: 'sprites/forms/10398.png',
      );
      expect(filtered.localSpritePath, 'sprites/forms/10398.png');
      // The Hisuian Arcanine sprite lives in the target species' detail, which
      // this screen never loads — the species art is the honest fallback.
      expect(filtered.children.single.localSpritePath, 'sprites/59.png');
    });

    test('a form selected further down the chain still maps back to the root', () {
      final filtered = growlitheChain.filteredForForm('arcanine-hisui');
      expect(filtered.nameZh, '卡蒂狗（洗翠的样子）');
      expect(filtered.children.single.formKey, 'arcanine-hisui');
    });

    test('multi-stage regional lines stay regional the whole way down', () {
      final zigzagoon = _node(
        263,
        'Zigzagoon',
        '蛇纹熊',
        children: [
          _node(
            264,
            'Linoone',
            '直冲熊',
            children: [_node(862, 'Obstagoon', '堵拦熊')],
          ),
        ],
      );

      final galar = zigzagoon.filteredForForm('zigzagoon-galar');
      expect(galar.children.single.nameZh, '直冲熊（伽勒尔的样子）');
      expect(galar.children.single.children.single.id, 862);

      // 直冲熊 is a dead end outside Galar.
      final ordinary = zigzagoon.filteredForForm('zigzagoon');
      expect(ordinary.children.single.children, isEmpty);
    });

    test('the cloak carries over to 结草贵妇 but not to 绅士蛾', () {
      final burmy = _node(
        412,
        'Burmy',
        '结草儿',
        children: [
          _node(413, 'Wormadam', '结草贵妇'),
          _node(414, 'Mothim', '绅士蛾'),
        ],
      );

      final trash = burmy.filteredForForm('burmy-trash');
      expect(trash.children.map((c) => c.nameZh), [
        '结草贵妇（垃圾蓑衣）',
        '绅士蛾',
      ]);
    });

    test('an unlisted form (mega, g-max, cosmetic) keeps the whole chain', () {
      final filtered = wooperChain.filteredForForm('wooper-totally-unknown');
      expect(filtered, same(wooperChain));
    });

    test('no form selected leaves the chain untouched', () {
      expect(wooperChain.filteredForForm(null), same(wooperChain));
    });

    test('a chain already resolved by the bundle is not filtered twice', () {
      final bundled = EvolutionNode(
        id: 58,
        nameEn: 'Growlithe',
        nameZh: '卡蒂狗（洗翠的样子）',
        formKey: 'growlithe-hisui',
        children: [
          EvolutionNode(
            id: 59,
            nameEn: 'Arcanine',
            nameZh: '风速狗（洗翠的样子）',
            formKey: 'arcanine-hisui',
          ),
        ],
      );
      final filtered = bundled.filteredForForm('growlithe-hisui');
      expect(filtered, same(bundled));
      expect(filtered.nameZh, '卡蒂狗（洗翠的样子）');
    });
  });

  test('formKey survives a JSON round trip', () {
    final restored = EvolutionNode.fromJson(
      growlitheChain.filteredForForm('growlithe-hisui').toJson(),
    );
    expect(restored.formKey, 'growlithe-hisui');
    expect(restored.children.single.formKey, 'arcanine-hisui');
  });

  test('every curated target names a form suffix the app can label', () {
    for (final entry in kFormEvolutionTargets.entries) {
      for (final target in entry.value) {
        final suffix = target.formSuffix;
        if (suffix == null) continue;
        expect(
          formVariantLabelZh(suffix),
          isNotNull,
          reason: '${entry.key} → $suffix has no Chinese label',
        );
      }
    }
  });
}
