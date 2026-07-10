import '../companion/companion_art.dart';
import '../parser/hgss_format.dart';
import '../../models/journey.dart';
import 'dex_models.dart';
import 'dex_offline_service.dart';
import 'dex_progress.dart';
import 'pokeapi_client.dart';
import 'type_chart.dart';

class DexRepository {
  DexRepository({
    PokeApiClient? client,
    DexOfflineService? offline,
    this.summaryBatchSize = 4,
  })  : _client = client ?? PokeApiClient(),
        _offline = offline ?? dexOfflineService;

  final PokeApiClient _client;
  final DexOfflineService _offline;
  final int summaryBatchSize;
  final Map<int, PokemonSummary> _summaryCache = {};
  final Map<int, PokemonDetail> _detailCache = {};
  final Map<String, int> _nameToIdCache = {};
  List<PokemonSummary>? _allSummaries;
  Future<List<PokemonSummary>>? _allSummariesFuture;

  DexProgress progressFor(CurrentJourney journey) =>
      DexProgress.fromJourney(journey);

  Future<PokemonSummary> getSummary(int id) async {
    if (_summaryCache.containsKey(id)) {
      return _summaryCache[id]!;
    }

    if (await _offline.shouldPreferOffline()) {
      final cached = await _offline.readSummary(id);
      if (cached != null) {
        _rememberSummary(cached);
        return cached;
      }
    }

    try {
      final summary = await _client.fetchSummary(id);
      _rememberSummary(summary);
      return summary;
    } on PokeApiException {
      final cached = await _offline.readSummary(id);
      if (cached != null) {
        _rememberSummary(cached);
        return cached;
      }
      rethrow;
    }
  }

  Future<PokemonDetail> getDetail(int id) async {
    if (_detailCache.containsKey(id)) {
      return _detailCache[id]!;
    }

    if (await _offline.shouldPreferOffline()) {
      try {
        final cached = await _offline.readDetail(id);
        if (cached != null) {
          _detailCache[id] = cached;
          _summaryCache[id] = cached.summary;
          return cached;
        }
      } catch (_) {
        // Corrupt partial offline cache — fall through to live API.
      }
    }

    try {
      final detail = await _client.fetchDetailWithMoves(id);
      _detailCache[id] = detail;
      _rememberSummary(detail.summary);
      return detail;
    } on PokeApiException {
      final cached = await _offline.readDetail(id);
      if (cached != null) {
        _detailCache[id] = cached;
        _summaryCache[id] = cached.summary;
        return cached;
      }
      rethrow;
    }
  }

  Future<List<PokemonSummary>> getAllSummaries() async {
    if (await _offline.shouldPreferOffline()) {
      final cached = await _offline.readAllSummaries();
      if (cached.isNotEmpty) {
        _allSummaries = cached;
        for (final summary in cached) {
          _rememberSummary(summary);
        }
        return cached;
      }
    }

    _allSummariesFuture ??= _loadAllSummaries();
    return _allSummariesFuture!;
  }

  Future<List<PokemonSummary>> _loadAllSummaries() async {
    if (_allSummaries != null) {
      return _allSummaries!;
    }

    final summaries = <PokemonSummary>[];

    for (var start = 1; start <= hgssMaxNationalDexId; start += summaryBatchSize) {
      final end = (start + summaryBatchSize - 1).clamp(1, hgssMaxNationalDexId);
      summaries.addAll(await getSummaryRange(start, end));
    }

    _allSummaries = summaries;
    return summaries;
  }

  Future<List<PokemonSummary>> getSummaryRange(int start, int end) async {
    final safeStart = start.clamp(1, hgssMaxNationalDexId);
    final safeEnd = end.clamp(safeStart, hgssMaxNationalDexId);
    final summaries = <PokemonSummary>[];

    for (var id = safeStart; id <= safeEnd; id += summaryBatchSize) {
      final batchEnd = (id + summaryBatchSize - 1).clamp(safeStart, safeEnd);
      final batch = await Future.wait(
        [
          for (var batchId = id; batchId <= batchEnd; batchId++)
            getSummary(batchId),
        ],
      );
      summaries.addAll(batch);
    }

    return summaries;
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

  /// Party + companion species treated as caught (legacy helper).
  Future<Set<int>> journeyCaughtIds(CurrentJourney journey) async {
    return progressFor(journey).caughtIds;
  }

  Future<List<PokemonSummary>> getSummariesForIds(Iterable<int> ids) async {
    final unique = ids.toSet().toList()..sort();
    if (unique.isEmpty) {
      return const [];
    }
    return Future.wait(unique.map(getSummary));
  }

  DexEncounterStatus statusFor(int id, DexProgress progress) =>
      progress.statusFor(id);

  List<PokemonSummary> filterSummaries(
    Iterable<PokemonSummary> entries,
    DexProgress progress,
    DexEncounterFilter filter,
  ) {
    return entries
        .where((entry) => progress.matchesFilter(entry.id, filter))
        .toList(growable: false);
  }

  void clearMemoryCache() {
    _summaryCache.clear();
    _detailCache.clear();
    _nameToIdCache.clear();
    _allSummaries = null;
    _allSummariesFuture = null;
  }

  void _rememberSummary(PokemonSummary summary) {
    _summaryCache[summary.id] = summary;
    _nameToIdCache[summary.nameEn.toLowerCase()] = summary.id;
    _nameToIdCache[summary.nameZh] = summary.id;
  }
}

final dexRepository = DexRepository();
