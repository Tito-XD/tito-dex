import 'pokemon_anniversary_catalog.g.dart';

/// Official commemorative graphics, independent from battle/shiny forms.
const pokemonAnniversarySourceUrl = 'https://www.pokemon.co.jp/ex/30th_logo/';

class PokemonAnniversaryArt {
  const PokemonAnniversaryArt(
    this.nationalId,
    this.file,
    this.nameJa,
    this.formJa,
  );

  final int nationalId;
  final String file;
  final String nameJa;
  final String formJa;

  bool get isBase => file == nationalId.toString().padLeft(4, '0');
  String get url =>
      '${pokemonAnniversarySourceUrl}assets/img/download/$file.png';
  String get officialLabel => formJa.isEmpty ? nameJa : '$nameJa · $formJa';
  String get label {
    if (nameJa.startsWith('メガ')) {
      if (nameJa.endsWith('Ｘ')) return '超级进化 X';
      if (nameJa.endsWith('Ｙ')) return '超级进化 Y';
      if (nameJa.endsWith('Ｚ')) return '超级进化 Z';
      return '超级进化';
    }
    if (formJa.isEmpty) return isBase ? '基础 Logo' : nameJa;
    return _formLabels[formJa] ?? '$formJa（日文）';
  }
}

final _catalog = <int, List<PokemonAnniversaryArt>>{};

List<PokemonAnniversaryArt> pokemonAnniversaryArts(int nationalId) {
  if (_catalog.isEmpty) {
    for (final (id, file, name, form) in pokemonAnniversaryCatalogRows) {
      (_catalog[id] ??= []).add(PokemonAnniversaryArt(id, file, name, form));
    }
    for (final id in _catalog.keys.toList()) {
      _catalog[id] = List.unmodifiable(_catalog[id]!);
    }
  }
  return _catalog[nationalId] ?? const [];
}

String? pokemonAnniversaryArtUrl(int nationalId) {
  final arts = pokemonAnniversaryArts(nationalId);
  if (arts.isEmpty) return null;
  return arts.firstWhere((art) => art.isBase, orElse: () => arts.first).url;
}

class PokemonAnniversarySelection {
  const PokemonAnniversarySelection(this.art, {required this.matchesForm});
  final PokemonAnniversaryArt art;
  final bool matchesForm;
}

/// Matches only known semantic identities against official names. File order,
/// branch numbers and PokeAPI IDs are not interchangeable form identifiers.
PokemonAnniversarySelection? selectPokemonAnniversaryArt(
  int nationalId, {
  String? nameEn,
  int? spriteResourceId,
}) {
  final arts = pokemonAnniversaryArts(nationalId);
  if (arts.isEmpty) return null;
  final slug = (nameEn ?? '').toLowerCase().replaceAll(RegExp(r'[ _]+'), '-');
  final exactFile = pokemonAnniversaryFileByFormKey[slug];
  final exactMatches = arts.where((art) => art.file == exactFile).toList();
  if (exactMatches.length == 1) {
    return PokemonAnniversarySelection(exactMatches.single, matchesForm: true);
  }
  bool Function(PokemonAnniversaryArt)? match;
  if (slug.endsWith('-mega-x') ||
      slug.endsWith('-mega-y') ||
      slug.endsWith('-mega-z')) {
    final suffix = {'x': 'Ｘ', 'y': 'Ｙ', 'z': 'Ｚ'}[slug[slug.length - 1]]!;
    match = (art) => art.nameJa.startsWith('メガ') && art.nameJa.endsWith(suffix);
  } else if (slug.endsWith('-mega')) {
    match = (art) =>
        art.nameJa.startsWith('メガ') && !RegExp('[ＸＹＺ]').hasMatch(art.nameJa);
  } else if (slug.endsWith('-gmax')) {
    match = (art) => art.formJa == 'キョダイマックスのすがた';
  } else if (slug.endsWith('-alola')) {
    match = (art) => art.formJa == 'アローラのすがた';
  } else if (slug.endsWith('-galar')) {
    match = (art) => art.formJa == 'ガラルのすがた';
  } else if (slug.endsWith('-hisui')) {
    match = (art) => art.formJa == 'ヒスイのすがた';
  } else if (_exactFormNames[slug] case final String officialName) {
    match = (art) => art.formJa == officialName;
  }
  if (match != null) {
    final matched = arts.where(match).toList();
    if (matched.length == 1) {
      return PokemonAnniversarySelection(matched.single, matchesForm: true);
    }
  }
  final base = arts.firstWhere((art) => art.isBase, orElse: () => arts.first);
  // Unknown cosmetic forms may share the base sprite ID. Qualified names
  // remain unmatched even when the image resource is shared with the base.
  return PokemonAnniversarySelection(base, matchesForm: false);
}

const _exactFormNames = <String, String>{
  'rotom': 'ロトムのすがた',
  'rotom-heat': 'ヒートロトム',
  'rotom-wash': 'ウォッシュロトム',
  'rotom-frost': 'フロストロトム',
  'rotom-fan': 'スピンロトム',
  'rotom-mow': 'カットロトム',
  'deoxys-normal': 'ノーマルフォルム',
  'deoxys-attack': 'アタックフォルム',
  'deoxys-defense': 'ディフェンスフォルム',
  'deoxys-speed': 'スピードフォルム',
  'darmanitan-standard': 'ノーマルモード',
  'darmanitan-zen': 'ダルマモード',
  'darmanitan-galar-standard': 'ガラルのすがた',
  'darmanitan-galar-zen': 'ガラルのすがた・ダルマモード',
  'tauros-paldea-combat-breed': 'パルデアのすがた・コンバットしゅ',
  'tauros-paldea-blaze-breed': 'パルデアのすがた・ブレイズしゅ',
  'tauros-paldea-aqua-breed': 'パルデアのすがた・ウォーターしゅ',
  'basculin-red-striped': 'あかすじのすがた',
  'basculin-blue-striped': 'あおすじのすがた',
  'basculin-white-striped': 'しろすじのすがた',
  'oricorio-baile': 'めらめらスタイル',
  'oricorio-pom-pom': 'ぱちぱちスタイル',
  'oricorio-pau': 'ふらふらスタイル',
  'oricorio-sensu': 'まいまいスタイル',
};

const _formLabels = <String, String>{
  'キョダイマックスのすがた': '超极巨化',
  'アローラのすがた': '阿罗拉的样子',
  'ガラルのすがた': '伽勒尔的样子',
  'ヒスイのすがた': '洗翠的样子',
  'パルデアのすがた・コンバットしゅ': '帕底亚的样子 · 斗战种',
  'パルデアのすがた・ブレイズしゅ': '帕底亚的样子 · 火炽种',
  'パルデアのすがた・ウォーターしゅ': '帕底亚的样子 · 水澜种',
  'ロトムのすがた': '洛托姆的样子',
  'ヒートロトム': '加热洛托姆',
  'ウォッシュロトム': '清洗洛托姆',
  'フロストロトム': '结冰洛托姆',
  'スピンロトム': '旋转洛托姆',
  'カットロトム': '切割洛托姆',
  'ノーマルフォルム': '普通形态',
  'アタックフォルム': '攻击形态',
  'ディフェンスフォルム': '防御形态',
  'スピードフォルム': '速度形态',
  'ノーマルモード': '普通模式',
  'ダルマモード': '达摩模式',
  'ガラルのすがた・ダルマモード': '伽勒尔的样子 · 达摩模式',
  'あかすじのすがた': '红条纹的样子',
  'あおすじのすがた': '蓝条纹的样子',
  'しろすじのすがた': '白条纹的样子',
  'めらめらスタイル': '热辣热辣风格',
  'ぱちぱちスタイル': '啪滋啪滋风格',
  'ふらふらスタイル': '呼拉呼拉风格',
  'まいまいスタイル': '轻盈轻盈风格',
};
