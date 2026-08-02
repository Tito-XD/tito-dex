import '../../models/journey.dart';
import '../companion/companion_art.dart';
import '../parser/hgss_format.dart';
import 'dex_game_scope.dart';
import 'dex_models.dart';

/// Encounter filter for dex list views.
enum DexEncounterFilter { all, caught, seen, unseen, evolutionOrTrade }

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

  factory DexProgress.fromJourney(
    CurrentJourney journey, {
    bool manualDexMarks = false,
  }) {
    if (manualDexMarks) {
      final caught = journey.manualDexCaughtIds.toSet();
      final seen = journey.manualDexSeenIds.toSet();
      seen.addAll(caught);
      return DexProgress(caughtIds: caught, seenIds: seen, fromSave: false);
    }

    final caught = journey.saveDexCaughtIds.toSet();
    final seen = journey.saveDexSeenIds.toSet();
    seen.addAll(caught);

    for (final member in journey.party) {
      final id =
          member.speciesId ??
          speciesIdForName(member.species) ??
          knownSpeciesIdForLabel(member.species);
      if (id != null) {
        caught.add(id);
        seen.add(id);
      }
    }

    final companionId =
        speciesIdForName(journey.companion) ??
        knownSpeciesIdForLabel(journey.companion);
    if (companionId != null) {
      caught.add(companionId);
      seen.add(companionId);
    }

    return DexProgress(
      caughtIds: caught,
      seenIds: seen,
      fromSave:
          journey.saveDexCaughtIds.isNotEmpty ||
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

  bool matchesFilter(
    int id,
    DexEncounterFilter filter, {
    Set<int> evolutionOrTradeIds = const {},
  }) {
    return switch (filter) {
      DexEncounterFilter.all => true,
      DexEncounterFilter.caught => caughtIds.contains(id),
      DexEncounterFilter.seen => seenIds.contains(id),
      DexEncounterFilter.unseen => !seenIds.contains(id),
      DexEncounterFilter.evolutionOrTrade => evolutionOrTradeIds.contains(id),
    };
  }

  DexScopeStats statsFor(
    DexRegionalScope scope, {
    Set<int> evolutionOrTradeIds = const {},
  }) {
    final (start, end) = switch (scope) {
      DexRegionalScope.national => (1, titodexMaxNationalDexId),
      _ => hgssSaveDexIdRange(scope),
    };
    var caught = 0;
    var seenOnly = 0;
    var evolutionOrTradeOnly = 0;
    for (var id = start; id <= end; id++) {
      if (caughtIds.contains(id)) {
        caught++;
      } else if (seenIds.contains(id)) {
        seenOnly++;
      }
      if (evolutionOrTradeIds.contains(id)) {
        evolutionOrTradeOnly++;
      }
    }
    final total = end - start + 1;
    return DexScopeStats(
      scope: scope,
      total: total,
      caught: caught,
      seenOnly: seenOnly,
      unseen: total - caught - seenOnly,
      evolutionOrTradeOnly: evolutionOrTradeOnly,
    );
  }
}

class DexScopeStats {
  const DexScopeStats({
    required this.scope,
    required this.total,
    required this.caught,
    required this.seenOnly,
    required this.unseen,
    this.evolutionOrTradeOnly = 0,
  });

  final DexRegionalScope scope;
  final int total;
  final int caught;
  final int seenOnly;
  final int unseen;
  final int evolutionOrTradeOnly;

  int get seen => caught + seenOnly;
}
