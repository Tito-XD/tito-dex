/// HGSS / Johto dex scope constants for PokeAPI version groups.
library;

import '../parser/hgss_map_lookup.dart';
import 'dex_models.dart';
import '../../l10n/zh_catalog.dart';

const hgssVersionGroup = 'heartgold-soulsilver';

const johtoPokedexNames = <String>{
  'original-johto',
  'updated-johto',
};

/// HeartGold / SoulSilver first — primary game scope for TitoDex.
const hgssFlavorVersions = <String>[
  'heartgold',
  'soulsilver',
  'crystal',
  'gold',
  'silver',
];

const maxBaseStatValue = 255;

const flavorVersionLabelsZh = <String, String>{
  'gold': '金版',
  'silver': '银版',
  'crystal': '水晶版',
  'heartgold': '心金',
  'soulsilver': '魂银',
  'zh-reference': '心金·魂银（中文参考）',
};

/// Common PokeAPI `location-area` slugs → Chinese labels for HGSS encounters.
const encounterAreaLabelsZh = <String, String>{
  'pallet-town-area': '真新镇',
  'viridian-city-area': '常磐市',
  'viridian-forest-area': '常磐森林',
  'pewter-city-area': '尼比市',
  'route-1-area': '1号道路',
  'route-2-area': '2号道路',
  'route-24-area': '24号道路',
  'route-25-area': '25号道路',
  'safari-zone-area': '狩猎地带',
  'mt-silver-area': '白银山',
  'national-park-area': '自然公园',
  'bell-tower-1f': '铃铛塔',
  'burned-tower-1f': '烧焦塔',
  'ice-path-1f': '冰雪小径',
  'mt-mortar-1f': '擂钵山',
  'dark-cave-area': '黑暗洞窟',
  'union-cave-1f': '连接洞窟',
  'slowpoke-well-1f': '呆呆兽之井',
};

String encounterAreaLabelZh(String slug) {
  if (encounterAreaLabelsZh.containsKey(slug)) {
    return encounterAreaLabelsZh[slug]!;
  }
  final route = RegExp(r'^route-(\d+)-').firstMatch(slug);
  if (route != null) {
    return '${route.group(1)}号道路';
  }
  final cleaned = slug
      .replaceAll(RegExp(r'-area$'), '')
      .replaceAll('-', ' ');
  return cleaned;
}

/// Resolves obtain-location labels from bundled catalog, PokeAPI slugs, or HGSS map ids.
String resolveObtainAreaLabelZh(String areaSlug) {
  final fromCatalog = zhCatalogLocationAreaLabel(areaSlug);
  if (fromCatalog != null && fromCatalog.isNotEmpty) {
    return fromCatalog;
  }

  final fromTable = encounterAreaLabelsZh[areaSlug];
  if (fromTable != null) {
    return fromTable;
  }
  if (RegExp(r'^\d+$').hasMatch(areaSlug)) {
    final fromHgssCatalog = zhCatalogHgssMapLabel(areaSlug);
    if (fromHgssCatalog != null && fromHgssCatalog.isNotEmpty) {
      return fromHgssCatalog;
    }
    return locationLabelForMapId(int.parse(areaSlug));
  }
  final fallback = encounterAreaLabelZh(areaSlug);
  if (RegExp(r'^\d+$').hasMatch(fallback)) {
    return '地点 $fallback';
  }
  return fallback;
}

const statLabelsZh = <String, String>{
  'hp': 'HP',
  'attack': '攻击',
  'defense': '防御',
  'special-attack': '特攻',
  'special-defense': '特防',
  'speed': '速度',
};

const moveMethodLabelsZh = <String, String>{
  'level-up': '等级提升',
  'machine': '招式学习器',
  'egg': '蛋招式',
  'tutor': '教学招式',
};

String flavorVersionLabelZh(String version) =>
    flavorVersionLabelsZh[version] ?? version;

String moveMethodLabelZh(String method) =>
    moveMethodLabelsZh[method] ?? method;

/// Regional pokedex scopes backed by CDN `pokedexNumbers` keys.
enum DexRegionalPokedex {
  national('national', '全国'),
  kanto('kanto', '关东'),
  johto('original-johto', '城都'),
  hoenn('hoenn', '丰缘'),
  sinnoh('original-sinnoh', '神奥'),
  unova('unova', '合众'),
  kalos('kalos-central', '卡洛斯'),
  alola('original-alola', '阿罗拉'),
  galar('galar', '伽勒尔'),
  paldea('paldea', '帕底亚'),
  hisui('hisui', '洗翠');

  const DexRegionalPokedex(this.primaryPokedexKey, this.labelZh);

  final String primaryPokedexKey;
  final String labelZh;

  /// All CDN / PokeAPI pokedex name keys that belong to this regional dex.
  List<String> get pokedexKeys => switch (this) {
        DexRegionalPokedex.national => const ['national'],
        DexRegionalPokedex.kanto => const ['kanto'],
        DexRegionalPokedex.johto => const ['original-johto', 'updated-johto'],
        DexRegionalPokedex.hoenn => const ['hoenn', 'updated-hoenn'],
        DexRegionalPokedex.sinnoh => const ['original-sinnoh', 'extended-sinnoh'],
        DexRegionalPokedex.unova => const ['unova', 'updated-unova'],
        DexRegionalPokedex.kalos => const [
            'kalos-central',
            'kalos-mountain',
            'kalos-coastal',
          ],
        DexRegionalPokedex.alola => const ['original-alola', 'updated-alola'],
        DexRegionalPokedex.galar => const [
            'galar',
            'isle-of-armor',
            'crown-tundra',
          ],
        DexRegionalPokedex.paldea => const ['paldea', 'kitakami', 'blueberry'],
        DexRegionalPokedex.hisui => const ['hisui'],
      };

  static DexRegionalPokedex? fromStorageKey(String? key) {
    if (key == null) {
      return null;
    }
    for (final scope in DexRegionalPokedex.values) {
      if (scope.name == key) {
        return scope;
      }
    }
    return null;
  }
}

String regionalPokedexLabelZh(DexRegionalPokedex scope) => scope.labelZh;

enum DexRegionalScope { national, johto, kanto }

(int, int) regionalDexIdRange(DexRegionalScope scope) {
  return switch (scope) {
    DexRegionalScope.national => (1, titodexMaxNationalDexId),
    DexRegionalScope.johto => (152, 251),
    DexRegionalScope.kanto => (1, 151),
  };
}

/// HGSS save-linked dex progress still caps at Gen IV national dex size.
(int, int) hgssSaveDexIdRange(DexRegionalScope scope) {
  return switch (scope) {
    DexRegionalScope.national => (1, hgssMaxNationalDexId),
    DexRegionalScope.johto => (152, 251),
    DexRegionalScope.kanto => (1, 151),
  };
}

String regionalScopeLabelZh(DexRegionalScope scope) {
  return switch (scope) {
    DexRegionalScope.national => '全国',
    DexRegionalScope.johto => '城都',
    DexRegionalScope.kanto => '关东',
  };
}
