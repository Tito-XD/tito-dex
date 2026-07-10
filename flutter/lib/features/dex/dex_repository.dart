import '../companion/companion_art.dart';
import '../parser/hgss_format.dart';
import '../../models/journey.dart';
import 'dex_cdn_data_source.dart';
import 'dex_models.dart';
import 'dex_offline_service.dart';
import 'pokeapi_client.dart';
import 'type_chart.dart';

/// Data priority: Settings-installed offline bundle → live CF R2 CDN
/// (`dex.tito.cafe`, one summaries.json + per-id details.json) → PokeAPI.
class DexRepository {
  DexRepository({
    PokeApiClient? client,
    DexOfflineService? offline,
    DexCdnDataSource? cdn,
    this.summaryBatchSize = 4,
  })  : _client = client ?? PokeApiClient(),
        _offline = offline ?? dexOfflineService,
        _cdn = cdn ?? DexCdnDataSource();

  final PokeApiClient _client;
  final DexOfflineService _offline;
  final DexCdnDataSource _cdn;
  final int summaryBatchSize;
  final Map<int, PokemonSummary> _summaryCache = {};
  final Map<int, PokemonDetail> _detailCache = {};
  final Map<String, int> _nameToIdCache = {};
  List<PokemonSummary>? _allSummaries;
  Future<List<PokemonSummary>>? _allSummariesFuture;
  bool _cdnSummariesUnavailable = false;

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

    // CDN: one summaries.json download covers every id.
    final fromCdn = await _summaryFromCdn(id);
    if (fromCdn != null) {
      return fromCdn;
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

  Future<PokemonSummary?> _summaryFromCdn(int id) async {
    if (_cdnSummariesUnavailable) {
      return null;
    }
    try {
      final all = await _cdn.fetchAllSummaries();
      for (final summary in all) {
        _rememberSummary(summary);
      }
      return _summaryCache[id];
    } catch (_) {
      // CDN unreachable — remember and fall back to PokeAPI for this session.
      _cdnSummariesUnavailable = true;
      return null;
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
        // Corrupt partial offline cache — fall through to live sources.
      }
    }

    try {
      final detail = await _cdn.fetchDetail(id);
      _detailCache[id] = detail;
      _rememberSummary(detail.summary);
      return detail;
    } catch (_) {
      // CDN miss/unreachable — fall through to PokeAPI.
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

    if (!_cdnSummariesUnavailable) {
      try {
        final all = await _cdn.fetchAllSummaries();
        for (final summary in all) {
          _rememberSummary(summary);
        }
        _allSummaries = all;
        return all;
      } catch (_) {
        _cdnSummariesUnavailable = true;
      }
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

    // Fast path: the CDN summary list covers the whole range at once.
    if (!_cdnSummariesUnavailable) {
      final fromCdn = await _summaryFromCdn(safeStart);
      if (fromCdn != null) {
        return [
          for (var id = safeStart; id <= safeEnd; id++)
            if (_summaryCache.containsKey(id)) _summaryCache[id]!,
        ];
      }
    }

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

  Future<Set<int>> journeyCaughtIds(CurrentJourney journey) async {
    final ids = <int>{};

    for (final member in journey.party) {
      final id = member.speciesId ??
          speciesIdForName(member.species) ??
          knownSpeciesIdForLabel(member.species);
      if (id != null) {
        ids.add(id);
      }
    }

    final companionId = speciesIdForName(journey.companion) ??
        knownSpeciesIdForLabel(journey.companion);
    if (companionId != null) {
      ids.add(companionId);
    }

    final names = <String>{
      ...journey.party.map((member) => member.species),
      journey.companion,
    };

    for (final name in names) {
      if (speciesIdForName(name) != null ||
          knownSpeciesIdForLabel(name) != null) {
        continue;
      }
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

  Future<List<PokemonSummary>> getSummariesForIds(Iterable<int> ids) async {
    final unique = ids.toSet().toList()..sort();
    if (unique.isEmpty) {
      return const [];
    }
    return Future.wait(unique.map(getSummary));
  }

  DexEncounterStatus statusFor(int id, Set<int> caughtIds) {
    if (caughtIds.contains(id)) {
      return DexEncounterStatus.caught;
    }
    return DexEncounterStatus.unknown;
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
