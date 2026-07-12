/// Dex browse scope: game version + regional pokedex filter.
library;

import '../../models/journey.dart';
import '../game/game_edition.dart';
import 'dex_game_scope.dart';
import 'dex_models.dart';

/// Legacy adapter over [GameEdition] for tests and gradual migration.
enum DexGameVersion {
  hgss,
  dppt,
  bw,
  xy,
  sm,
  swsh,
  sv,
  pla;

  GameEdition get edition => switch (this) {
        DexGameVersion.hgss => GameEdition.hgss,
        DexGameVersion.dppt => gameEditionFromSlug('pt')!,
        DexGameVersion.bw => gameEditionFromSlug('bw')!,
        DexGameVersion.xy => gameEditionFromSlug('xy')!,
        DexGameVersion.sm => gameEditionFromSlug('sm')!,
        DexGameVersion.swsh => gameEditionFromSlug('swsh')!,
        DexGameVersion.sv => gameEditionFromSlug('sv')!,
        DexGameVersion.pla => gameEditionFromSlug('pla')!,
      };

  String get versionGroup => edition.dataVersionGroupKey;
  String get labelZh => edition.labelZh;

  static DexGameVersion? fromStorageKey(String? key) {
    if (key == null) {
      return null;
    }
    for (final version in DexGameVersion.values) {
      if (version.name == key) {
        return version;
      }
    }
    final edition = gameEditionFromSlug(key);
    return edition == null ? null : fromGameEdition(edition);
  }

  static DexGameVersion fromGameEdition(GameEdition edition) {
    for (final version in DexGameVersion.values) {
      if (version.edition.slug == edition.slug) {
        return version;
      }
    }
    return DexGameVersion.hgss;
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
    this.gameEdition = defaultGameEdition,
    this.regionalScope = DexRegionalPokedex.national,
  });

  final GameEdition gameEdition;
  final DexRegionalPokedex regionalScope;

  /// Legacy alias used by early Phase E wiring.
  DexGameVersion get gameVersion => DexGameVersion.fromGameEdition(gameEdition);

  /// Legacy alias used by early Phase E wiring.
  GameEdition get game => gameEdition;

  /// Legacy alias mapped to the closest HGSS regional scope enum.
  DexRegionalScope get region => regionalScopeFromPokedex(regionalScope);

  String get label => '${gameEdition.labelZh} · ${regionalScope.labelZh}';

  (int, int) get idRange => idRangeForScope(
        regionalScope,
        gameEdition: gameEdition,
      );

  DexScope copyWith({
    GameEdition? gameEdition,
    DexRegionalPokedex? regionalScope,
  }) {
    return DexScope(
      gameEdition: gameEdition ?? this.gameEdition,
      regionalScope: regionalScope ?? this.regionalScope,
    );
  }

  static DexScope defaultForJourney(CurrentJourney journey) {
    return DexScope(
      gameEdition: gameEditionFromJourneyGame(journey.game),
      regionalScope: gameEditionFromJourneyGame(journey.game)
          .defaultRegionalPokedex,
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
    if (gameEdition.slug != GameEdition.hgss.slug) {
      return false;
    }
    final (start, end) = _hgssRegionalNationalRange(regionalScope);
    if (start == null || end == null) {
      return false;
    }
    return id >= start && id <= end;
  }

  int? _hgssNationalFallbackRegionalNumber(int id) {
    if (gameEdition.slug != GameEdition.hgss.slug) {
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
    GameEdition gameEdition = defaultGameEdition,
  }) {
    if (scope == DexRegionalPokedex.national) {
      return (1, titodexMaxNationalDexId);
    }

    if (gameEdition.slug == GameEdition.hgss.slug) {
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

bool summaryMatchesRegionalPokedex(
  PokemonSummary summary,
  DexRegionalPokedex scope,
) {
  return DexScope(regionalScope: scope).speciesInScope(summary);
}

bool summaryMatchesDexScope(PokemonSummary summary, DexScope scope) =>
    scope.speciesInScope(summary);
