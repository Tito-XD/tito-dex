/// v0.4.0 — Global game edition catalog (23 editions).
///
/// **CDN note:** PokeAPI-backed fields (flavor, moves, obtain) resolve via
/// [versionGroup]. LZA/Champions have no PokeAPI data — UI shows empty state.
/// This file is App-side only; CDN build does not depend on it.
library;

import '../dex/dex_game_scope.dart';
import '../dex/dex_models.dart';
import '../dex/dex_scope.dart';

/// All playable / upcoming game editions for TitoDex v0.4.0.
enum GameEdition {
  rgb('rgb', '红/绿/蓝', 'red-blue', hasPokeApiData: true),
  yellow('yellow', '皮卡丘', 'yellow', hasPokeApiData: true),
  gs('gs', '金/银', 'gold-silver', hasPokeApiData: true),
  crystal('crystal', '水晶', 'crystal', hasPokeApiData: true),
  rs('rs', '红宝石/蓝宝石', 'ruby-sapphire', hasPokeApiData: true),
  emerald('emerald', '绿宝石', 'emerald', hasPokeApiData: true),
  frlg('frlg', '火红/叶绿', 'firered-leafgreen', hasPokeApiData: true),
  dp('dp', '钻石/珍珠', 'diamond-pearl', hasPokeApiData: true),
  pt('pt', '白金', 'platinum', hasPokeApiData: true),
  hgss('hgss', '心金/魂银', 'heartgold-soulsilver', hasPokeApiData: true),
  bw('bw', '黑/白', 'black-white', hasPokeApiData: true),
  bw2('bw2', '黑2/白2', 'black-2-white-2', hasPokeApiData: true),
  xy('xy', 'X/Y', 'x-y', hasPokeApiData: true),
  oras('oras', '欧米加红宝石/阿尔法蓝宝石', 'omega-ruby-alpha-sapphire', hasPokeApiData: true),
  sm('sm', '太阳/月亮', 'sun-moon', hasPokeApiData: true),
  usum('usum', '究极之日/月', 'ultra-sun-ultra-moon', hasPokeApiData: true),
  lgpe('lgpe', "Let's Go 皮卡丘/伊布", 'lets-go-pikachu-lets-go-eevee', hasPokeApiData: true),
  swsh('swsh', '剑/盾', 'sword-shield', hasPokeApiData: true),
  bdsp('bdsp', '晶灿钻石/明亮珍珠', 'brilliant-diamond-shining-pearl', hasPokeApiData: true),
  pla('pla', '传说阿尔宙斯', 'legends-arceus', hasPokeApiData: true),
  sv('sv', '朱/紫', 'scarlet-violet', hasPokeApiData: true),
  lza('lza', '传说 Z-A', null, hasPokeApiData: false),
  champions('champions', 'Champions', null, hasPokeApiData: false);

  const GameEdition(
    this.slug,
    this.labelZh,
    this.versionGroup, {
    required this.hasPokeApiData,
  });

  final String slug;
  final String labelZh;

  /// PokeAPI version-group key for move/obtain/flavor lookups. Null when unavailable.
  final String? versionGroup;
  final bool hasPokeApiData;

  /// CDN game icon path (v3); falls back gracefully when offline.
  String gameIconUrl(String cdnBase) =>
      '$cdnBase/v3/game_icons/$slug.png';

  /// Edition used when this one has sparse or no CDN/PokeAPI data.
  GameEdition get dataFallback => switch (this) {
        GameEdition.bdsp => GameEdition.pt,
        GameEdition.lza => GameEdition.sv,
        GameEdition.champions => GameEdition.sv,
        _ => this,
      };

  /// Resolve move-set / obtain key — uses fallback when primary group is empty.
  String get moveSetKey => versionGroup ?? dataFallback.versionGroup!;

  static GameEdition? fromStorageKey(String? key) {
    if (key == null) {
      return null;
    }
    for (final edition in GameEdition.values) {
      if (edition.name == key || edition.slug == key) {
        return edition;
      }
    }
    // Migrate legacy DexGameVersion storage keys.
    final legacy = DexGameVersion.fromStorageKey(key);
    if (legacy != null) {
      return fromDexGameVersion(legacy);
    }
    return null;
  }

  static GameEdition fromDexGameVersion(DexGameVersion version) {
    return switch (version) {
      DexGameVersion.hgss => GameEdition.hgss,
      DexGameVersion.dppt => GameEdition.pt,
      DexGameVersion.bw => GameEdition.bw,
      DexGameVersion.xy => GameEdition.xy,
      DexGameVersion.sm => GameEdition.sm,
      DexGameVersion.swsh => GameEdition.swsh,
      DexGameVersion.sv => GameEdition.sv,
      DexGameVersion.pla => GameEdition.pla,
    };
  }

  DexGameVersion? toDexGameVersion() {
    return switch (this) {
      GameEdition.hgss => DexGameVersion.hgss,
      GameEdition.pt || GameEdition.dp => DexGameVersion.dppt,
      GameEdition.bw || GameEdition.bw2 => DexGameVersion.bw,
      GameEdition.xy || GameEdition.oras => DexGameVersion.xy,
      GameEdition.sm || GameEdition.usum => DexGameVersion.sm,
      GameEdition.swsh => DexGameVersion.swsh,
      GameEdition.sv => DexGameVersion.sv,
      GameEdition.pla => DexGameVersion.pla,
      _ => null,
    };
  }

  /// Journey save key for home badge compatibility (HGSS journey parsing).
  static GameEdition fromJourneyGameKey(String gameKey) {
    return switch (gameKey) {
      'HeartGold' || 'SoulSilver' => GameEdition.hgss,
      'Platinum' => GameEdition.pt,
      'BlackWhite' => GameEdition.bw,
      'Black2White2' => GameEdition.bw2,
      'XY' => GameEdition.xy,
      'ORAS' => GameEdition.oras,
      'USUM' => GameEdition.usum,
      _ => GameEdition.hgss,
    };
  }

  String get journeyGameKey => switch (this) {
        GameEdition.hgss => 'SoulSilver',
        GameEdition.pt => 'Platinum',
        GameEdition.bw => 'BlackWhite',
        GameEdition.bw2 => 'Black2White2',
        GameEdition.xy => 'XY',
        GameEdition.oras => 'ORAS',
        GameEdition.usum => 'USUM',
        _ => 'SoulSilver',
      };

  String get homeBadgeLabel => switch (this) {
        GameEdition.rgb => 'RGB',
        GameEdition.yellow => 'Y',
        GameEdition.gs => 'GS',
        GameEdition.crystal => 'C',
        GameEdition.rs => 'RS',
        GameEdition.emerald => 'E',
        GameEdition.frlg => 'FRLG',
        GameEdition.dp => 'DP',
        GameEdition.pt => 'Pt',
        GameEdition.hgss => 'HGSS',
        GameEdition.bw => 'B/W',
        GameEdition.bw2 => 'B2W2',
        GameEdition.xy => 'X/Y',
        GameEdition.oras => 'ORAS',
        GameEdition.sm => 'SM',
        GameEdition.usum => 'USUM',
        GameEdition.lgpe => 'LGPE',
        GameEdition.swsh => 'SWSH',
        GameEdition.bdsp => 'BDSP',
        GameEdition.pla => 'LA',
        GameEdition.sv => 'SV',
        GameEdition.lza => 'LZA',
        GameEdition.champions => 'Champions',
      };
}

/// Default regional dex tabs highlighted per edition (v0.4.0 D1).
List<DexRegionalPokedex> defaultRegionsForEdition(GameEdition edition) {
  return switch (edition) {
    GameEdition.rgb ||
    GameEdition.yellow ||
    GameEdition.frlg =>
      const [DexRegionalPokedex.kanto, DexRegionalPokedex.national],
    GameEdition.gs ||
    GameEdition.crystal ||
    GameEdition.hgss =>
      const [
        DexRegionalPokedex.johto,
        DexRegionalPokedex.kanto,
        DexRegionalPokedex.national,
      ],
    GameEdition.rs ||
    GameEdition.emerald ||
    GameEdition.oras =>
      const [DexRegionalPokedex.hoenn, DexRegionalPokedex.national],
    GameEdition.dp ||
    GameEdition.pt ||
    GameEdition.bdsp =>
      const [DexRegionalPokedex.sinnoh, DexRegionalPokedex.national],
    GameEdition.bw || GameEdition.bw2 =>
      const [DexRegionalPokedex.unova, DexRegionalPokedex.national],
    GameEdition.xy =>
      const [DexRegionalPokedex.kalos, DexRegionalPokedex.national],
    GameEdition.sm || GameEdition.usum =>
      const [DexRegionalPokedex.alola, DexRegionalPokedex.national],
    GameEdition.swsh =>
      const [DexRegionalPokedex.galar, DexRegionalPokedex.national],
    GameEdition.pla =>
      const [DexRegionalPokedex.hisui, DexRegionalPokedex.national],
    GameEdition.sv || GameEdition.lza || GameEdition.champions =>
      const [DexRegionalPokedex.paldea, DexRegionalPokedex.national],
    GameEdition.lgpe =>
      const [DexRegionalPokedex.kanto, DexRegionalPokedex.national],
  };
}

/// UI grouping for the 23-item game picker (v0.4.0 B1).
const gameEditionPickerGroups = <String, List<GameEdition>>{
  '第一世代': [GameEdition.rgb, GameEdition.yellow],
  '第二世代': [GameEdition.gs, GameEdition.crystal],
  '第三世代': [GameEdition.rs, GameEdition.emerald, GameEdition.frlg],
  '第四世代': [GameEdition.dp, GameEdition.pt, GameEdition.hgss],
  '第五世代': [GameEdition.bw, GameEdition.bw2],
  '第六世代': [GameEdition.xy, GameEdition.oras],
  '第七世代': [GameEdition.sm, GameEdition.usum, GameEdition.lgpe],
  '第八世代': [GameEdition.swsh, GameEdition.bdsp, GameEdition.pla],
  '第九世代': [GameEdition.sv, GameEdition.lza, GameEdition.champions],
};

// v0.4.0: Edition-scoped detail lookups (exported via dex_models.dart).

/// Obtain locations for [edition], keyed by [GameEdition.moveSetKey] with fallback.
List<ObtainLocationEntry> obtainLocationsForEdition(
  PokemonDetail detail,
  GameEdition edition,
) {
  if (detail.obtainLocationsByGame.isNotEmpty) {
    final primaryKey = edition.moveSetKey;
    final locations = detail.obtainLocationsByGame[primaryKey];
    if (locations != null && locations.isNotEmpty) {
      return locations;
    }
    final fallbackKey = edition.dataFallback.moveSetKey;
    if (fallbackKey != primaryKey) {
      final fallback = detail.obtainLocationsByGame[fallbackKey];
      if (fallback != null && fallback.isNotEmpty) {
        return fallback;
      }
    }
    return const [];
  }

  // v0.4.0: v2 CDN flat obtainLocations — HGSS scope only.
  if (edition == GameEdition.hgss ||
      edition.moveSetKey == hgssVersionGroup) {
    return detail.obtainLocations;
  }
  return const [];
}

/// Flavor entries scoped to [edition] (with data fallback when tagged v3 data).
List<FlavorTextEntry> flavorEntriesForEdition(
  PokemonDetail detail,
  GameEdition edition,
) {
  final all = detail.flavorEntries;
  if (all.isEmpty) {
    return const [];
  }

  final hasEditionTags = all.any((entry) => entry.gameEdition != null);
  if (!hasEditionTags) {
    // v2 CDN: HGSS-era flavor list only.
    if (edition == GameEdition.hgss ||
        edition.moveSetKey == hgssVersionGroup) {
      return all;
    }
    return const [];
  }

  List<FlavorTextEntry> matching(GameEdition target) {
    return all
        .where(
          (entry) =>
              entry.gameEdition == target.slug ||
              entry.version == target.slug,
        )
        .toList(growable: false);
  }

  var matched = matching(edition);
  if (matched.isEmpty && edition != edition.dataFallback) {
    matched = matching(edition.dataFallback);
  }
  return matched;
}

/// Index in [detail.flavorEntries] for carousel default page (current edition).
int flavorEntryDefaultIndex(PokemonDetail detail, GameEdition edition) {
  final entries = detail.flavorEntries;
  if (entries.isEmpty) {
    return 0;
  }

  if (!edition.hasPokeApiData) {
    return 0;
  }

  final hasEditionTags = entries.any((entry) => entry.gameEdition != null);
  if (!hasEditionTags) {
    return 0;
  }

  final slug = edition.slug;
  final idx = entries.indexWhere(
    (entry) => entry.gameEdition == slug || entry.version == slug,
  );
  if (idx >= 0) {
    return idx;
  }

  final fallbackSlug = edition.dataFallback.slug;
  final fallbackIdx = entries.indexWhere(
    (entry) =>
        entry.gameEdition == fallbackSlug || entry.version == fallbackSlug,
  );
  return fallbackIdx >= 0 ? fallbackIdx : 0;
}
