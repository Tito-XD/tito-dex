/// HGSS / Johto dex scope constants for PokeAPI version groups.
library;

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
