/// Vocabulary layer for dex search.
///
/// Search is offline, so it cannot learn from query logs. Everything a player
/// might type has to be enumerated up front — that alias table is the whole
/// feature. A query word resolves to at most one [DexSearchConstraint]; words
/// that resolve to nothing fall back to plain text matching.
library;

export 'dex_axis_labels.g.dart';

import 'dex_axis_labels.g.dart';
import 'dex_models.dart';
import 'type_chart.dart';

/// What a single query word narrows the dex down to.
enum DexConstraintKind { type, shape, color, generation, size, tag, text }

extension DexConstraintKindX on DexConstraintKind {
  /// Whether a species can hold more than one value of this kind.
  ///
  /// This decides how repeated words combine. A species has exactly one body
  /// style, colour, generation and size, so ANDing two of them can only ever
  /// return nothing — those OR instead, which is what makes 「棕 红」 behave like
  /// the multi-select colour picker. Types and tags are genuinely multi-valued,
  /// so 「火 飞行」 correctly means the Fire/Flying dual type.
  bool get isSingleValued => switch (this) {
    DexConstraintKind.shape ||
    DexConstraintKind.color ||
    DexConstraintKind.generation ||
    DexConstraintKind.size => true,
    DexConstraintKind.type ||
    DexConstraintKind.tag ||
    DexConstraintKind.text => false,
  };
}

/// Relative-size buckets over `heightDm`.
///
/// Boundaries were picked against the real 1025-species height distribution
/// (median 1.0 m, p90 2.0 m) so no bucket collapses to a handful of species:
/// roughly 19 / 29 / 24 / 16 / 13 percent.
enum DexSizeBucket {
  tiny('tiny', '极小', null, 4),
  small('small', '小', 5, 9),
  medium('medium', '中', 10, 14),
  large('large', '大', 15, 19),
  huge('huge', '巨大', 20, null);

  const DexSizeBucket(this.slug, this.labelZh, this.minDm, this.maxDm);

  final String slug;
  final String labelZh;
  final int? minDm;
  final int? maxDm;

  bool contains(int heightDm) =>
      (minDm == null || heightDm >= minDm!) &&
      (maxDm == null || heightDm <= maxDm!);

  static DexSizeBucket? forHeightDm(int? heightDm) {
    if (heightDm == null || heightDm <= 0) {
      return null;
    }
    for (final bucket in DexSizeBucket.values) {
      if (bucket.contains(heightDm)) {
        return bucket;
      }
    }
    return null;
  }

  static DexSizeBucket? fromSlug(String slug) {
    for (final bucket in DexSizeBucket.values) {
      if (bucket.slug == slug) {
        return bucket;
      }
    }
    return null;
  }
}

class DexSearchConstraint {
  const DexSearchConstraint(this.kind, this.value, {this.labelZh, String? raw})
    : raw = raw ?? value;

  /// Free text that matched no alias — name / genus / form substring search.
  const DexSearchConstraint.text(String word)
    : kind = DexConstraintKind.text,
      value = word,
      raw = word,
      labelZh = null;

  final DexConstraintKind kind;

  /// Slug for structured kinds; the raw word for [DexConstraintKind.text].
  final String value;

  /// The word the player actually typed, kept so an alias never *removes*
  /// results: 「鱼」 resolves to the fish body style but must still find 鲤鱼王.
  final String raw;

  /// Chinese label used by the filter banner, e.g. 「传说」.
  final String? labelZh;

  bool matches(PokemonSummary summary) {
    if (kind == DexConstraintKind.text) {
      return _matchesText(summary, value);
    }
    return _matchesStructured(summary) || _matchesText(summary, raw);
  }

  bool _matchesStructured(PokemonSummary summary) => switch (kind) {
    DexConstraintKind.type => summary.types.contains(value),
    DexConstraintKind.shape => dexSummaryHasShape(summary, value),
    DexConstraintKind.color => summary.colorSlug == value,
    DexConstraintKind.generation => summary.generation?.toString() == value,
    DexConstraintKind.size =>
      DexSizeBucket.forHeightDm(summary.heightDm)?.slug == value,
    DexConstraintKind.tag => summary.tags.contains(value),
    DexConstraintKind.text => false,
  };

  static bool _matchesText(PokemonSummary summary, String raw) {
    final lower = raw.toLowerCase();
    final numeric = int.tryParse(raw);
    if (numeric != null && summary.id == numeric) {
      return true;
    }
    if (summary.id.toString().contains(raw)) {
      return true;
    }
    if (summary.nameEn.toLowerCase().contains(lower)) {
      return true;
    }
    if (summary.nameZh.contains(raw)) {
      return true;
    }
    if (summary.genusZh?.contains(raw) ?? false) {
      return true;
    }
    if (summary.formSearchTerms.any(
      (term) => term.toLowerCase().contains(lower) || term.contains(raw),
    )) {
      return true;
    }
    return false;
  }
}

/// Body style slugs in Pokédex shape order (PokeAPI shape id 1–14, which is
/// the same numbering as 52poke's Body01–Body14 icons).
const kDexShapeSlugs = <String>[
  'ball',
  'squiggle',
  'fish',
  'arms',
  'blob',
  'upright',
  'legs',
  'quadruped',
  'wings',
  'tentacles',
  'heads',
  'humanoid',
  'bug-wings',
  'armor',
];

/// Body styles reassigned in Gen VI — PokeAPI only reports the modern value.
///
/// TitoDex is HGSS-first, so the Gen IV value is the one a player searching
/// their own Pokédex expects. All eight species below appear in HGSS. Matching
/// accepts *either* value so a search is never wrong in one direction.
/// Source: 52poke 宝可梦列表（按体形分类）→ 体形变更.
const kDexPreGen6ShapeSlugs = <int, String>{
  10: 'squiggle', // 绿毛虫 → armor in XY
  13: 'squiggle', // 独角虫
  265: 'squiggle', // 刺尾虫
  412: 'squiggle', // 结草儿 → blob in XY
  413: 'squiggle', // 结草贵妇
  422: 'armor', // 无壳海兔 → squiggle in XY
  423: 'armor', // 海兔兽
  488: 'armor', // 克雷色利亚
};

/// The body style this species had before Gen VI, when it differs from today's.
String? dexPreGen6ShapeSlug(int speciesId) => kDexPreGen6ShapeSlugs[speciesId];

/// The in-game Pokédex palette. Note there is no orange — orange species sit
/// in brown / red / yellow, so the picker should show swatches, not words.
const kDexColorSlugs = <String>[
  'black',
  'blue',
  'brown',
  'gray',
  'green',
  'pink',
  'purple',
  'red',
  'white',
  'yellow',
];

const kDexTagLabelsZh = <String, String>{
  'legendary': '传说',
  'mythical': '幻之宝可梦',
  'baby': '幼年',
  'pseudo-legendary': '准神',
};

/// Experience group — how fast a species levels.
/// Habitat exists only for Gen I–III species; the detail view must say so
/// rather than render a blank row for everything newer.

/// True when [slug] is either the species' current or its pre-Gen VI body
/// style — the 「双重筛选」 that keeps reclassified species findable both ways.
bool dexSummaryHasShape(PokemonSummary summary, String slug) =>
    summary.shapeSlug == slug || dexPreGen6ShapeSlug(summary.id) == slug;

String? dexShapeLabelZh(String slug) => kDexShapeLabelsZh[slug];
String? dexColorLabelZh(String slug) => kDexColorLabelsZh[slug];
String? dexTagLabelZh(String slug) => kDexTagLabelsZh[slug];
String? dexGrowthRateLabelZh(String slug) => kDexGrowthRateLabelsZh[slug];
String? dexHabitatLabelZh(String slug) => kDexHabitatLabelsZh[slug];

/// Every spelling a player might reach for, mapped to one constraint.
///
/// Chinese input is wildly inconsistent — 「神」「传说」「传说的宝可梦」 all mean
/// the same thing — so breadth here beats cleverness anywhere else.
final Map<String, DexSearchConstraint> _aliases = _buildAliases();

Map<String, DexSearchConstraint> _buildAliases() {
  final map = <String, DexSearchConstraint>{};

  void add(
    DexConstraintKind kind,
    String value,
    String labelZh,
    List<String> words,
  ) {
    for (final word in words) {
      map[word.toLowerCase()] = DexSearchConstraint(
        kind,
        value,
        labelZh: labelZh,
        raw: word,
      );
    }
  }

  // ── Tags ────────────────────────────────────────────────────────────────
  add(DexConstraintKind.tag, 'legendary', '传说', [
    '传说',
    '传说宝可梦',
    '传说的宝可梦',
    '神兽',
    '神',
    'legendary',
  ]);
  add(DexConstraintKind.tag, 'mythical', '幻之宝可梦', [
    '幻',
    '幻兽',
    '幻之宝可梦',
    '幻の',
    'mythical',
  ]);
  add(DexConstraintKind.tag, 'baby', '幼年', ['幼年', '幼年宝可梦', '宝宝', 'baby']);
  add(DexConstraintKind.tag, 'pseudo-legendary', '准神', [
    '准神',
    '600族',
    '伪传说',
    'pseudo',
    'pseudolegendary',
  ]);

  // ── Body style ──────────────────────────────────────────────────────────
  add(DexConstraintKind.shape, 'quadruped', '四足兽形', [
    '四足兽形',
    '四足',
    '四脚',
    'quadruped',
  ]);
  add(DexConstraintKind.shape, 'humanoid', '人形', ['人形', 'humanoid']);
  add(DexConstraintKind.shape, 'upright', '双足兽形', [
    '双足兽形',
    '双足',
    '直立',
    'upright',
  ]);
  add(DexConstraintKind.shape, 'wings', '双翅形', ['双翅形', '有翼', '翅膀', 'wings']);
  add(DexConstraintKind.shape, 'bug-wings', '多翅形', ['多翅形', 'bug-wings']);
  add(DexConstraintKind.shape, 'fish', '鱼形', ['鱼形', '鱼', 'fish']);
  add(DexConstraintKind.shape, 'squiggle', '蛇形', ['蛇形', '蛇', '细长', 'squiggle']);
  add(DexConstraintKind.shape, 'ball', '球形', ['球形', '球状', '球', 'ball']);
  add(DexConstraintKind.shape, 'arms', '双手形', ['双手形', 'arms']);
  add(DexConstraintKind.shape, 'blob', '柱形', ['柱形', 'blob']);
  add(DexConstraintKind.shape, 'legs', '双腿形', ['双腿形', 'legs']);
  add(DexConstraintKind.shape, 'tentacles', '触手形', [
    '触手形',
    '触手',
    '多足',
    'tentacles',
  ]);
  add(DexConstraintKind.shape, 'heads', '组合形', ['组合形', '多头', 'heads']);
  add(DexConstraintKind.shape, 'armor', '虫形', ['虫形', '甲壳', 'armor']);

  // ── Colour ──────────────────────────────────────────────────────────────
  add(DexConstraintKind.color, 'black', '黑', ['黑', '黑色', 'black']);
  add(DexConstraintKind.color, 'blue', '蓝', ['蓝', '蓝色', 'blue']);
  add(DexConstraintKind.color, 'brown', '棕', ['棕', '棕色', '褐', '褐色', 'brown']);
  add(DexConstraintKind.color, 'gray', '灰', ['灰', '灰色', 'gray', 'grey']);
  add(DexConstraintKind.color, 'green', '绿', ['绿', '绿色', 'green']);
  add(DexConstraintKind.color, 'pink', '粉', ['粉', '粉色', '粉红', 'pink']);
  add(DexConstraintKind.color, 'purple', '紫', ['紫', '紫色', 'purple']);
  add(DexConstraintKind.color, 'red', '红', ['红', '红色', 'red']);
  add(DexConstraintKind.color, 'white', '白', ['白', '白色', 'white']);
  add(DexConstraintKind.color, 'yellow', '黄', ['黄', '黄色', 'yellow']);

  // ── Relative size ───────────────────────────────────────────────────────
  add(DexConstraintKind.size, 'tiny', '极小', ['极小', '很小', '迷你']);
  add(DexConstraintKind.size, 'small', '小', ['小', '小型', '小只']);
  add(DexConstraintKind.size, 'medium', '中', ['中', '中等', '中型']);
  add(DexConstraintKind.size, 'large', '大', ['大', '大型', '大只']);
  add(DexConstraintKind.size, 'huge', '巨大', ['巨大', '超大', '庞大']);

  // ── Generation ──────────────────────────────────────────────────────────
  const generationWords = <int, List<String>>{
    1: ['一代', '第一世代', '初代', '关都世代', 'gen1'],
    2: ['二代', '第二世代', '城都世代', 'gen2'],
    3: ['三代', '第三世代', '丰缘世代', 'gen3'],
    4: ['四代', '第四世代', '神奥世代', 'gen4'],
    5: ['五代', '第五世代', '合众世代', 'gen5'],
    6: ['六代', '第六世代', '卡洛斯世代', 'gen6'],
    7: ['七代', '第七世代', '阿罗拉世代', 'gen7'],
    8: ['八代', '第八世代', '伽勒尔世代', 'gen8'],
    9: ['九代', '第九世代', '帕底亚世代', 'gen9'],
  };
  for (final entry in generationWords.entries) {
    add(
      DexConstraintKind.generation,
      '${entry.key}',
      '第${entry.key}世代',
      entry.value,
    );
  }

  return map;
}

/// Words offered on the empty search screen. Offline search cannot teach itself
/// what people want, so the UI has to teach people what search understands.
const kDexSearchSuggestions = <String>[
  '传说',
  '准神',
  '幻之宝可梦',
  '四足兽形',
  '双翅形',
  '四代',
];

/// Resolve one query word. Returns a text constraint when nothing matches.
DexSearchConstraint resolveDexSearchWord(String word) {
  final normalized = word.trim().toLowerCase();
  if (normalized.isEmpty) {
    return DexSearchConstraint.text(word.trim());
  }
  final alias = _aliases[normalized];
  if (alias != null) {
    return alias;
  }
  final typeSlug = _typeSlugForZh(word.trim());
  if (typeSlug != null) {
    return DexSearchConstraint(
      DexConstraintKind.type,
      typeSlug,
      labelZh: typeNameZh(typeSlug),
    );
  }
  return DexSearchConstraint.text(word.trim());
}

/// Split a query on whitespace and resolve each word independently.
///
/// Different kinds are ANDed — 「四足 棕」 means quadruped *and* brown — which is
/// what makes the search box double as the filter UI.
List<DexSearchConstraint> parseDexSearchQuery(String query) {
  final words = query.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words.map(resolveDexSearchWord).toList(growable: false);
}

/// Does [summary] satisfy the whole query?
///
/// Constraints of a single-valued kind (colour, body style, generation, size)
/// are ORed with each other and the groups are then ANDed. That is what lets a
/// player type 「棕 红 四足」 for "brownish *or* reddish quadrupeds" — the
/// in-game palette has no orange, so a player looking for an orange Pokémon has
/// to be able to name two adjacent colours without getting an empty list.
bool dexQueryMatches(
  List<DexSearchConstraint> constraints,
  PokemonSummary summary,
) {
  if (constraints.isEmpty) {
    return false;
  }
  final orGroups = <DexConstraintKind, bool>{};
  for (final constraint in constraints) {
    final matched = constraint.matches(summary);
    if (constraint.kind.isSingleValued) {
      orGroups[constraint.kind] =
          (orGroups[constraint.kind] ?? false) || matched;
    } else if (!matched) {
      return false;
    }
  }
  return orGroups.values.every((matched) => matched);
}

String? _typeSlugForZh(String word) {
  if (word.isEmpty) {
    return null;
  }
  final lower = word.toLowerCase();
  for (final slug in typeGridOrder) {
    if (slug == lower) {
      return slug;
    }
    final zh = typeNameZh(slug);
    // 「火」 should match 火 without also matching every 火-prefixed name.
    if (zh == word || '$word系' == zh || word == '$zh系') {
      return slug;
    }
  }
  return null;
}
