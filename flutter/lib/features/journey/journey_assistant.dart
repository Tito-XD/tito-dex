import '../../models/journey.dart';
import '../../l10n/game_zh.dart';
import '../dex/dex_game_scope.dart';
import '../dex/dex_models.dart';
import '../dex/dex_progress.dart';
import '../dex/dex_repository.dart';
import '../dex/location_index.dart';
import '../dex/version_availability.dart';
import '../game/game_edition.dart';
import '../game/game_edition_repository.dart';

class JourneyAssistantPokemon {
  const JourneyAssistantPokemon({
    required this.id,
    required this.nameZh,
    this.spritePath,
    this.formKey,
  });

  final int id;
  final String nameZh;
  final String? spritePath;
  final String? formKey;
}

class JourneyAssistantEvolution {
  const JourneyAssistantEvolution({
    required this.fromId,
    required this.fromNameZh,
    required this.toId,
    required this.toNameZh,
    required this.triggerZh,
  });

  final int fromId;
  final String fromNameZh;
  final int toId;
  final String toNameZh;
  final String triggerZh;
}

class JourneyAssistantSnapshot {
  const JourneyAssistantSnapshot({
    required this.locationLabel,
    required this.locationMatched,
    required this.nearbyUncaught,
    required this.nearbyUncaughtCount,
    required this.exactVersion,
    required this.exactVersionLabel,
    required this.pairedVersionLabel,
    required this.versionEncounterGaps,
    required this.versionEncounterGapCount,
    required this.evolutionOrTradeMissing,
    required this.evolutionOrTradeMissingCount,
    required this.partyEvolutions,
  });

  final String locationLabel;
  final bool locationMatched;
  final List<JourneyAssistantPokemon> nearbyUncaught;
  final int nearbyUncaughtCount;
  final String? exactVersion;
  final String? exactVersionLabel;
  final String? pairedVersionLabel;
  final List<JourneyAssistantPokemon> versionEncounterGaps;
  final int versionEncounterGapCount;
  final List<JourneyAssistantPokemon> evolutionOrTradeMissing;
  final int evolutionOrTradeMissingCount;
  final List<JourneyAssistantEvolution> partyEvolutions;

  String get cardSummary {
    if (locationMatched) {
      return nearbyUncaughtCount == 0
          ? '附近已捕获齐全'
          : '附近 $nearbyUncaughtCount 种待捕';
    }
    if (partyEvolutions.isNotEmpty) {
      return '队伍 ${partyEvolutions.length} 条进化提醒';
    }
    return '打开存档助手';
  }
}

typedef JourneyAssistantDetailLoader = Future<PokemonDetail> Function(int id);

class JourneyAssistantRepository {
  JourneyAssistantRepository({
    LocationIndexRepository? locationIndex,
    DexRepository? dex,
    GameEditionRepository? editions,
  }) : _locationIndex = locationIndex ?? locationIndexRepository,
       _dex = dex ?? dexRepository,
       _editions = editions ?? gameEditionRepository;

  final LocationIndexRepository _locationIndex;
  final DexRepository _dex;
  final GameEditionRepository _editions;
  final Map<String, Future<JourneyAssistantSnapshot>> _cache = {};

  /// Lightweight home-card path: one cached summary catalog plus the location
  /// index, with no per-party detail reads.
  Future<JourneyAssistantSnapshot> loadPreview(CurrentJourney journey) async {
    final edition = await _editions.loadEdition();
    final key = 'preview:${_cacheKey(journey, edition)}';
    return _cache.putIfAbsent(key, () => _loadPreview(journey, edition));
  }

  Future<JourneyAssistantSnapshot> load(CurrentJourney journey) async {
    final edition = await _editions.loadEdition();
    final key = _cacheKey(journey, edition);
    return _cache.putIfAbsent(key, () => _load(journey, edition));
  }

  Future<JourneyAssistantSnapshot> _loadPreview(
    CurrentJourney journey,
    GameEdition edition,
  ) async {
    final results = await Future.wait([
      _locationIndex.load(),
      _dex.getAllSummaries(),
    ]);
    return buildJourneyAssistantSnapshot(
      journey: journey,
      edition: edition,
      index: results[0] as LocationIndex,
      summaries: {
        for (final summary in results[1] as List<PokemonSummary>)
          summary.id: summary,
      },
      progress: DexProgress.fromJourney(journey),
      evolutionOrTradeMissingIds: const {},
    );
  }

  Future<JourneyAssistantSnapshot> _load(
    CurrentJourney journey,
    GameEdition edition,
  ) async {
    final results = await Future.wait([
      _locationIndex.load(),
      _dex.getAllSummaries(),
    ]);
    final index = results[0] as LocationIndex;
    final summaries = {
      for (final summary in results[1] as List<PokemonSummary>)
        summary.id: summary,
    };
    final progress = DexProgress.fromJourney(journey);
    final evolutionMissingIds = await _dex.evolutionOrTradeMissingIds(
      progress: progress,
      edition: edition,
    );
    final details = <int, PokemonDetail>{};
    await Future.wait([
      for (final id in journey.party.map((member) => member.speciesId).nonNulls)
        _dex
            .getDetail(id)
            .then<void>((detail) => details[id] = detail, onError: (_) {}),
    ]);
    return buildJourneyAssistantSnapshot(
      journey: journey,
      edition: edition,
      index: index,
      summaries: summaries,
      progress: progress,
      evolutionOrTradeMissingIds: evolutionMissingIds,
      partyDetails: details,
    );
  }

  String _cacheKey(CurrentJourney journey, GameEdition edition) => [
    edition.slug,
    edition.selectedFlavor ?? '@merged',
    journey.location,
    journey.saveDexHash ?? '',
    ...journey.manualDexCaughtIds,
    ...journey.party.map((member) => '${member.speciesId}:${member.level}'),
  ].join('|');
}

JourneyAssistantSnapshot buildJourneyAssistantSnapshot({
  required CurrentJourney journey,
  required GameEdition edition,
  required LocationIndex index,
  required Map<int, PokemonSummary> summaries,
  required DexProgress progress,
  required Set<int> evolutionOrTradeMissingIds,
  Map<int, PokemonDetail> partyDetails = const {},
  int previewLimit = 6,
}) {
  final matchedAreas = matchJourneyLocation(
    index.areasForEdition(edition),
    localizeLocation(journey.location),
  );
  final entriesBySpecies = <int, LocationEncounterEntry>{};
  for (final area in matchedAreas) {
    for (final entry in area.entries) {
      final previous = entriesBySpecies[entry.speciesId];
      if (previous == null || entry.maxChance > previous.maxChance) {
        entriesBySpecies[entry.speciesId] = entry;
      }
    }
  }
  final nearbyIds =
      entriesBySpecies.keys
          .where((id) => !progress.caughtIds.contains(id))
          .toList()
        ..sort((a, b) {
          final chance = entriesBySpecies[b]!.maxChance.compareTo(
            entriesBySpecies[a]!.maxChance,
          );
          return chance != 0 ? chance : a.compareTo(b);
        });

  final exactVersion = edition.selectedFlavor;
  final pairedVersion = exactVersion == null
      ? null
      : pairedEncounterVersion(exactVersion);
  final currentEncounterIds = exactVersion == null
      ? const <int>{}
      : _encounterIds(index, accessibleEncounterVersions(exactVersion));
  final pairedEncounterIds = pairedVersion == null
      ? const <int>{}
      : _encounterIds(index, accessibleEncounterVersions(pairedVersion));
  final encounterGapIds =
      pairedEncounterIds
          .difference(currentEncounterIds)
          .where((id) => !progress.caughtIds.contains(id))
          .toList()
        ..sort();
  final evolutionIds = evolutionOrTradeMissingIds.toList()..sort();

  final partyEvolutions = <JourneyAssistantEvolution>[];
  for (final member in journey.party) {
    final id = member.speciesId;
    final chain = id == null ? null : partyDetails[id]?.evolutionChain;
    final current = chain == null ? null : _findEvolutionNode(chain, id!);
    if (current == null) {
      continue;
    }
    for (final child in current.children) {
      partyEvolutions.add(
        JourneyAssistantEvolution(
          fromId: current.id,
          fromNameZh: current.nameZh,
          toId: child.id,
          toNameZh: child.nameZh,
          triggerZh: child.triggerZh?.trim().isNotEmpty == true
              ? child.triggerZh!
              : '满足进化条件',
        ),
      );
    }
  }

  JourneyAssistantPokemon pokemon(int id, {String? formKey}) {
    final summary = summaries[id];
    return JourneyAssistantPokemon(
      id: id,
      nameZh: summary?.nameZh ?? '#$id',
      spritePath: summary?.displaySpritePath,
      formKey: formKey,
    );
  }

  return JourneyAssistantSnapshot(
    locationLabel: matchedAreas.isEmpty
        ? localizeLocation(journey.location)
        : matchedAreas.first.labelZh,
    locationMatched: matchedAreas.isNotEmpty,
    nearbyUncaught: [
      for (final id in nearbyIds.take(previewLimit))
        pokemon(id, formKey: entriesBySpecies[id]?.formKey),
    ],
    nearbyUncaughtCount: nearbyIds.length,
    exactVersion: exactVersion,
    exactVersionLabel: exactVersion == null
        ? null
        : flavorVersionLabelZh(exactVersion),
    pairedVersionLabel: pairedVersion == null
        ? null
        : flavorVersionLabelZh(pairedVersion),
    versionEncounterGaps: [
      for (final id in encounterGapIds.take(previewLimit)) pokemon(id),
    ],
    versionEncounterGapCount: encounterGapIds.length,
    evolutionOrTradeMissing: [
      for (final id in evolutionIds.take(previewLimit)) pokemon(id),
    ],
    evolutionOrTradeMissingCount: evolutionIds.length,
    partyEvolutions: partyEvolutions,
  );
}

List<LocationArea> matchJourneyLocation(
  Iterable<LocationArea> areas,
  String location,
) {
  final target = _normalizeLocation(location);
  if (target.isEmpty) {
    return const [];
  }
  final exact = areas
      .where((area) => _normalizeLocation(area.labelZh) == target)
      .toList(growable: false);
  if (exact.isNotEmpty) {
    return exact;
  }
  final fuzzy = areas.where((area) {
    final label = _normalizeLocation(area.labelZh);
    return label.length >= 2 &&
        target.length >= 2 &&
        (target.contains(label) || label.contains(target));
  }).toList();
  final labels = fuzzy.map((area) => _normalizeLocation(area.labelZh)).toSet();
  return labels.length == 1 ? fuzzy : const [];
}

String _normalizeLocation(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[\s·・,，.。()（）\-_/]'), '');

Set<int> _encounterIds(LocationIndex index, Iterable<String> versions) => {
  for (final version in versions)
    for (final area in index.byVersion[version] ?? const <LocationArea>[])
      for (final entry in area.entries) entry.speciesId,
};

EvolutionNode? _findEvolutionNode(EvolutionNode node, int id) {
  if (node.id == id) {
    return node;
  }
  for (final child in node.children) {
    final result = _findEvolutionNode(child, id);
    if (result != null) {
      return result;
    }
  }
  return null;
}

final journeyAssistantRepository = JourneyAssistantRepository();
