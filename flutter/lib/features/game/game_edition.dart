import '../dex/dex_game_scope.dart';

/// Canonical game edition for home / dex / detail / battle tools (23 games).
class GameEdition {
  const GameEdition({
    required this.slug,
    required this.labelZh,
    required this.versionGroup,
    required this.hasPokeApiData,
    required this.fallbackSlug,
    required this.defaultRegionalPokedex,
    this.journeyGameKey,
  });

  final String slug;
  final String labelZh;

  /// PokeAPI version-group key; null for editions without API data (LZA, Champions).
  final String? versionGroup;
  final bool hasPokeApiData;
  final String fallbackSlug;
  final DexRegionalPokedex defaultRegionalPokedex;

  /// Journey save `game` field key (e.g. SoulSilver for HGSS).
  final String? journeyGameKey;

  /// Move-set / obtain-locations lookup key (falls back to [fallbackSlug] edition).
  String get dataVersionGroupKey {
    if (versionGroup != null) {
      return versionGroup!;
    }
    final fallback = gameEditionFromSlug(fallbackSlug);
    return fallback?.versionGroup ?? fallbackSlug;
  }

  /// National dex generation (1–9) for default sprite / battle scope display.
  int get generation => switch (dataVersionGroupKey) {
    'red-blue' || 'yellow' => 1,
    'gold-silver' || 'crystal' => 2,
    'ruby-sapphire' || 'emerald' || 'firered-leafgreen' => 3,
    'diamond-pearl' || 'platinum' || 'heartgold-soulsilver' => 4,
    'black-white' || 'black-2-white-2' => 5,
    'x-y' || 'omega-ruby-alpha-sapphire' => 6,
    'sun-moon' ||
    'ultra-sun-ultra-moon' ||
    'lets-go-pikachu-lets-go-eevee' => 7,
    'sword-shield' ||
    'brilliant-diamond-shining-pearl' ||
    'legends-arceus' => 8,
    _ => 9,
  };

  /// PokeAPI version-group key used for in-game dex sprites.
  String get spriteVersionGroup => dataVersionGroupKey;

  String? get iconUrl {
    final key = versionGroup ?? fallbackSlug;
    return 'https://dex.tito.cafe/v3/game_icons/$key.png';
  }

  static const GameEdition hgss = GameEdition(
    slug: 'hgss',
    labelZh: '心金/魂银 (HGSS)',
    versionGroup: 'heartgold-soulsilver',
    hasPokeApiData: true,
    fallbackSlug: 'hgss',
    defaultRegionalPokedex: DexRegionalPokedex.johto,
    journeyGameKey: 'SoulSilver',
  );

  static final List<GameEdition> all = [
    const GameEdition(
      slug: 'rgb',
      labelZh: '红/绿/蓝 (RGB)',
      versionGroup: 'red-blue',
      hasPokeApiData: true,
      fallbackSlug: 'rgb',
      defaultRegionalPokedex: DexRegionalPokedex.kanto,
    ),
    const GameEdition(
      slug: 'yellow',
      labelZh: '皮卡丘 (Y)',
      versionGroup: 'yellow',
      hasPokeApiData: true,
      fallbackSlug: 'yellow',
      defaultRegionalPokedex: DexRegionalPokedex.kanto,
    ),
    const GameEdition(
      slug: 'gs',
      labelZh: '金/银 (GS)',
      versionGroup: 'gold-silver',
      hasPokeApiData: true,
      fallbackSlug: 'gs',
      defaultRegionalPokedex: DexRegionalPokedex.johto,
    ),
    const GameEdition(
      slug: 'crystal',
      labelZh: '水晶 (C)',
      versionGroup: 'crystal',
      hasPokeApiData: true,
      fallbackSlug: 'crystal',
      defaultRegionalPokedex: DexRegionalPokedex.johto,
    ),
    const GameEdition(
      slug: 'rs',
      labelZh: '红宝石/蓝宝石 (RS)',
      versionGroup: 'ruby-sapphire',
      hasPokeApiData: true,
      fallbackSlug: 'rs',
      defaultRegionalPokedex: DexRegionalPokedex.hoenn,
    ),
    const GameEdition(
      slug: 'emerald',
      labelZh: '绿宝石 (E)',
      versionGroup: 'emerald',
      hasPokeApiData: true,
      fallbackSlug: 'emerald',
      defaultRegionalPokedex: DexRegionalPokedex.hoenn,
    ),
    const GameEdition(
      slug: 'frlg',
      labelZh: '火红/叶绿 (FRLG)',
      versionGroup: 'firered-leafgreen',
      hasPokeApiData: true,
      fallbackSlug: 'frlg',
      defaultRegionalPokedex: DexRegionalPokedex.kanto,
    ),
    const GameEdition(
      slug: 'dp',
      labelZh: '钻石/珍珠 (DP)',
      versionGroup: 'diamond-pearl',
      hasPokeApiData: true,
      fallbackSlug: 'dp',
      defaultRegionalPokedex: DexRegionalPokedex.sinnoh,
    ),
    const GameEdition(
      slug: 'pt',
      labelZh: '白金 (Pt)',
      versionGroup: 'platinum',
      hasPokeApiData: true,
      fallbackSlug: 'pt',
      defaultRegionalPokedex: DexRegionalPokedex.sinnoh,
      journeyGameKey: 'Platinum',
    ),
    hgss,
    const GameEdition(
      slug: 'bw',
      labelZh: '黑/白 (BW)',
      versionGroup: 'black-white',
      hasPokeApiData: true,
      fallbackSlug: 'bw',
      defaultRegionalPokedex: DexRegionalPokedex.unova,
      journeyGameKey: 'BlackWhite',
    ),
    const GameEdition(
      slug: 'bw2',
      labelZh: '黑2/白2 (BW2)',
      versionGroup: 'black-2-white-2',
      hasPokeApiData: true,
      fallbackSlug: 'bw2',
      defaultRegionalPokedex: DexRegionalPokedex.unova,
      journeyGameKey: 'Black2White2',
    ),
    const GameEdition(
      slug: 'xy',
      labelZh: 'X/Y (XY)',
      versionGroup: 'x-y',
      hasPokeApiData: true,
      fallbackSlug: 'xy',
      defaultRegionalPokedex: DexRegionalPokedex.kalos,
      journeyGameKey: 'XY',
    ),
    const GameEdition(
      slug: 'oras',
      labelZh: '欧米加红宝石/阿尔法蓝宝石 (ORAS)',
      versionGroup: 'omega-ruby-alpha-sapphire',
      hasPokeApiData: true,
      fallbackSlug: 'oras',
      defaultRegionalPokedex: DexRegionalPokedex.hoenn,
      journeyGameKey: 'ORAS',
    ),
    const GameEdition(
      slug: 'sm',
      labelZh: '太阳/月亮 (SM)',
      versionGroup: 'sun-moon',
      hasPokeApiData: true,
      fallbackSlug: 'sm',
      defaultRegionalPokedex: DexRegionalPokedex.alola,
    ),
    const GameEdition(
      slug: 'usum',
      labelZh: '究极之日/月 (USUM)',
      versionGroup: 'ultra-sun-ultra-moon',
      hasPokeApiData: true,
      fallbackSlug: 'usum',
      defaultRegionalPokedex: DexRegionalPokedex.alola,
      journeyGameKey: 'USUM',
    ),
    const GameEdition(
      slug: 'lgpe',
      labelZh: "Let's Go 皮卡丘/伊布 (LGPE)",
      versionGroup: 'lets-go-pikachu-lets-go-eevee',
      hasPokeApiData: true,
      fallbackSlug: 'lgpe',
      defaultRegionalPokedex: DexRegionalPokedex.kanto,
    ),
    const GameEdition(
      slug: 'swsh',
      labelZh: '剑/盾 (SWSH)',
      versionGroup: 'sword-shield',
      hasPokeApiData: true,
      fallbackSlug: 'swsh',
      defaultRegionalPokedex: DexRegionalPokedex.galar,
    ),
    const GameEdition(
      slug: 'bdsp',
      labelZh: '晶灿钻石/明亮珍珠 (BDSP)',
      versionGroup: 'brilliant-diamond-shining-pearl',
      hasPokeApiData: true,
      fallbackSlug: 'dp',
      defaultRegionalPokedex: DexRegionalPokedex.sinnoh,
    ),
    const GameEdition(
      slug: 'pla',
      labelZh: '传说阿尔宙斯 (LA)',
      versionGroup: 'legends-arceus',
      hasPokeApiData: true,
      fallbackSlug: 'pla',
      defaultRegionalPokedex: DexRegionalPokedex.hisui,
    ),
    const GameEdition(
      slug: 'sv',
      labelZh: '朱/紫 (SV)',
      versionGroup: 'scarlet-violet',
      hasPokeApiData: true,
      fallbackSlug: 'sv',
      defaultRegionalPokedex: DexRegionalPokedex.paldea,
    ),
    const GameEdition(
      slug: 'lza',
      labelZh: '传说 Z-A (LZA)',
      versionGroup: null,
      hasPokeApiData: false,
      fallbackSlug: 'sv',
      defaultRegionalPokedex: DexRegionalPokedex.paldea,
    ),
    const GameEdition(
      slug: 'champions',
      labelZh: 'Champions',
      versionGroup: null,
      hasPokeApiData: false,
      fallbackSlug: 'sv',
      defaultRegionalPokedex: DexRegionalPokedex.national,
    ),
  ];
}

const defaultGameEdition = GameEdition.hgss;

GameEdition? gameEditionFromSlug(String? slug) {
  if (slug == null || slug.isEmpty) {
    return null;
  }
  for (final edition in GameEdition.all) {
    if (edition.slug == slug) {
      return edition;
    }
  }
  return null;
}

GameEdition gameEditionFromJourneyGame(String? journeyGame) {
  if (journeyGame == null || journeyGame.isEmpty) {
    return defaultGameEdition;
  }
  for (final edition in GameEdition.all) {
    if (edition.journeyGameKey == journeyGame) {
      return edition;
    }
  }
  final legacySlug = switch (journeyGame) {
    'RedBlueYellow' => 'rgb',
    'GoldSilver' => 'gs',
    'Crystal' => 'crystal',
    'RubySapphire' => 'rs',
    'Emerald' => 'emerald',
    'FireRedLeafGreen' => 'frlg',
    'Diamond' || 'Pearl' || 'DiamondPearl' => 'dp',
    'Platinum' => 'pt',
    'HeartGold' => 'hgss',
    'White' || 'Black' || 'BlackWhite' => 'bw',
    'White2' || 'Black2' => 'bw2',
    'X' || 'Y' => 'xy',
    'AlphaSapphire' || 'OmegaRuby' => 'oras',
    'Sun' || 'Moon' || 'SunMoon' => 'sm',
    'UltraSun' || 'UltraMoon' => 'usum',
    _ => null,
  };
  final legacyEdition = gameEditionFromSlug(legacySlug);
  if (legacyEdition != null) return legacyEdition;
  return defaultGameEdition;
}

String gameEditionLabelZh(GameEdition edition) => edition.labelZh;

String gameEditionLabelForVersionGroup(String versionGroupKey) {
  for (final edition in GameEdition.all) {
    if (edition.dataVersionGroupKey == versionGroupKey ||
        edition.versionGroup == versionGroupKey) {
      return edition.labelZh;
    }
  }
  return versionGroupKey;
}

String gameEditionMoveSetKey(GameEdition edition) =>
    edition.dataVersionGroupKey;
