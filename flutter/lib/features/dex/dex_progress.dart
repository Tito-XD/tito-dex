import '../../models/journey.dart';
import '../companion/companion_art.dart';
import '../parser/hgss_format.dart';
import 'dex_game_scope.dart';
import 'dex_models.dart';
import 'dex_scope.dart';

/// Encounter filter for dex list views.
enum DexEncounterFilter {
  all,
  caught,
  seen,
  unseen,
}

/// Aggregated dex progress from save file + journey party.
class DexProgress {
  const DexProgress({
    required this.caughtIds,
    required this.seenIds,
    this.fromSave = false,
  });

  final Set<int> caughtIds;
  final Set<int> seenIds;
  final bool fromSave;

  factory DexProgress.fromJourney(CurrentJourney journey) {
    final caught = journey.saveDexCaughtIds.toSet();
    final seen = journey.saveDexSeenIds.toSet();
    seen.addAll(caught);

    for (final member in journey.party) {
      final id = member.speciesId ??
          speciesIdForName(member.species) ??
          knownSpeciesIdForLabel(member.species);
      if (id != null) {
        caught.add(id);
        seen.add(id);
      }
    }

    final companionId = speciesIdForName(journey.companion) ??
        knownSpeciesIdForLabel(journey.companion);
    if (companionId != null) {
      caught.add(companionId);
      seen.add(companionId);
    }

    return DexProgress(
      caughtIds: caught,
      seenIds: seen,
      fromSave: journey.saveDexCaughtIds.isNotEmpty ||
          journey.saveDexSeenIds.isNotEmpty,
    );
  }

  DexEncounterStatus statusFor(int id) {
    if (caughtIds.contains(id)) {
      return DexEncounterStatus.caught;
    }
    if (seenIds.contains(id)) {
      return DexEncounterStatus.seen;
    }
    return DexEncounterStatus.unknown;
  }

  bool matchesFilter(int id, DexEncounterFilter filter) {
    return switch (filter) {
      DexEncounterFilter.all => true,
      DexEncounterFilter.caught => caughtIds.contains(id),
      DexEncounterFilter.seen => seenIds.contains(id),
      DexEncounterFilter.unseen => !seenIds.contains(id),
    };
  }

  /// v0.4.0: Progress stats for any [DexRegionalPokedex] (11 regions).
  ///
  /// HGSS save-linked ranges still apply for national/kanto/johto; extended
  /// regions use [statsForSummaries] once browse data is loaded.
  DexScopeStats statsFor(
    DexRegionalPokedex region, {
    DexGameVersion gameVersion = DexGameVersion.hgss,
  }) {
    if (region == DexRegionalPokedex.national ||
        region == DexRegionalPokedex.kanto ||
        region == DexRegionalPokedex.johto) {
      final (start, end) = switch (region) {
        DexRegionalPokedex.national =>
          hgssSaveDexIdRange(DexRegionalScope.national),
        DexRegionalPokedex.kanto => hgssSaveDexIdRange(DexRegionalScope.kanto),
        DexRegionalPokedex.johto => hgssSaveDexIdRange(DexRegionalScope.johto),
        _ => throw StateError('Unreachable regional scope: $region'),
      };
      var caught = 0;
      var seenOnly = 0;
      for (var id = start; id <= end; id++) {
        if (caughtIds.contains(id)) {
          caught++;
        } else if (seenIds.contains(id)) {
          seenOnly++;
        }
      }
      final total = end - start + 1;
      return DexScopeStats(
        region: region,
        total: total,
        caught: caught,
        seenOnly: seenOnly,
        unseen: total - caught - seenOnly,
      );
    }

    // v0.4.0: Non-HGSS regional dexes have no save id range — empty until summaries load.
    return DexScopeStats(
      region: region,
      total: 0,
      caught: 0,
      seenOnly: 0,
      unseen: 0,
    );
  }

  /// v0.4.0: Count caught/seen against loaded summaries for extended regions.
  DexScopeStats statsForSummaries({
    required DexRegionalPokedex region,
    required DexGameVersion gameVersion,
    required Iterable<PokemonSummary> summaries,
  }) {
    final scope = DexScope(
      gameVersion: gameVersion,
      regionalScope: region,
    );
    var caught = 0;
    var seenOnly = 0;
    var total = 0;
    for (final summary in summaries) {
      if (!scope.speciesInScope(summary)) {
        continue;
      }
      total++;
      if (caughtIds.contains(summary.id)) {
        caught++;
      } else if (seenIds.contains(summary.id)) {
        seenOnly++;
      }
    }
    return DexScopeStats(
      region: region,
      total: total,
      caught: caught,
      seenOnly: seenOnly,
      unseen: total - caught - seenOnly,
    );
  }
}

class DexScopeStats {
  const DexScopeStats({
    required this.region,
    required this.total,
    required this.caught,
    required this.seenOnly,
    required this.unseen,
  });

  /// v0.4.0: Regional pokedex key (replaces legacy 3-value [DexRegionalScope]).
  final DexRegionalPokedex region;
  final int total;
  final int caught;
  final int seenOnly;
  final int unseen;

  int get seen => caught + seenOnly;
}
