import '../../models/journey.dart';
import 'dex_models.dart';
import 'pokeapi_client.dart';
import 'type_chart.dart';

/// HGSS national dex scope (Gen IV).
const hgssMaxNationalDexId = 493;

class DexRepository {
  DexRepository({PokeApiClient? client}) : _client = client ?? PokeApiClient();

  final PokeApiClient _client;
  final Map<int, PokemonSummary> _summaryCache = {};
  final Map<int, PokemonDetail> _detailCache = {};
  final Map<String, int> _nameToIdCache = {};
  List<PokemonSummary>? _allSummaries;
  Future<List<PokemonSummary>>? _allSummariesFuture;

  Future<PokemonSummary> getSummary(int id) async {
    if (_summaryCache.containsKey(id)) {
      return _summaryCache[id]!;
    }
    final summary = await _client.fetchSummary(id);
    _summaryCache[id] = summary;
    _nameToIdCache[summary.nameEn.toLowerCase()] = id;
    _nameToIdCache[summary.nameZh] = id;
    return summary;
  }

  Future<PokemonDetail> getDetail(int id) async {
    if (_detailCache.containsKey(id)) {
      return _detailCache[id]!;
    }
    final detail = await _client.fetchDetail(id);
    _detailCache[id] = detail;
    _summaryCache[id] = detail.summary;
    return detail;
  }

  Future<List<PokemonSummary>> getAllSummaries() {
    _allSummariesFuture ??= _loadAllSummaries();
    return _allSummariesFuture!;
  }

  Future<List<PokemonSummary>> _loadAllSummaries() async {
    if (_allSummaries != null) {
      return _allSummaries!;
    }

    const batchSize = 25;
    final summaries = <PokemonSummary>[];

    for (var start = 1; start <= hgssMaxNationalDexId; start += batchSize) {
      final end = (start + batchSize - 1).clamp(1, hgssMaxNationalDexId);
      final batch = await Future.wait(
        [
          for (var id = start; id <= end; id++) getSummary(id),
        ],
      );
      summaries.addAll(batch);
    }

    _allSummaries = summaries;
    return summaries;
  }

  Future<List<PokemonSummary>> getSummaryRange(int start, int end) async {
    final safeStart = start.clamp(1, hgssMaxNationalDexId);
    final safeEnd = end.clamp(safeStart, hgssMaxNationalDexId);
    return Future.wait(
      [
        for (var id = safeStart; id <= safeEnd; id++) getSummary(id),
      ],
    );
  }

  Future<List<PokemonSummary>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final all = await getAllSummaries();
    final lower = trimmed.toLowerCase();
    final numeric = int.tryParse(trimmed);

    return all.where((entry) {
      if (numeric != null && entry.id == numeric) {
        return true;
      }
      if (entry.id.toString().contains(trimmed)) {
        return true;
      }
      if (entry.nameEn.toLowerCase().contains(lower)) {
        return true;
      }
      if (entry.nameZh.contains(trimmed)) {
        return true;
      }
      if (entry.types.any((type) => typeNameZh(type).contains(trimmed))) {
        return true;
      }
      return false;
    }).toList();
  }

  Future<Set<int>> journeyCaughtIds(CurrentJourney journey) async {
    final ids = <int>{};
    final names = <String>{
      ...journey.party.map((member) => member.species),
      journey.companion,
    };

    for (final name in names) {
      final cached = _nameToIdCache[name.toLowerCase()];
      if (cached != null) {
        ids.add(cached);
        continue;
      }
      final id = await _client.resolveSpeciesId(name);
      if (id != null) {
        ids.add(id);
        _nameToIdCache[name.toLowerCase()] = id;
      }
    }
    return ids;
  }

  DexEncounterStatus statusFor(int id, Set<int> caughtIds) {
    if (caughtIds.contains(id)) {
      return DexEncounterStatus.caught;
    }
    return DexEncounterStatus.unknown;
  }

  void clearCache() {
    _summaryCache.clear();
    _detailCache.clear();
    _nameToIdCache.clear();
    _allSummaries = null;
    _allSummariesFuture = null;
  }
}

final dexRepository = DexRepository();
