/// Dex browse scope: game version + regional pokedex filter.
library;

import '../../models/journey.dart';
import 'dex_game_scope.dart';
import 'dex_models.dart';

/// Supported game-version scopes for move sets and dex browse defaults.
enum DexGameVersion {
  hgss('heartgold-soulsilver', '心金·魂银'),
  dppt('diamond-pearl-platinum', '钻石·珍珠·白金'),
  bw('black-white', '黑·白'),
  xy('x-y', 'X·Y'),
  sm('sun-moon', '太阳·月亮'),
  swsh('sword-shield', '剑·盾'),
  sv('scarlet-violet', '朱·紫'),
  pla('legends-arceus', '传说阿尔宙斯');

  const DexGameVersion(this.versionGroup, this.labelZh);

  final String versionGroup;
  final String labelZh;

  static DexGameVersion? fromStorageKey(String? key) {
    if (key == null) {
      return null;
    }
    for (final version in DexGameVersion.values) {
      if (version.name == key) {
        return version;
      }
    }
    return null;
  }
}

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

DexRegionalPokedex regionalPokedexFromScope(DexRegionalScope scope) {
  return switch (scope) {
    DexRegionalScope.national => DexRegionalPokedex.national,
    DexRegionalScope.johto => DexRegionalPokedex.johto,
    DexRegionalScope.kanto => DexRegionalPokedex.kanto,
  };
}

DexRegionalScope regionalScopeFromPokedex(DexRegionalPokedex scope) {
  return switch (scope) {
    DexRegionalPokedex.national => DexRegionalScope.national,
    DexRegionalPokedex.johto => DexRegionalScope.johto,
    DexRegionalPokedex.kanto => DexRegionalScope.kanto,
    _ => DexRegionalScope.national,
  };
}

String gameVersionLabelZh(DexGameVersion version) => version.labelZh;

String gameVersionMoveSetKey(DexGameVersion version) => version.versionGroup;

/// Combined browse scope for the dex list.
class DexScope {
  const DexScope({
    this.gameVersion = DexGameVersion.hgss,
    this.regionalScope = DexRegionalPokedex.national,
  });

  final DexGameVersion gameVersion;
  final DexRegionalPokedex regionalScope;

  /// Legacy alias used by early Phase E wiring.
  DexGameVersion get game => gameVersion;

  /// Legacy alias mapped to the closest HGSS regional scope enum.
  DexRegionalScope get region => regionalScopeFromPokedex(regionalScope);

  String get label => '${gameVersion.labelZh} · ${regionalScope.labelZh}';

  (int, int) get idRange => idRangeForScope(
        regionalScope,
        gameVersion: gameVersion,
      );

  DexScope copyWith({
    DexGameVersion? gameVersion,
    DexRegionalPokedex? regionalScope,
  }) {
    return DexScope(
      gameVersion: gameVersion ?? this.gameVersion,
      regionalScope: regionalScope ?? this.regionalScope,
    );
  }

  static DexScope defaultForJourney(CurrentJourney journey) {
    return const DexScope(
      gameVersion: DexGameVersion.hgss,
      regionalScope: DexRegionalPokedex.national,
    );
  }

  int? regionalNumberFor(PokemonSummary summary) {
    if (regionalScope == DexRegionalPokedex.national) {
      return summary.id;
    }

    final numbers = summary.pokedexNumbers;
    if (numbers != null) {
      for (final key in regionalScope.pokedexKeys) {
        final value = numbers[key];
        if (value != null) {
          return value;
        }
      }
    }

    return _hgssNationalFallbackRegionalNumber(summary.id);
  }

  bool speciesInScope(PokemonSummary summary) {
    if (regionalScope == DexRegionalPokedex.national) {
      return summary.id >= 1 && summary.id <= titodexMaxNationalDexId;
    }

    final numbers = summary.pokedexNumbers;
    if (numbers != null) {
      for (final key in regionalScope.pokedexKeys) {
        if (numbers.containsKey(key)) {
          return true;
        }
      }
    }

    return _matchesHgssNationalFallback(summary.id);
  }

  bool _matchesHgssNationalFallback(int id) {
    if (gameVersion != DexGameVersion.hgss) {
      return false;
    }
    final (start, end) = _hgssRegionalNationalRange(regionalScope);
    if (start == null || end == null) {
      return false;
    }
    return id >= start && id <= end;
  }

  int? _hgssNationalFallbackRegionalNumber(int id) {
    if (gameVersion != DexGameVersion.hgss) {
      return null;
    }
    final (start, end) = _hgssRegionalNationalRange(regionalScope);
    if (start == null || end == null || id < start || id > end) {
      return null;
    }
    return switch (regionalScope) {
      DexRegionalPokedex.kanto => id,
      DexRegionalPokedex.johto => id - 151,
      _ => null,
    };
  }

  static (int, int) idRangeForScope(
    DexRegionalPokedex scope, {
    DexGameVersion gameVersion = DexGameVersion.hgss,
  }) {
    if (scope == DexRegionalPokedex.national) {
      return (1, titodexMaxNationalDexId);
    }

    if (gameVersion == DexGameVersion.hgss) {
      final hgssRange = _hgssRegionalNationalRange(scope);
      if (hgssRange.$1 != null && hgssRange.$2 != null) {
        return (hgssRange.$1!, hgssRange.$2!);
      }
    }

    // Regional dexes without hardcoded national ranges are filtered via
    // `pokedexNumbers`; expose the full browse range for chunk loading.
    return (1, titodexMaxNationalDexId);
  }
}

(int?, int?) _hgssRegionalNationalRange(DexRegionalPokedex scope) {
  return switch (scope) {
    DexRegionalPokedex.kanto => (1, 151),
    DexRegionalPokedex.johto => (152, 251),
    _ => (null, null),
  };
}

(int, int) nationalDexIdRangeForScope(DexScope scope) => scope.idRange;

bool summaryMatchesRegionalScope(
  PokemonSummary summary,
  DexRegionalScope scope,
) {
  return DexScope(
    regionalScope: regionalPokedexFromScope(scope),
  ).speciesInScope(summary);
}

bool summaryMatchesDexScope(PokemonSummary summary, DexScope scope) =>
    scope.speciesInScope(summary);
