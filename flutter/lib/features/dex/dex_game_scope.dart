/// HGSS / Johto dex scope constants for PokeAPI version groups.
library;

import 'dex_models.dart';

const hgssVersionGroup = 'heartgold-soulsilver';

const johtoPokedexNames = <String>{
  'original-johto',
  'updated-johto',
};

const hgssFlavorVersions = <String>[
  'gold',
  'silver',
  'crystal',
  'heartgold',
  'soulsilver',
];

const flavorVersionLabelsZh = <String, String>{
  'gold': '金版',
  'silver': '银版',
  'crystal': '水晶版',
  'heartgold': '心金',
  'soulsilver': '魂银',
};

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
