import '../../l10n/game_zh.dart';
import '../../models/journey.dart';
import '../game/game_edition.dart';
import '../../l10n/app_zh.dart';
import 'dex_cdn_config.dart';
import 'dex_cdn_data_source.dart';
import 'dex_catalog.dart';
import 'dex_filter.dart';
import 'dex_models.dart';
import 'dex_offline_service.dart';
import 'dex_progress.dart';
import 'dex_scope.dart';
import 'dex_settings_repository.dart';
import 'pokeapi_client.dart';
import 'type_chart.dart';

/// Data priority: Settings-installed offline bundle → live pre-built dex CDN
/// (summaries + per-id details) → PokeAPI.
class DexRepository {
  DexRepository({
    PokeApiClient? client,
    DexOfflineService? offline,
    DexCdnDataSource? cdn,
    DexCdnConfig? cdnConfig,
    this.summaryBatchSize = 4,
  }) : _client = client ?? PokeApiClient(),
       _offline = offline ?? dexOfflineService,
       _cdn = cdn ?? DexCdnDataSource(),
       _cdnConfig = cdnConfig ?? const DexCdnConfig();

  final PokeApiClient _client;
  final DexOfflineService _offline;
  final DexCdnDataSource _cdn;
  final DexCdnConfig _cdnConfig;
  final int summaryBatchSize;
  final Map<int, PokemonSummary> _summaryCache = {};
  final Map<int, PokemonDetail> _detailCache = {};
  final Map<String, int> _nameToIdCache = {};
  List<PokemonSummary>? _allSummaries;
  Future<List<PokemonSummary>>? _allSummariesFuture;
  DexCatalog? _catalog;
  Future<DexCatalog?>? _catalogFuture;
  bool _cdnSummariesUnavailable = false;
  Map<int, CachedMove>? _allMovesCache;
  Future<Map<int, CachedMove>>? _allMovesFuture;
  Map<int, CachedAbility>? _allAbilitiesCache;
  Future<Map<int, CachedAbility>>? _allAbilitiesFuture;
  Map<String, List<int>>? _eggGroupIndexCache;
  Future<Map<String, List<int>>>? _eggGroupIndexFuture;
  Map<int, List<int>>? _moveLearnersIndexCache;
  Future<Map<int, List<int>>>? _moveLearnersIndexFuture;

  DexProgress progressFor(
    CurrentJourney journey, {
    bool manualDexMarks = false,
  }) => DexProgress.fromJourney(journey, manualDexMarks: manualDexMarks);

  Future<DexScope> getDefaultScope() =>
      dexSettingsRepository.loadDefaultScope();

  Future<List<PokemonSummary>> getScopeSummaries(DexScope scope) async {
    final all = await getAllSummaries();
    final filtered = all.where(scope.speciesInScope).toList(growable: false);
    filtered.sort((a, b) {
      final aNumber = scope.regionalNumberFor(a) ?? a.id;
      final bNumber = scope.regionalNumberFor(b) ?? b.id;
      final numberCompare = aNumber.compareTo(bNumber);
      if (numberCompare != 0) {
        return numberCompare;
      }
      return a.id.compareTo(b.id);
    });
    return filtered;
  }

  Future<PokemonSummary> getSummary(int id) async {
    if (_summaryCache.containsKey(id)) {
      return _summaryCache[id]!;
    }

    final catalog = await _loadCatalog();
    if (catalog != null) {
      await _activateCatalog(catalog);
      final summary = _summaryCache[id];
      if (summary != null) {
        return summary;
      }
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

    // Full CDN bundle installed — always serve from local files (airplane mode).
    if (await _offline.isReady()) {
      try {
        final cached = await _offline.readDetail(id);
        if (cached != null) {
          _detailCache[id] = cached;
          _summaryCache[id] = cached.summary;
          return cached;
        }
      } catch (_) {
        // Corrupt entry — fall through to live sources.
      }
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

    // Offline bundle fallback even when preferOffline is off (airplane mode).
    try {
      final cached = await _offline.readDetail(id);
      if (cached != null) {
        _detailCache[id] = cached;
        _summaryCache[id] = cached.summary;
        return cached;
      }
    } catch (_) {}

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

  /// Abilities for a species — detail JSON first, then reverse lookup in abilities index.
  Future<List<PokemonAbility>> abilitiesForPokemon(int pokemonId) async {
    final detail = await getDetail(pokemonId);
    var abilities = detail.abilities;
    if (abilities.isEmpty) {
      final index = await _loadAllAbilities();
      final fromIndex = <PokemonAbility>[];
      for (final entry in index.values) {
        if (entry.pokemonIds.contains(pokemonId)) {
          fromIndex.add(
            PokemonAbility(
              nameEn: entry.nameEn,
              nameZh: entry.nameZh,
              descriptionZh: entry.descriptionZh,
            ),
          );
        }
      }
      fromIndex.sort((a, b) => a.nameZh.compareTo(b.nameZh));
      abilities = fromIndex;
    }
    return _enrichAbilityGameLabels(abilities, detail);
  }

  List<PokemonAbility> _enrichAbilityGameLabels(
    List<PokemonAbility> abilities,
    PokemonDetail detail,
  ) {
    if (abilities.isEmpty) {
      return abilities;
    }

    final labelsByNameEn = <String, List<String>>{};
    if (detail.abilitiesByGame.isNotEmpty) {
      for (final entry in detail.abilitiesByGame.entries) {
        final label = gameEditionLabelForVersionGroup(entry.key);
        for (final ability in entry.value) {
          labelsByNameEn.putIfAbsent(ability.nameEn, () => []).add(label);
        }
      }
    }

    return abilities
        .map((ability) {
          if (ability.gameLabelsZh.isNotEmpty) {
            return ability;
          }
          final labels = labelsByNameEn[ability.nameEn];
          if (labels != null && labels.isNotEmpty) {
            return ability.copyWith(
              gameLabelsZh: labels.toSet().toList()..sort(),
            );
          }
          return ability.copyWith(
            gameLabelsZh: [
              ability.isHidden
                  ? AppZh.dexAbilitySinceGen5
                  : AppZh.dexAbilityAllVersions,
            ],
          );
        })
        .toList(growable: false);
  }

  Future<List<PokemonSummary>> getAllSummaries() async {
    if (_allSummaries != null) {
      return _allSummaries!;
    }
    _allSummariesFuture ??= _loadAllSummaries();
    return _allSummariesFuture!;
  }

  /// Starts the complete list/filter directory before a user opens the Dex.
  /// Once this resolves, list, search and all supported reference filters are
  /// pure memory operations.
  Future<void> warmUp() async {
    await getAllSummaries();
  }

  Future<List<PokemonSummary>> _loadAllSummaries() async {
    if (_allSummaries != null) {
      return _allSummaries!;
    }

    final catalog = await _loadCatalog();
    if (catalog != null) {
      return _activateCatalog(catalog);
    }

    if (await _offline.shouldPreferOffline()) {
      final cached = await _offline.readAllSummaries();
      if (cached.isNotEmpty) {
        final resolved = await Future.wait(cached.map(_resolveSummarySprite));
        return _rememberAllSummaries(resolved);
      }
    }

    if (!_cdnSummariesUnavailable) {
      try {
        final all = await _cdn.fetchAllSummaries();
        return _rememberAllSummaries(all);
      } catch (_) {
        _cdnSummariesUnavailable = true;
      }
    }

    final summaries = <PokemonSummary>[];

    for (
      var start = 1;
      start <= titodexMaxNationalDexId;
      start += summaryBatchSize
    ) {
      final end = (start + summaryBatchSize - 1).clamp(
        1,
        titodexMaxNationalDexId,
      );
      summaries.addAll(await getSummaryRange(start, end));
    }

    return _rememberAllSummaries(summaries);
  }

  Future<List<PokemonSummary>> getSummaryRange(int start, int end) async {
    final safeStart = start.clamp(1, titodexMaxNationalDexId);
    final safeEnd = end.clamp(safeStart, titodexMaxNationalDexId);

    final all = await getAllSummaries();
    return [
      for (final summary in all)
        if (summary.id >= safeStart && summary.id <= safeEnd) summary,
    ];
  }

  Future<List<PokemonSummary>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final all = await getAllSummaries();
    final lower = trimmed.toLowerCase();
    final numeric = int.tryParse(trimmed);

    final matches = all.where((entry) {
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

    return matches;
  }

  Future<List<PokemonSummary>> filterSummaries(DexFilter filter) async {
    if (!filter.isActive) {
      return getAllSummaries();
    }

    if (filter.learnsMoveId != null) {
      final ids = await findPokemonWithMove(filter.learnsMoveId!);
      return getSummariesForIds(ids);
    }

    if (filter.abilityId != null) {
      return findByAbility(filter.abilityId!);
    }

    if (filter.eggGroupSlug != null) {
      return findByEggGroup(filter.eggGroupSlug!);
    }

    return const [];
  }

  Future<List<int>> findPokemonWithMove(int moveId) async {
    final catalog = await _loadCatalog();
    if (catalog != null) {
      return catalog.moveLearners[moveId] ?? const [];
    }

    final offlineIds = await _offline.findPokemonIdsWithMove(moveId);
    if (offlineIds.isNotEmpty) {
      return offlineIds;
    }

    final cached = <int>[];
    for (final entry in _detailCache.entries) {
      if (_detailHasMove(entry.value, moveId)) {
        cached.add(entry.key);
      }
    }
    if (cached.isNotEmpty) {
      cached.sort();
      return cached;
    }

    final index = await _loadMoveLearnersIndex();
    final indexed = index[moveId] ?? const [];
    if (indexed.isNotEmpty) {
      return indexed;
    }

    return const [];
  }

  bool _detailHasMove(PokemonDetail detail, int moveId) {
    for (final move in detail.moveSet.allMoves) {
      if (move.id == moveId) {
        return true;
      }
    }
    for (final moveSet in detail.moveSets.values) {
      for (final move in moveSet.allMoves) {
        if (move.id == moveId) {
          return true;
        }
      }
    }
    return false;
  }

  Future<PokemonSummary> _resolveSummarySprite(PokemonSummary summary) async {
    final path = summary.localSpritePath;
    if (path != null && !path.startsWith('http') && !_isAbsolutePath(path)) {
      final absolute = await _offline.absolutePathForRelative(path);
      if (absolute != null) {
        return summary.copyWith(localSpritePath: absolute);
      }
    } else if (path != null) {
      return summary;
    }

    final fallback = summary.spriteUrl ?? _cdnConfig.spriteUrl(summary.id);
    return summary.copyWith(localSpritePath: fallback);
  }

  bool _isAbsolutePath(String path) {
    if (path.startsWith('/')) {
      return true;
    }
    // Windows drive paths (e.g. C:\sprites\1.png).
    return RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(path);
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
    if (_allSummaries != null) {
      return [
        for (final id in unique)
          if (_summaryCache[id] != null) _summaryCache[id]!,
      ];
    }
    return Future.wait(unique.map(getSummary));
  }

  DexEncounterStatus statusFor(int id, DexProgress progress) =>
      progress.statusFor(id);

  List<PokemonSummary> filterByEncounter(
    Iterable<PokemonSummary> entries,
    DexProgress progress,
    DexEncounterFilter filter,
  ) {
    return entries
        .where((entry) => progress.matchesFilter(entry.id, filter))
        .toList(growable: false);
  }

  Future<List<CachedMove>> getAllMoves() async {
    if (_allMovesCache != null) {
      return _allMovesCache!.values.toList()
        ..sort((a, b) => a.id.compareTo(b.id));
    }

    _allMovesFuture ??= _loadAllMoves();
    final moves = await _allMovesFuture!;
    return moves.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<Map<int, CachedMove>> _loadAllMoves() async {
    if (_allMovesCache != null) {
      return _allMovesCache!;
    }
    final catalog = await _loadCatalog();
    if (catalog != null && catalog.moves.isNotEmpty) {
      _allMovesCache = catalog.moves;
      return catalog.moves;
    }
    final offline = await _offline.readMovesIndex();
    if (offline.isNotEmpty) {
      _allMovesCache = offline;
      return offline;
    }
    try {
      final moves = await _cdn.fetchAllMoves();
      _allMovesCache = moves;
      return moves;
    } catch (_) {
      final offline = await _offline.readMovesIndex();
      if (offline.isNotEmpty) {
        _allMovesCache = offline;
        return offline;
      }
      return const {};
    }
  }

  Future<List<CachedAbility>> getAllAbilities() async {
    if (_allAbilitiesCache != null) {
      return _allAbilitiesCache!.values.toList()
        ..sort((a, b) => a.id.compareTo(b.id));
    }

    _allAbilitiesFuture ??= _loadAllAbilities();
    final abilities = await _allAbilitiesFuture!;
    return abilities.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<CachedAbility> fetchAbilityEncyclopedia(int id) async {
    final abilities = await _loadAllAbilities();
    final entry = abilities[id];
    if (entry != null) {
      return entry;
    }
    return _cdn.fetchAbilityEncyclopedia(id);
  }

  Future<Map<int, CachedAbility>> _loadAllAbilities() async {
    if (_allAbilitiesCache != null) {
      return _allAbilitiesCache!;
    }
    final catalog = await _loadCatalog();
    if (catalog != null && catalog.abilities.isNotEmpty) {
      _allAbilitiesCache = catalog.abilities;
      return catalog.abilities;
    }
    final offline = await _offline.readAbilitiesIndex();
    if (offline.isNotEmpty) {
      _allAbilitiesCache = offline;
      return offline;
    }
    try {
      final abilities = await _cdn.fetchAllAbilities();
      _allAbilitiesCache = abilities;
      return abilities;
    } catch (_) {
      final offline = await _offline.readAbilitiesIndex();
      if (offline.isNotEmpty) {
        _allAbilitiesCache = offline;
        return offline;
      }
      return const {};
    }
  }

  /// Reference hub entries (natures, weather, …) — local bundle first, then CDN.
  Future<List<Map<String, dynamic>>> getReferenceEntries(
    String filename,
  ) async {
    final offline = await _offline.readReferenceArray(filename);
    if (offline.isNotEmpty) {
      return offline;
    }
    try {
      return await _cdn.fetchReferenceArray(filename);
    } catch (_) {
      return const [];
    }
  }

  Future<List<PokemonSummary>> findByAbility(int id) async {
    final catalog = await _loadCatalog();
    if (catalog != null) {
      return getSummariesForIds(catalog.abilityPokemonIds[id] ?? const []);
    }
    final abilities = await _loadAllAbilities();
    final entry = abilities[id];
    if (entry == null || entry.pokemonIds.isEmpty) {
      return const [];
    }
    return getSummariesForIds(entry.pokemonIds);
  }

  Future<List<PokemonSummary>> findByEggGroup(String slug) async {
    final catalog = await _loadCatalog();
    if (catalog != null) {
      return getSummariesForIds(catalog.eggGroups[slug] ?? const []);
    }
    final index = await _loadEggGroupIndex();
    final ids = index[slug] ?? const [];
    if (ids.isEmpty) {
      return const [];
    }
    return getSummariesForIds(ids);
  }

  Future<List<PokemonSummary>> findByMove(int moveId) async {
    final catalog = await _loadCatalog();
    if (catalog != null) {
      return getSummariesForIds(catalog.moveLearners[moveId] ?? const []);
    }
    final index = await _loadMoveLearnersIndex();
    final ids = index[moveId] ?? const [];
    if (ids.isEmpty) {
      return const [];
    }
    return getSummariesForIds(ids);
  }

  Future<Map<String, List<int>>> _loadEggGroupIndex() {
    return _eggGroupIndexFuture ??= _buildEggGroupIndex().catchError((
      Object error,
    ) {
      _eggGroupIndexFuture = null;
      throw error; // ignore: only_throw_errors
    });
  }

  Future<Map<int, List<int>>> _loadMoveLearnersIndex() {
    return _moveLearnersIndexFuture ??= _buildMoveLearnersIndex().catchError((
      Object error,
    ) {
      _moveLearnersIndexFuture = null;
      throw error; // ignore: only_throw_errors
    });
  }

  Future<Map<String, List<int>>> _buildEggGroupIndex() async {
    if (_eggGroupIndexCache != null) {
      return _eggGroupIndexCache!;
    }
    final index = <String, List<int>>{};
    final summaries = await getAllSummaries();
    for (var start = 0; start < summaries.length; start += summaryBatchSize) {
      final end = (start + summaryBatchSize).clamp(0, summaries.length);
      final batch = summaries.sublist(start, end);
      final details = await Future.wait(
        batch.map((entry) => getDetail(entry.id)),
      );
      for (final detail in details) {
        for (final groupLabel in detail.eggGroups) {
          final slug = _eggGroupSlugForLabel(groupLabel);
          if (slug == null) {
            continue;
          }
          index.putIfAbsent(slug, () => []).add(detail.summary.id);
        }
      }
    }
    for (final ids in index.values) {
      ids.sort();
    }
    _eggGroupIndexCache = index;
    return index;
  }

  Future<Map<int, List<int>>> _buildMoveLearnersIndex() async {
    if (_moveLearnersIndexCache != null) {
      return _moveLearnersIndexCache!;
    }
    final index = <int, List<int>>{};
    final summaries = await getAllSummaries();
    for (var start = 0; start < summaries.length; start += summaryBatchSize) {
      final end = (start + summaryBatchSize).clamp(0, summaries.length);
      final batch = summaries.sublist(start, end);
      final details = await Future.wait(
        batch.map((entry) => getDetail(entry.id)),
      );
      for (final detail in details) {
        final moveIds = <int>{};
        for (final moveSet in detail.moveSets.values) {
          moveIds.addAll(_moveIdsFromSet(moveSet));
        }
        moveIds.addAll(_moveIdsFromSet(detail.moveSet));
        for (final moveId in moveIds) {
          index.putIfAbsent(moveId, () => []).add(detail.summary.id);
        }
      }
    }
    for (final ids in index.values) {
      ids.sort();
    }
    _moveLearnersIndexCache = index;
    return index;
  }

  Set<int> _moveIdsFromSet(PokemonMoveSet moveSet) {
    final ids = <int>{};
    for (final entry in moveSet.levelUp) {
      ids.add(entry.move.id);
    }
    for (final entry in moveSet.machine) {
      ids.add(entry.move.id);
    }
    for (final entry in moveSet.egg) {
      ids.add(entry.move.id);
    }
    for (final entry in moveSet.tutor) {
      ids.add(entry.move.id);
    }
    return ids;
  }

  String? _eggGroupSlugForLabel(String label) => eggGroupSlugForLabelZh(label);

  void clearMemoryCache() {
    _summaryCache.clear();
    _detailCache.clear();
    _nameToIdCache.clear();
    _allSummaries = null;
    _allSummariesFuture = null;
    _catalog = null;
    _catalogFuture = null;
    _allMovesCache = null;
    _allMovesFuture = null;
    _allAbilitiesCache = null;
    _allAbilitiesFuture = null;
    _eggGroupIndexCache = null;
    _eggGroupIndexFuture = null;
    _moveLearnersIndexCache = null;
    _moveLearnersIndexFuture = null;
  }

  void _rememberSummary(PokemonSummary summary) {
    _summaryCache[summary.id] = summary;
    _nameToIdCache[summary.nameEn.toLowerCase()] = summary.id;
    _nameToIdCache[summary.nameZh] = summary.id;
  }

  Future<DexCatalog?> _loadCatalog() {
    if (_catalog != null) {
      return Future.value(_catalog);
    }
    return _catalogFuture ??= _offline
        .readCatalog()
        .then((catalog) {
          _catalog = catalog;
          return catalog;
        })
        .catchError((_) {
          // A legacy or interrupted bundle can still use the existing fallback.
          return null;
        });
  }

  Future<List<PokemonSummary>> _activateCatalog(DexCatalog catalog) async {
    if (_allSummaries != null) {
      return _allSummaries!;
    }
    final rootPath = await _offline.cacheRootPath();
    final resolved = catalog.summaries
        .map((summary) => _resolveCatalogSummarySprite(summary, rootPath))
        .toList(growable: false);
    return _rememberAllSummaries(resolved);
  }

  PokemonSummary _resolveCatalogSummarySprite(
    PokemonSummary summary,
    String rootPath,
  ) {
    final path = summary.localSpritePath;
    if (path != null && !path.startsWith('http') && !_isAbsolutePath(path)) {
      return summary.copyWith(localSpritePath: '$rootPath/$path');
    }
    if (path != null) {
      return summary;
    }
    return summary.copyWith(
      localSpritePath: summary.spriteUrl ?? _cdnConfig.spriteUrl(summary.id),
    );
  }

  List<PokemonSummary> _rememberAllSummaries(List<PokemonSummary> summaries) {
    _allSummaries = summaries;
    for (final summary in summaries) {
      _rememberSummary(summary);
    }
    return summaries;
  }
}

final dexRepository = DexRepository();
