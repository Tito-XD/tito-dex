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

  /// Exact display name when the user selected one side of a paired release.
  String get selectedLabelZh =>
      selectedFlavor == null ? labelZh : flavorVersionLabelZh(selectedFlavor!);

  /// Journey/save key matching the selected side of a paired release.
  ///
  /// [journeyGameKey] remains the merged-edition fallback for legacy data.
  String? get selectedJourneyGameKey => switch (selectedFlavor) {
    'diamond' => 'Diamond',
    'pearl' => 'Pearl',
    'heartgold' => 'HeartGold',
    'soulsilver' => 'SoulSilver',
    'black' => 'Black',
    'white' => 'White',
    'black-2' => 'Black2',
    'white-2' => 'White2',
    'x' => 'X',
    'y' => 'Y',
    'omega-ruby' => 'OmegaRuby',
    'alpha-sapphire' => 'AlphaSapphire',
    'sun' => 'Sun',
    'moon' => 'Moon',
    'ultra-sun' => 'UltraSun',
    'ultra-moon' => 'UltraMoon',
    'sword' => 'sword',
    'shield' => 'shield',
    'brilliant-diamond' => 'brilliant-diamond',
    'shining-pearl' => 'shining-pearl',
    'legends-arceus' => 'legends-arceus',
    'scarlet' => 'scarlet',
    'violet' => 'violet',
    _ => journeyGameKey,
  };

  /// Exact game key accepted by the Journey Assistant contract.
  ///
  /// Paired releases deliberately return null while the merged edition is
  /// selected: choosing a representative side would silently change encounter
  /// and progression facts. Single-version releases can be exact without an
  /// explicit flavor selection.
  String? get assistantGameKey => switch (selectedFlavor) {
    'diamond' => 'diamond',
    'pearl' => 'pearl',
    'heartgold' => 'heartgold',
    'soulsilver' => 'soulsilver',
    'black' => 'black',
    'white' => 'white',
    'black-2' => 'black-2',
    'white-2' => 'white-2',
    'x' => 'x',
    'y' => 'y',
    'omega-ruby' => 'omega-ruby',
    'alpha-sapphire' => 'alpha-sapphire',
    'sun' => 'sun',
    'moon' => 'moon',
    'ultra-sun' => 'ultra-sun',
    'ultra-moon' => 'ultra-moon',
    'sword' => 'sword',
    'shield' => 'shield',
    'brilliant-diamond' => 'brilliant-diamond',
    'shining-pearl' => 'shining-pearl',
    'legends-arceus' => 'legends-arceus',
    'scarlet' => 'scarlet',
    'violet' => 'violet',
    _ => switch (slug) {
      'pt' => 'platinum',
      'pla' => 'legends-arceus',
      _ => null,
    },
  };

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

  /// Bundled game icon — Gen VI+ titles use their Pokémon HOME game icon,
  /// Gen I–V titles use the DS/3DS launch icon (via SteamGridDB), and the two
  /// versions with no official icon (white-2, mega-dimension) use a Pokémon
  /// artwork badge. Every flavor owns `<flavor>.png`; merged edition slugs
  /// show the primary flavor's art. Bundled in the APK so there is no CDN
  /// round trip.
  ///
  /// When a [selectedFlavor] is set, the matching per-flavor icon is used so
  /// X/Y, Sword/Shield, etc. show distinct art in the flavor picker.
  String? get iconAsset {
    final flavor = selectedFlavor;
    if (flavor != null) {
      return 'assets/game_icons/$flavor.png';
    }
    return switch (slug) {
      // Older merged editions have no slug file of their own — show the
      // primary flavor's icon for a consistent look.
      'rgb' => 'assets/game_icons/red.png',
      'gs' => 'assets/game_icons/gold.png',
      'rs' => 'assets/game_icons/ruby.png',
      'frlg' => 'assets/game_icons/firered.png',
      'dp' => 'assets/game_icons/diamond.png',
      'hgss' => 'assets/game_icons/heartgold.png',
      'bw' => 'assets/game_icons/black.png',
      'bw2' => 'assets/game_icons/black-2.png',
      'yellow' => 'assets/game_icons/yellow.png',
      'crystal' => 'assets/game_icons/crystal.png',
      'emerald' => 'assets/game_icons/emerald.png',
      'pt' => 'assets/game_icons/platinum.png',
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
  }

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

/// Maps a parsed save `game` name (`ParsedSaveSummary.game`) to the edition —
/// with the matching flavor when the save pins down a single version — that
/// should be auto-selected after a save import.
///
/// Unlike [gameEditionFromJourneyGame] this returns **null** for unknown
/// names, so callers never override the user's edition on unrecognized saves.
GameEdition? gameEditionForSaveGame(String? saveGame) {
  if (saveGame == null || saveGame.isEmpty) {
    return null;
  }
  final (String? slug, String? flavor) = switch (saveGame) {
    'RedBlueYellow' => ('rgb', null),
    'GoldSilver' => ('gs', null),
    'Crystal' => ('crystal', null),
    'RubySapphire' => ('rs', null),
    'Emerald' => ('emerald', null),
    'FireRedLeafGreen' => ('frlg', null),
    'Diamond' => ('dp', 'diamond'),
    'Pearl' => ('dp', 'pearl'),
    'DiamondPearl' => ('dp', null),
    'Platinum' => ('pt', null),
    'HeartGold' => ('hgss', 'heartgold'),
    'SoulSilver' => ('hgss', 'soulsilver'),
    'Black' => ('bw', 'black'),
    'White' => ('bw', 'white'),
    'BlackWhite' => ('bw', null),
    'Black2' => ('bw2', 'black-2'),
    'White2' => ('bw2', 'white-2'),
    'Black2White2' => ('bw2', null),
    'X' => ('xy', 'x'),
    'Y' => ('xy', 'y'),
    'XY' => ('xy', null),
    'OmegaRuby' => ('oras', 'omega-ruby'),
    'AlphaSapphire' => ('oras', 'alpha-sapphire'),
    'ORAS' => ('oras', null),
    'Sun' => ('sm', 'sun'),
    'Moon' => ('sm', 'moon'),
    'SunMoon' => ('sm', null),
    'UltraSun' => ('usum', 'ultra-sun'),
    'UltraMoon' => ('usum', 'ultra-moon'),
    'USUM' => ('usum', null),
    _ => (null, null),
  };
  final edition = gameEditionFromSlug(slug);
  if (edition == null) {
    return null;
  }
  return flavor == null ? edition : edition.withFlavor(flavor);
}

String gameEditionLabelZh(GameEdition edition) => edition.selectedLabelZh;

/// Stable short code for compact Assistant context UI.
String assistantEditionCode(GameEdition edition) => switch (edition.slug) {
  'rgb' => 'RGB',
  'yellow' => 'Y',
  'gs' => 'GS',
  'crystal' => 'C',
  'rs' => 'RS',
  'emerald' => 'E',
  'frlg' => 'FRLG',
  'dp' => 'DP',
  'pt' => 'Pt',
  'hgss' => 'HGSS',
  'bw' => 'BW',
  'bw2' => 'BW2',
  'xy' => 'XY',
  'oras' => 'ORAS',
  'sm' => 'SM',
  'usum' => 'USUM',
  'lgpe' => 'LGPE',
  'swsh' => 'SWSH',
  'bdsp' => 'BDSP',
  'pla' => 'PLA',
  'sv' => 'SV',
  'lza' => 'LZA',
  'champions' => 'Champions',
  _ => edition.slug.toUpperCase(),
};

/// Human-readable current-version label, e.g. `魂银 · HGSS`.
String assistantEditionDisplayLabel(GameEdition edition) =>
    '${edition.selectedLabelZh} · ${assistantEditionCode(edition)}';

/// Whether save-derived progression belongs to the selected edition.
///
/// A merged selection accepts either side of the same paired release. If both
/// sides are exact, they must agree; a SoulSilver save is not valid context for
/// a manually selected HeartGold journey even though both use the HGSS parser.
bool isSaveEditionCompatible({
  required GameEdition selected,
  required GameEdition save,
}) {
  if (selected.slug != save.slug) return false;
  final selectedFlavor = selected.selectedFlavor;
  final saveFlavor = save.selectedFlavor;
  return selectedFlavor == null ||
      saveFlavor == null ||
      selectedFlavor == saveFlavor;
}

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
