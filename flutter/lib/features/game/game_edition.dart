import 'dart:ui' show Color;

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
    this.flavorVersions = const [],
    this.selectedFlavor,
  });

  final String slug;
  final String labelZh;

  /// PokeAPI version-group key; null for editions without API data (LZA, Champions).
  final String? versionGroup;
  final bool hasPokeApiData;
  final String fallbackSlug;
  final DexRegionalPokedex defaultRegionalPokedex;

  /// Sub-versions that share the same [versionGroup] (e.g. scarlet/violet).
  /// Empty when the edition has only one flavor.
  final List<String> flavorVersions;

  /// Currently preferred sub-version, or null to use the merged edition.
  final String? selectedFlavor;

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

  /// Whether this edition has sub-versions to choose from.
  bool get hasFlavorVersions => flavorVersions.length > 1;

  /// A copy with the preferred sub-version selected (or null for merged).
  GameEdition withFlavor(String? flavor) {
    if (flavor == selectedFlavor) {
      return this;
    }
    return GameEdition(
      slug: slug,
      labelZh: labelZh,
      versionGroup: versionGroup,
      hasPokeApiData: hasPokeApiData,
      fallbackSlug: fallbackSlug,
      defaultRegionalPokedex: defaultRegionalPokedex,
      journeyGameKey: journeyGameKey,
      flavorVersions: flavorVersions,
      selectedFlavor: flavor,
    );
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

  /// Bundled official Pokémon HOME game icon — only Gen VI+ titles have
  /// square per-game icons (Nintendo never drew them for older games), so
  /// earlier editions fall back to a version-tinted letter badge. Bundled in
  /// the APK on purpose: 11 files ≈ 88 KB, no CDN round trip.
  String? get iconAsset => switch (slug) {
    'xy' ||
    'oras' ||
    'sm' ||
    'usum' ||
    'lgpe' ||
    'swsh' ||
    'bdsp' ||
    'pla' ||
    'sv' ||
    'lza' ||
    'champions' => 'assets/game_icons/$slug.png',
    _ => null,
  };

  /// Representative version color for the letter-badge fallback.
  Color get accentColor => switch (slug) {
    'rgb' => const Color(0xFFE3350D),
    'yellow' => const Color(0xFFF2C63A),
    'gs' => const Color(0xFFC9A548),
    'crystal' => const Color(0xFF6FC7D8),
    'rs' => const Color(0xFFB63A2F),
    'emerald' => const Color(0xFF2FA05C),
    'frlg' => const Color(0xFFE8703A),
    'dp' => const Color(0xFF6C93C4),
    'pt' => const Color(0xFF8E8E9E),
    'hgss' => const Color(0xFFD1A62C),
    'bw' => const Color(0xFF4A4A55),
    'bw2' => const Color(0xFF3D7A99),
    _ => const Color(0xFF7B91A6),
  };

  static const GameEdition hgss = GameEdition(
    slug: 'hgss',
    labelZh: '心金/魂银 (HGSS)',
    versionGroup: 'heartgold-soulsilver',
    hasPokeApiData: true,
    fallbackSlug: 'hgss',
    defaultRegionalPokedex: DexRegionalPokedex.johto,
    flavorVersions: ['heartgold', 'soulsilver'],
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
      flavorVersions: ['red', 'blue'],
    ),
    const GameEdition(
      slug: 'yellow',
      labelZh: '皮卡丘 (Y)',
      versionGroup: 'yellow',
      hasPokeApiData: true,
      fallbackSlug: 'yellow',
      defaultRegionalPokedex: DexRegionalPokedex.kanto,
      flavorVersions: ['yellow'],
    ),
    const GameEdition(
      slug: 'gs',
      labelZh: '金/银 (GS)',
      versionGroup: 'gold-silver',
      hasPokeApiData: true,
      fallbackSlug: 'gs',
      defaultRegionalPokedex: DexRegionalPokedex.johto,
      flavorVersions: ['gold', 'silver'],
    ),
    const GameEdition(
      slug: 'crystal',
      labelZh: '水晶 (C)',
      versionGroup: 'crystal',
      hasPokeApiData: true,
      fallbackSlug: 'crystal',
      defaultRegionalPokedex: DexRegionalPokedex.johto,
      flavorVersions: ['crystal'],
    ),
    const GameEdition(
      slug: 'rs',
      labelZh: '红宝石/蓝宝石 (RS)',
      versionGroup: 'ruby-sapphire',
      hasPokeApiData: true,
      fallbackSlug: 'rs',
      defaultRegionalPokedex: DexRegionalPokedex.hoenn,
      flavorVersions: ['ruby', 'sapphire'],
    ),
    const GameEdition(
      slug: 'emerald',
      labelZh: '绿宝石 (E)',
      versionGroup: 'emerald',
      hasPokeApiData: true,
      fallbackSlug: 'emerald',
      defaultRegionalPokedex: DexRegionalPokedex.hoenn,
      flavorVersions: ['emerald'],
    ),
    const GameEdition(
      slug: 'frlg',
      labelZh: '火红/叶绿 (FRLG)',
      versionGroup: 'firered-leafgreen',
      hasPokeApiData: true,
      fallbackSlug: 'frlg',
      defaultRegionalPokedex: DexRegionalPokedex.kanto,
      flavorVersions: ['firered', 'leafgreen'],
    ),
    const GameEdition(
      slug: 'dp',
      labelZh: '钻石/珍珠 (DP)',
      versionGroup: 'diamond-pearl',
      hasPokeApiData: true,
      fallbackSlug: 'dp',
      defaultRegionalPokedex: DexRegionalPokedex.sinnoh,
      flavorVersions: ['diamond', 'pearl'],
    ),
    const GameEdition(
      slug: 'pt',
      labelZh: '白金 (Pt)',
      versionGroup: 'platinum',
      hasPokeApiData: true,
      fallbackSlug: 'pt',
      defaultRegionalPokedex: DexRegionalPokedex.sinnoh,
      flavorVersions: ['platinum'],
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
      flavorVersions: ['black', 'white'],
      journeyGameKey: 'BlackWhite',
    ),
    const GameEdition(
      slug: 'bw2',
      labelZh: '黑2/白2 (BW2)',
      versionGroup: 'black-2-white-2',
      hasPokeApiData: true,
      fallbackSlug: 'bw2',
      defaultRegionalPokedex: DexRegionalPokedex.unova,
      flavorVersions: ['black-2', 'white-2'],
      journeyGameKey: 'Black2White2',
    ),
    const GameEdition(
      slug: 'xy',
      labelZh: 'X/Y (XY)',
      versionGroup: 'x-y',
      hasPokeApiData: true,
      fallbackSlug: 'xy',
      defaultRegionalPokedex: DexRegionalPokedex.kalos,
      flavorVersions: ['x', 'y'],
      journeyGameKey: 'XY',
    ),
    const GameEdition(
      slug: 'oras',
      labelZh: '欧米加红宝石/阿尔法蓝宝石 (ORAS)',
      versionGroup: 'omega-ruby-alpha-sapphire',
      hasPokeApiData: true,
      fallbackSlug: 'oras',
      defaultRegionalPokedex: DexRegionalPokedex.hoenn,
      flavorVersions: ['omega-ruby', 'alpha-sapphire'],
      journeyGameKey: 'ORAS',
    ),
    const GameEdition(
      slug: 'sm',
      labelZh: '太阳/月亮 (SM)',
      versionGroup: 'sun-moon',
      hasPokeApiData: true,
      fallbackSlug: 'sm',
      defaultRegionalPokedex: DexRegionalPokedex.alola,
      flavorVersions: ['sun', 'moon'],
    ),
    const GameEdition(
      slug: 'usum',
      labelZh: '究极之日/月 (USUM)',
      versionGroup: 'ultra-sun-ultra-moon',
      hasPokeApiData: true,
      fallbackSlug: 'usum',
      defaultRegionalPokedex: DexRegionalPokedex.alola,
      flavorVersions: ['ultra-sun', 'ultra-moon'],
      journeyGameKey: 'USUM',
    ),
    const GameEdition(
      slug: 'lgpe',
      labelZh: "Let's Go 皮卡丘/伊布 (LGPE)",
      versionGroup: 'lets-go-pikachu-lets-go-eevee',
      hasPokeApiData: true,
      fallbackSlug: 'lgpe',
      defaultRegionalPokedex: DexRegionalPokedex.kanto,
      flavorVersions: ['lets-go-pikachu', 'lets-go-eevee'],
    ),
    const GameEdition(
      slug: 'swsh',
      labelZh: '剑/盾 (SWSH)',
      versionGroup: 'sword-shield',
      hasPokeApiData: true,
      fallbackSlug: 'swsh',
      defaultRegionalPokedex: DexRegionalPokedex.galar,
      flavorVersions: ['sword', 'shield'],
    ),
    const GameEdition(
      slug: 'bdsp',
      labelZh: '晶灿钻石/明亮珍珠 (BDSP)',
      versionGroup: 'brilliant-diamond-shining-pearl',
      hasPokeApiData: true,
      fallbackSlug: 'dp',
      defaultRegionalPokedex: DexRegionalPokedex.sinnoh,
      flavorVersions: ['brilliant-diamond', 'shining-pearl'],
    ),
    const GameEdition(
      slug: 'pla',
      labelZh: '传说阿尔宙斯 (LA)',
      versionGroup: 'legends-arceus',
      hasPokeApiData: true,
      fallbackSlug: 'pla',
      defaultRegionalPokedex: DexRegionalPokedex.hisui,
      flavorVersions: ['legends-arceus'],
    ),
    const GameEdition(
      slug: 'sv',
      labelZh: '朱/紫 (SV)',
      versionGroup: 'scarlet-violet',
      hasPokeApiData: true,
      fallbackSlug: 'sv',
      defaultRegionalPokedex: DexRegionalPokedex.paldea,
      flavorVersions: ['scarlet', 'violet'],
    ),
    const GameEdition(
      slug: 'lza',
      labelZh: '传说 Z-A (LZA)',
      versionGroup: 'legends-za',
      hasPokeApiData: true,
      fallbackSlug: 'sv',
      defaultRegionalPokedex: DexRegionalPokedex.kalos,
      flavorVersions: ['legends-za', 'mega-dimension'],
    ),
    const GameEdition(
      slug: 'champions',
      labelZh: 'Champions',
      versionGroup: 'champions',
      hasPokeApiData: true,
      fallbackSlug: 'sv',
      defaultRegionalPokedex: DexRegionalPokedex.national,
      flavorVersions: ['champions'],
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
