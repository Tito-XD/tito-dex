/// HGSS / Johto dex scope constants for PokeAPI version groups.
library;

import 'dex_models.dart';

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
};

String flavorVersionLabelZh(String version) =>
    flavorVersionLabelsZh[version] ?? version;

String moveMethodLabelZh(String method) =>
    moveMethodLabelsZh[method] ?? method;

enum DexRegionalScope { national, johto, kanto }

(int, int) regionalDexIdRange(DexRegionalScope scope) {
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
