import 'package:flutter/foundation.dart';

import 'ask_motion_catalog.dart';

enum AskMotionKind { ball, book, map, berry, berries, emblems, tokens }

/// A small semantic cue for the changing answer heading, never answer evidence.
@immutable
class AskMotionTheme {
  const AskMotionTheme({
    required this.topic,
    required this.kind,
    required this.assets,
  });

  final String topic;
  final AskMotionKind kind;
  final List<String> assets;
}

const _spriteRoot = 'assets/ask_motion/';
const _book = '${_spriteRoot}sonias-book.png';
const _typeRoot = 'assets/type_icons/';

String _sprite(String slug) => '$_spriteRoot$slug.png';
String _type(String slug) => '$_typeRoot$slug.png';

// Fold full-width Latin input without introducing a normalization dependency.
String _normalize(String text) => String.fromCharCodes(
  text.runes.map((rune) {
    if (rune >= 0xff01 && rune <= 0xff5e) return rune - 0xfee0;
    return rune == 0x3000 ? 0x20 : rune;
  }),
).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

bool _containsName(String text, String name) {
  final value = _normalize(name);
  if (value.isEmpty || !text.contains(value)) return false;
  if (RegExp(r'^[a-z0-9 -]+$').hasMatch(value)) {
    return RegExp(
      '(?:^|[^a-z])${RegExp.escape(value)}(?=\$|[^a-z])',
    ).hasMatch(text);
  }
  return value.length > 1;
}

List<List<String>> _matches(String text, List<List<String>> rows) {
  int position(List<String> row) {
    final zh = text.indexOf(_normalize(row[0]));
    final en = row[1].isEmpty ? -1 : text.indexOf(_normalize(row[1]));
    if (zh < 0) return en;
    if (en < 0) return zh;
    return zh < en ? zh : en;
  }

  return rows
      .where(
        (row) => _containsName(text, row[0]) || _containsName(text, row[1]),
      )
      .toList()
    ..sort((a, b) {
      final byPosition = position(a).compareTo(position(b));
      return byPosition != 0 ? byPosition : b[0].length.compareTo(a[0].length);
    });
}

AskMotionTheme _theme(
  String topic,
  AskMotionKind kind,
  Iterable<String> assets,
) => AskMotionTheme(
  topic: topic,
  kind: kind,
  assets: List.unmodifiable(assets.where((s) => s.isNotEmpty).toSet().take(6)),
);

/// Uses the bundled entity names and exact local artwork for both APK variants.
/// Missing artwork falls back to a reference book, never an unrelated item.
AskMotionTheme classifyAskMotionTheme(String question) {
  final text = _normalize(question);
  bool has(String pattern) => RegExp(pattern).hasMatch(text);
  final items = _matches(text, askMotionCatalogItems);
  final species = _matches(text, askMotionCatalogSpecies);
  // 喷火 is a move, but the 喷火 in 喷火龙 is part of the species name.
  // Resolve longer entities before matching embedded move/ability names.
  var mechanicsText = text;
  for (final row in [...species, ...items]) {
    mechanicsText = mechanicsText.replaceAll(_normalize(row[0]), '');
    if (row[1].isNotEmpty) {
      mechanicsText = mechanicsText.replaceAll(_normalize(row[1]), '');
    }
  }
  final moves = _matches(mechanicsText, askMotionCatalogMoves);
  final abilities = _matches(mechanicsText, askMotionCatalogAbilities);
  Iterable<String> itemAssets() => items.map((row) => row[3]);
  final berries = items.where((row) => row[2] == 'berry').toList();
  final berryIntent =
      berries.isNotEmpty || items.isEmpty && has(r'树果|莓果|berry|berries');
  final typeIntent =
      has(r'属性|克制|抗性|弱点|免疫|几倍|相克|抵抗|type\b|weakness|resistan') ||
      askMotionCatalogTypes.any((row) => text.contains('${row[0]}系'));
  final evolutionIntent = has(r'进化|mega|超进化|evolv|evolution');
  final breedingIntent = has(r'孵化|孵蛋|生蛋|蛋组|蛋群|遗传|培育|育成|breed|hatch|egg group');
  final abilityIntent = has(r'特性|梦特|隐藏特性|ability|abilities');
  final moveIntent = has(
    r'招式|技能|配招|招式机|技能机|秘传|习得|遗忘|回忆|学会|学什么|能学|move\b|moves\b|learn',
  );
  final levelIntent = has(r'升级|练级|经验|等级|几级|多少级|level|experience|exp\b');
  final statIntent = has(
    r'努力值|个体值|种族值|能力值|性格|实数值|伤害|伤害计算|速度线|亲密度|好感度|数值|性别|闪光|iv\b|ev\b|stats?\b|nature',
  );

  if (berryIntent) {
    final exactAssets = berries.map((row) => row[3]).toSet();
    final multiple = exactAssets.length > 1;
    return _theme(
      multiple ? 'berries' : 'berry',
      multiple ? AskMotionKind.berries : AskMotionKind.berry,
      berries.isNotEmpty
          ? exactAssets
          : ['oran-berry', 'pecha-berry', 'leppa-berry'].map(_sprite),
    );
  }

  if (typeIntent) {
    // A species/move/item name may itself contain a type word (喷火龙, 火焰拳).
    // Remove these whole names before looking for explicit match-up types.
    var typeText = text;
    for (final row in [...species, ...moves, ...items]) {
      typeText = typeText.replaceAll(_normalize(row[0]), '');
      if (row[1].isNotEmpty) {
        typeText = typeText.replaceAll(_normalize(row[1]), '');
      }
    }
    final types = askMotionCatalogTypes
        .where(
          (row) => typeText.contains(row[0]) || _containsName(typeText, row[1]),
        )
        .toList();
    int typePosition(List<String> row) {
      final zh = typeText.indexOf(row[0]);
      return zh < 0 ? typeText.indexOf(row[1]) : zh;
    }

    types.sort((a, b) => typePosition(a).compareTo(typePosition(b)));
    return _theme(
      'types',
      AskMotionKind.emblems,
      types.isNotEmpty
          ? types.map((row) => _type(row[1]))
          : moves.isNotEmpty
          ? moves.map((row) => _type(row[2]))
          : [
              'normal',
              'fire',
              'water',
              'grass',
              'electric',
              'fairy',
            ].map(_type),
    );
  }
  if (evolutionIntent) {
    return _theme(
      'evolution',
      AskMotionKind.tokens,
      items.isNotEmpty
          ? itemAssets()
          : ['thunder-stone', 'fire-stone', 'water-stone'].map(_sprite),
    );
  }
  if (breedingIntent) {
    return _theme(
      'breeding',
      AskMotionKind.tokens,
      items.isNotEmpty ? itemAssets() : ['egg', 'destiny-knot'].map(_sprite),
    );
  }
  if (abilityIntent) {
    return _theme(
      'abilities',
      AskMotionKind.tokens,
      items.isNotEmpty ? itemAssets() : [_sprite('ability-capsule')],
    );
  }
  if (has(
    r'天气|晴天|雨天|下雨|沙暴|冰雹|下雪|大晴天|日照|降雨|\b(?:weather|sunny|rain(?:y|fall|ing)?|snow(?:y|fall|ing)?)\b',
  )) {
    final weatherAssets = has(r'雨|\brain(?:y|fall|ing)?\b')
        ? ['damp-rock']
        : has(r'晴|日照|\bsunny\b')
        ? ['heat-rock']
        : has(r'沙暴')
        ? ['smooth-rock']
        : has(r'雪|冰雹|\bsnow(?:y|fall|ing)?\b')
        ? ['icy-rock']
        : ['heat-rock', 'damp-rock', 'icy-rock'];
    return _theme(
      'weather',
      AskMotionKind.emblems,
      items.isNotEmpty ? itemAssets() : weatherAssets.map(_sprite),
    );
  }
  if (has(r'升级|练级|经验|level up|experience')) {
    return _theme(
      'level',
      AskMotionKind.tokens,
      items.isNotEmpty
          ? itemAssets()
          : ['exp-candy-m', 'lucky-egg'].map(_sprite),
    );
  }
  if (statIntent) {
    return _theme(
      'stats',
      AskMotionKind.tokens,
      items.isNotEmpty
          ? itemAssets()
          : has(r'亲密度|好感度')
          ? [_sprite('soothe-bell')]
          : ['protein', 'calcium'].map(_sprite),
    );
  }
  if (moveIntent || moves.isNotEmpty && items.isEmpty && !levelIntent) {
    return _theme('moves', AskMotionKind.book, [
      _book,
      ...moves.map((row) => _type(row[2])),
    ]);
  }
  if (levelIntent) {
    return moves.isNotEmpty
        ? _theme('moves', AskMotionKind.book, [
            _book,
            ...moves.map((row) => _type(row[2])),
          ])
        : _theme(
            'level',
            AskMotionKind.tokens,
            items.isNotEmpty
                ? itemAssets()
                : ['exp-candy-m', 'lucky-egg'].map(_sprite),
          );
  }
  if (items.isNotEmpty) {
    return _theme('items', AskMotionKind.tokens, itemAssets());
  }
  if (abilities.isNotEmpty) {
    return _theme('abilities', AskMotionKind.tokens, [
      _sprite('ability-capsule'),
    ]);
  }
  if (has(r'道具|物品|装备|携带|购买|商店|哪里买|在哪买|价格|售价|item\b|items\b')) {
    return _theme(
      'items',
      AskMotionKind.tokens,
      ['potion', 'great-ball', 'exp-candy-m'].map(_sprite),
    );
  }
  if (has(r'捕捉|捕获|捕到|抓|出没|遇到|遇见|刷闪|出现地点|在哪找|在哪里找|catch|encounter') ||
      species.isNotEmpty && has(r'在哪|哪里|何处')) {
    return _theme(
      'capture',
      AskMotionKind.ball,
      ['poke-ball', 'great-ball'].map(_sprite),
    );
  }
  if (has(
    r'路线|道路|城市|城镇|怎么走|如何走|怎么去|如何去|怎么到|怎么过|如何过|攻略|道馆|徽章|四天王|冠军|迷宫|洞穴|隧道|瀑布|森林|火箭队|剧情|支线|主线|卡关|下一步|route|walkthrough|gym',
  )) {
    return _theme('route', AskMotionKind.map, [_sprite('town-map')]);
  }
  if (species.isNotEmpty || has(r'宝可梦|精灵|图鉴|pokemon|pokémon')) {
    return _theme('capture', AskMotionKind.ball, [
      _sprite('poke-ball'),
      'assets/icons/Dex.png',
    ]);
  }
  return _theme('general', AskMotionKind.book, [_book]);
}

/// Stable topic order for the small idle word slot; labels belong to l10n.
const askMotionIdleThemes = <AskMotionTheme>[
  AskMotionTheme(
    topic: 'capture',
    kind: AskMotionKind.ball,
    assets: ['${_spriteRoot}poke-ball.png', '${_spriteRoot}great-ball.png'],
  ),
  AskMotionTheme(
    topic: 'moves',
    kind: AskMotionKind.book,
    assets: [_book, '${_typeRoot}fire.png'],
  ),
  AskMotionTheme(
    topic: 'types',
    kind: AskMotionKind.emblems,
    assets: ['${_typeRoot}fire.png', '${_typeRoot}grass.png'],
  ),
  AskMotionTheme(
    topic: 'berry',
    kind: AskMotionKind.berry,
    assets: ['${_spriteRoot}oran-berry.png'],
  ),
  AskMotionTheme(
    topic: 'evolution',
    kind: AskMotionKind.tokens,
    assets: ['${_spriteRoot}thunder-stone.png'],
  ),
  AskMotionTheme(
    topic: 'level',
    kind: AskMotionKind.tokens,
    assets: ['${_spriteRoot}lucky-egg.png'],
  ),
  AskMotionTheme(
    topic: 'items',
    kind: AskMotionKind.tokens,
    assets: ['${_spriteRoot}leftovers.png'],
  ),
  AskMotionTheme(
    topic: 'route',
    kind: AskMotionKind.map,
    assets: ['${_spriteRoot}town-map.png'],
  ),
  AskMotionTheme(
    topic: 'abilities',
    kind: AskMotionKind.tokens,
    assets: ['${_spriteRoot}ability-capsule.png'],
  ),
  AskMotionTheme(
    topic: 'breeding',
    kind: AskMotionKind.tokens,
    assets: ['${_spriteRoot}egg.png', '${_spriteRoot}destiny-knot.png'],
  ),
  AskMotionTheme(
    topic: 'stats',
    kind: AskMotionKind.tokens,
    assets: ['${_spriteRoot}protein.png', '${_spriteRoot}calcium.png'],
  ),
  AskMotionTheme(
    topic: 'weather',
    kind: AskMotionKind.emblems,
    assets: ['${_spriteRoot}damp-rock.png'],
  ),
  AskMotionTheme(topic: 'general', kind: AskMotionKind.book, assets: [_book]),
];
