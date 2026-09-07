import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/companion/companion_art.dart';
import '../features/game/journey_capability.dart';
import '../features/game/game_edition_repository.dart';
import '../features/dex/dex_filter.dart';
import '../features/dex/dex_browse_scope.dart';
import '../features/dex/dex_browse_session.dart';
import '../features/dex/dex_game_scope.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_progress.dart';
import '../features/dex/dex_repository.dart';
import '../features/dex/dex_scope.dart';
import '../features/dex/dex_settings_repository.dart';
import '../features/parser/hgss_format.dart';
import '../theme/error_text.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../navigation/tito_route_work.dart';
import '../theme/app_visual_style.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../widgets/dex_filter_banner.dart';
import '../widgets/dex_search_filter_sheet.dart';
import '../widgets/handheld_input.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';
import '../widgets/sticker_pressable.dart';
import '../widgets/tito_list_reveal.dart';
import '../widgets/tito_skeleton.dart';

class DexPage extends StatefulWidget {
  const DexPage({
    super.key,
    required this.journey,
    this.onManualDexMarkChanged,
    this.bootstrapOverride,
  });

  final CurrentJourney journey;
  final ValueChanged<CurrentJourney>? onManualDexMarkChanged;

  @visibleForTesting
  final Future<void> Function()? bootstrapOverride;

  @override
  State<DexPage> createState() => _DexPageState();
}

enum _DexMode { national, journey }

class _DexPageState extends State<DexPage> {
  static const _chunkSize = 18;

  late final ScrollController _scrollController;
  final DexBrowseScrollMemory _scrollMemory = DexBrowseScrollMemory();
  double? _pendingRestoreOffset;
  bool _restoreScheduled = false;
  bool _applyingScrollRestore = false;
  bool _bootstrapRequested = false;
  bool _bootstrapPending = true;

  int _loadedThrough = 0;
  bool _loadingChunk = false;
  bool _loadingJourney = false;
  _DexMode _mode = _DexMode.national;
  DexBrowseScope _browseScope = const DexBrowseScope.region(
    DexRegionalPokedex.national,
  );
  DexRegionalPokedex _region = DexRegionalPokedex.national;
  DexEncounterFilter _encounterFilter = DexEncounterFilter.all;
  List<PokemonSummary> _summaries = const [];
  List<PokemonSummary> _journeySummaries = const [];
  List<PokemonSummary> _referenceFilteredSummaries = const [];
  bool _loadingReferenceFilter = false;
  int _filterVisibleCount = 0;
  int _filterRequest = 0;
  final Map<DexRegionalPokedex, List<PokemonSummary>> _regionCache = {};
  final Map<int, List<PokemonSummary>> _generationCache = {};
  bool _loadingRegion = false;
  DexProgress _progress = const DexProgress(caughtIds: {}, seenIds: {});
  Set<int> _evolutionOrTradeMissingIds = const {};
  bool _loadingEvolutionOrTrade = false;
  int _availabilityRequest = 0;
  Set<int> _journeyIds = const {};
  String? _error;
  bool _showScrollToTop = false;

  /// Whether this page instance was opened by a reference drill-down. Such
  /// pages are pushed on top of the reference list; popping them clears the
  /// filter so the dex underneath (and later visits) show the full list.
  var _openedWithReferenceFilter = false;

  @override
  void initState() {
    super.initState();
    // Browse-session restoration is the single source of truth. Leaving
    // PageStorage enabled here creates a second writer whose teardown timing
    // can race the explicit session restoration below.
    _scrollController = ScrollController(keepScrollOffset: false)
      ..addListener(_onScroll);
    _openedWithReferenceFilter = dexFilterController.hasActiveFilter;
    gameEditionRepository.addListener(_onEditionChanged);
    dexFilterController.addListener(_onReferenceFilterChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_bootstrapAfterIncomingRoute());
    });
  }

  Future<void> _bootstrapAfterIncomingRoute() async {
    if (_bootstrapRequested) {
      return;
    }
    _bootstrapRequested = true;
    final canStart = await waitForIncomingRouteSettled(context);
    if (!canStart || !mounted) {
      return;
    }
    final override = widget.bootstrapOverride;
    if (override == null) {
      await _bootstrap();
    } else {
      await override();
    }
    if (!mounted) {
      return;
    }
    setState(() => _bootstrapPending = false);
  }

  @override
  void deactivate() {
    // Reveal memory is keyed by route + result set, so returning from detail
    // keeps the list settled while a genuine filter change can replay it.
    _saveBrowseSession();
    super.deactivate();
  }

  @override
  void dispose() {
    _saveBrowseSession();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    gameEditionRepository.removeListener(_onEditionChanged);
    dexFilterController.removeListener(_onReferenceFilterChanged);
    if (_openedWithReferenceFilter) {
      dexFilterController.clearFilter();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_applyingScrollRestore && _scrollController.hasClients) {
      _scrollMemory.offsetForSave(_scrollController.offset);
    }
    final show = _scrollController.hasClients && _scrollController.offset > 420;
    if (show != _showScrollToTop && mounted) {
      setState(() => _showScrollToTop = show);
    }
    _saveBrowseSession();
  }

  void _saveBrowseSession() {
    final offset = _scrollMemory.offsetForSave(
      _scrollController.hasClients ? _scrollController.offset : null,
    );
    DexBrowseSessionStore.save(
      DexBrowseSession(
        scrollOffset: offset,
        loadedThrough: _loadedThrough,
        filterVisibleCount: _filterVisibleCount,
        modeName: _mode.name,
        browseScope: _browseScope,
        encounterFilter: _encounterFilter,
        filterFingerprint: dexFilterFingerprint(
          dexFilterController.currentFilter,
        ),
      ),
    );
  }

  void _restoreScroll(double offset) {
    if (offset <= 0) return;
    _scrollMemory.rememberRestoreTarget(offset);
    _pendingRestoreOffset = offset;
    _scheduleScrollRestore();
  }

  void _scheduleScrollRestore() {
    if (_restoreScheduled || _pendingRestoreOffset == null) return;
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScheduled = false;
      if (!mounted || _pendingRestoreOffset == null) return;
      if (!_scrollController.hasClients) {
        _scheduleScrollRestore();
        return;
      }

      final target = _pendingRestoreOffset!;
      final maxExtent = _scrollController.position.maxScrollExtent;
      final contentCanStillGrow =
          _loadingChunk ||
          _loadingRegion ||
          _loadingReferenceFilter ||
          _loadingJourney ||
          (_encounterFilter == DexEncounterFilter.evolutionOrTrade &&
              _loadingEvolutionOrTrade);

      // If an async filter has not repopulated the grid yet, keep the original
      // target and retry when that load completes. Clamping now would turn a
      // valid deep-list offset into zero permanently.
      if (maxExtent + 0.5 < target && contentCanStillGrow) return;

      final resolved = target.clamp(0.0, maxExtent).toDouble();
      _applyingScrollRestore = true;
      _scrollController.jumpTo(resolved);
      _applyingScrollRestore = false;
      _scrollMemory.rememberRestoreTarget(resolved);
      _pendingRestoreOffset = null;
      _saveBrowseSession();
    });
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) {
      return;
    }
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(DexPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.journey != widget.journey) {
      _journeyIds = _resolveJourneyIds();
      setState(() {
        _progress = dexRepository.progressFor(
          widget.journey,
          manualDexMarks: !_isSaveLinked,
        );
      });
      unawaited(_refreshEvolutionOrTradeMissing());
    }
  }

  bool get _isSaveLinked => gameEditionRepository.edition.isSaveLinked;

  void _onEditionChanged() {
    setState(() {
      _progress = dexRepository.progressFor(
        widget.journey,
        manualDexMarks: !_isSaveLinked,
      );
    });
    unawaited(_refreshEvolutionOrTradeMissing());
  }

  void _onReferenceFilterChanged() {
    _loadReferenceFilter();
  }

  Future<void> _openSpeciesFilter() async {
    final picked = await showDexSearchFilterSheet(
      context,
      filter: dexFilterController.currentFilter,
      scope: _browseScope,
      encounter: _encounterFilter,
      journeyOnly: _mode == _DexMode.journey,
    );
    if (picked == null || !mounted) return;
    _pendingRestoreOffset = null;
    _scrollMemory.rememberRestoreTarget(0);
    if (picked.scope != _browseScope) _setBrowseScope(picked.scope);
    setState(() {
      _encounterFilter = picked.encounter;
    });
    dexFilterController.setFilter(picked.filter);
    await _setMode(picked.journeyOnly ? _DexMode.journey : _DexMode.national);
    if (!mounted) return;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _saveBrowseSession();
  }

  Future<void> _loadReferenceFilter() async {
    final request = ++_filterRequest;
    if (!dexFilterController.hasActiveFilter) {
      if (!mounted || request != _filterRequest) {
        return;
      }
      setState(() {
        _referenceFilteredSummaries = const [];
        _filterVisibleCount = 0;
        _loadingReferenceFilter = false;
      });
      return;
    }

    setState(() => _loadingReferenceFilter = true);
    try {
      final entries = await dexRepository.filterSummaries(
        dexFilterController.currentFilter,
        isCancelled: () => !mounted || request != _filterRequest,
      );
      if (!mounted || request != _filterRequest) {
        return;
      }
      setState(() {
        _referenceFilteredSummaries = entries;
        _filterVisibleCount = _chunkSize.clamp(0, entries.length);
        _loadingReferenceFilter = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || request != _filterRequest) {
        return;
      }
      setState(() {
        _error = _formatDexError(error);
        _loadingReferenceFilter = false;
        _referenceFilteredSummaries = const [];
      });
    }
  }

  Future<void> _bootstrap() async {
    try {
      final browseScope = await dexSettingsRepository.loadBrowseScope();
      final session = DexBrowseSessionStore.current;
      final restore =
          session != null &&
          session.matches(browseScope, dexFilterController.currentFilter);
      _journeyIds = _resolveJourneyIds();
      final progress = dexRepository.progressFor(
        widget.journey,
        manualDexMarks: !_isSaveLinked,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _progress = progress;
        _browseScope = browseScope;
        _region = browseScope.region ?? DexRegionalPokedex.national;
        if (restore) {
          _encounterFilter = session.encounterFilter;
          _mode = session.modeName == _DexMode.journey.name
              ? _DexMode.journey
              : _DexMode.national;
        }
      });
      unawaited(_refreshEvolutionOrTradeMissing());
      if (dexFilterController.hasActiveFilter) {
        await _loadReferenceFilter();
        if (restore && mounted) {
          setState(() {
            final restoredCount = session.filterVisibleCount <= 0
                ? _chunkSize
                : session.filterVisibleCount;
            _filterVisibleCount = restoredCount.clamp(
              0,
              _scopedReferenceEntries.length,
            );
          });
        }
      } else if (browseScope.generation != null) {
        await _loadGeneration(browseScope.generation!);
      } else if (_region != DexRegionalPokedex.national) {
        await _loadRegion(_region);
      } else {
        await _loadMore();
        if (restore) {
          while (mounted && _loadedThrough < session.loadedThrough) {
            await _loadMore();
          }
        }
      }
      if (restore && session.modeName == _DexMode.journey.name) {
        await _setMode(_DexMode.journey);
      }
      if (restore) {
        _restoreScroll(session.scrollOffset);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = _formatDexError(error));
    }
  }

  String _formatDexError(Object error) => formatUserFacingError(error);

  Set<int> _resolveJourneyIds() {
    final ids = <int>{};
    for (final member in widget.journey.party) {
      final id =
          member.speciesId ??
          speciesIdForName(member.species) ??
          knownSpeciesIdForLabel(member.species);
      if (id != null) {
        ids.add(id);
      }
    }
    final companionId =
        speciesIdForName(widget.journey.companion) ??
        knownSpeciesIdForLabel(widget.journey.companion);
    if (companionId != null) {
      ids.add(companionId);
    }
    return ids;
  }

  void _cycleManualMark(int id, DexEncounterStatus current) {
    if (_isSaveLinked || widget.onManualDexMarkChanged == null) {
      return;
    }

    var seenIds = widget.journey.manualDexSeenIds.toList();
    var caughtIds = widget.journey.manualDexCaughtIds.toList();

    switch (current) {
      case DexEncounterStatus.unknown:
        if (!seenIds.contains(id)) {
          seenIds = [...seenIds, id];
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppZh.dexManualMarkSeen)));
      case DexEncounterStatus.seen:
        if (!caughtIds.contains(id)) {
          caughtIds = [...caughtIds, id];
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppZh.dexManualMarkCaught)),
        );
      case DexEncounterStatus.caught:
        seenIds = seenIds.where((value) => value != id).toList();
        caughtIds = caughtIds.where((value) => value != id).toList();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppZh.dexManualMarkClear)));
    }

    final updated = widget.journey.copyWith(
      manualDexSeenIds: seenIds,
      manualDexCaughtIds: caughtIds,
    );
    widget.onManualDexMarkChanged!(updated);
    setState(() {
      _progress = dexRepository.progressFor(updated, manualDexMarks: true);
    });
    unawaited(_refreshEvolutionOrTradeMissing());
  }

  Future<void> _refreshEvolutionOrTradeMissing() async {
    final request = ++_availabilityRequest;
    if (mounted) {
      setState(() {
        _evolutionOrTradeMissingIds = const {};
        _loadingEvolutionOrTrade = true;
      });
    }
    Set<int> result;
    try {
      result = await dexRepository.evolutionOrTradeMissingIds(
        progress: _progress,
        edition: gameEditionRepository.edition,
      );
    } catch (_) {
      result = const {};
    }
    if (!mounted || request != _availabilityRequest) {
      return;
    }
    setState(() {
      _evolutionOrTradeMissingIds = result;
      _loadingEvolutionOrTrade = false;
      if (_encounterFilter == DexEncounterFilter.evolutionOrTrade &&
          result.isEmpty) {
        _encounterFilter = DexEncounterFilter.all;
      }
    });
    _scheduleScrollRestore();
  }

  void _loadMoreVisible() {
    if (dexFilterController.hasActiveFilter) {
      if (_filterVisibleCount >= _scopedReferenceEntries.length) {
        return;
      }
      setState(() {
        _filterVisibleCount = (_filterVisibleCount + _chunkSize).clamp(
          0,
          _scopedReferenceEntries.length,
        );
      });
      return;
    }
    if (_browseScope.generation == null &&
        _region == DexRegionalPokedex.national) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingChunk || _loadedThrough >= titodexMaxNationalDexId) {
      return;
    }

    setState(() => _loadingChunk = true);
    try {
      final start = _loadedThrough + 1;
      final end = (_loadedThrough + _chunkSize).clamp(
        1,
        titodexMaxNationalDexId,
      );
      final chunk = await dexRepository.getSummaryRange(start, end);
      if (!mounted) {
        return;
      }
      setState(() {
        _summaries = [..._summaries, ...chunk];
        _loadedThrough = end;
        _loadingChunk = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _formatDexError(error);
        _loadingChunk = false;
      });
    }
  }

  String get _revealReplayKey => [
    _mode.name,
    _browseScope.storageValue,
    _encounterFilter.name,
    dexFilterFingerprint(dexFilterController.currentFilter),
  ].join('|');

  /// TitoListReveal waits for route completion itself. Only row stagger belongs
  /// here, avoiding a second route-length delay after the shell has landed.
  Duration _cardRevealDelay(int index, int columns) {
    final row = index ~/ columns;
    final staggerMs = row.clamp(0, 7).toInt() * 42;
    return Duration(milliseconds: staggerMs);
  }

  Duration _headerRevealDelay() => Duration.zero;

  Future<void> _setMode(_DexMode mode) async {
    if (_mode == mode && mode == _DexMode.national) {
      return;
    }

    setState(() {
      _mode = mode;
      _error = null;
      if (mode == _DexMode.national) {
        _loadingJourney = false;
      } else {
        _loadingJourney = true;
      }
    });

    if (mode == _DexMode.national) {
      return;
    }

    try {
      final entries = await dexRepository.getSummariesForIds(_journeyIds);
      if (!mounted) {
        return;
      }
      setState(() {
        _journeySummaries = entries;
        _loadingJourney = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _formatDexError(error);
        _loadingJourney = false;
        _journeySummaries = const [];
      });
    }
  }

  void _setBrowseScope(DexBrowseScope scope) {
    final region = scope.region ?? DexRegionalPokedex.national;
    setState(() {
      _browseScope = scope;
      _region = region;
      _filterVisibleCount = _chunkSize.clamp(
        0,
        _referenceFilteredSummaries.where(scope.matches).length,
      );
      _mode = _DexMode.national;
      _error = null;
    });
    unawaited(dexSettingsRepository.saveBrowseScope(scope));
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    if (scope.generation != null) {
      _loadGeneration(scope.generation!);
    } else if (region != DexRegionalPokedex.national) {
      _loadRegion(region);
    } else if (_summaries.isEmpty) {
      _loadMore();
    }
  }

  Future<void> _loadGeneration(int generation) async {
    if (_generationCache.containsKey(generation) || _loadingRegion) return;
    setState(() => _loadingRegion = true);
    try {
      final entries = await dexRepository.getSummaryRange(
        1,
        titodexMaxNationalDexId,
      );
      final filtered = entries
          .where((entry) => entry.generation == generation)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _generationCache[generation] = filtered;
        _loadingRegion = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _formatDexError(error);
        _loadingRegion = false;
      });
    }
  }

  /// Regional scopes start mid-list (城都 = #152+), so waiting for the chunked
  /// national loader would leave the grid empty. Fetch the whole range —
  /// one summaries.json via the CDN fast path.
  Future<void> _loadRegion(DexRegionalPokedex region) async {
    if (_regionCache.containsKey(region) || _loadingRegion) {
      return;
    }
    setState(() => _loadingRegion = true);
    try {
      final (start, end) = DexScope.idRangeForScope(
        region,
        gameEdition: gameEditionRepository.edition,
      );
      final entries = await dexRepository.getSummaryRange(start, end);
      final filtered = entries
          .where((entry) => summaryMatchesRegionalPokedex(entry, region))
          .toList(growable: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _regionCache[region] = filtered;
        _loadingRegion = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _formatDexError(error);
        _loadingRegion = false;
      });
    }
  }

  List<PokemonSummary> get _visibleEntries {
    if (dexFilterController.hasActiveFilter) {
      final filtered = dexRepository.filterByEncounter(
        _scopedReferenceEntries,
        _progress,
        _encounterFilter,
        evolutionOrTradeIds: _evolutionOrTradeMissingIds,
      );
      if (_filterVisibleCount <= 0) {
        return filtered;
      }
      return filtered.take(_filterVisibleCount).toList(growable: false);
    }

    final Iterable<PokemonSummary> entries;
    if (_mode == _DexMode.journey) {
      entries = _journeySummaries.where(_browseScope.matches);
    } else if (_browseScope.generation != null) {
      entries = _generationCache[_browseScope.generation] ?? const [];
    } else if (_region != DexRegionalPokedex.national &&
        _regionCache.containsKey(_region)) {
      entries = _regionCache[_region]!;
    } else {
      entries = _summaries.where(_browseScope.matches);
    }

    return dexRepository.filterByEncounter(
      entries,
      _progress,
      _encounterFilter,
      evolutionOrTradeIds: _evolutionOrTradeMissingIds,
    );
  }

  List<PokemonSummary> get _scopedReferenceEntries =>
      _referenceFilteredSummaries
          .where(_browseScope.matches)
          .where(
            (entry) =>
                _mode != _DexMode.journey || _journeyIds.contains(entry.id),
          )
          .toList(growable: false);

  Iterable<PokemonSummary> get _primaryScopeEntries {
    final generation = _browseScope.generation;
    if (generation != null) return _generationCache[generation] ?? const [];
    if (_region != DexRegionalPokedex.national) {
      return _regionCache[_region] ?? const [];
    }
    return _summaries;
  }

  DexScopeStats get _scopeStats {
    final legacyScope = regionalScopeFromPokedex(_region);
    if (_browseScope.generation == null &&
        (_region == DexRegionalPokedex.national ||
            _region == DexRegionalPokedex.johto ||
            _region == DexRegionalPokedex.kanto)) {
      return _progress.statsFor(
        legacyScope,
        evolutionOrTradeIds: _evolutionOrTradeMissingIds,
      );
    }
    final visible = _primaryScopeEntries;
    var caught = 0;
    var seenOnly = 0;
    var evolutionOrTradeOnly = 0;
    for (final entry in visible) {
      final status = _progress.statusFor(entry.id);
      if (status == DexEncounterStatus.caught) {
        caught++;
      } else if (status == DexEncounterStatus.seen) {
        seenOnly++;
      }
      if (_evolutionOrTradeMissingIds.contains(entry.id)) {
        evolutionOrTradeOnly++;
      }
    }
    final total = visible.length;
    return DexScopeStats(
      scope: legacyScope,
      total: total,
      caught: caught,
      seenOnly: seenOnly,
      unseen: total - caught - seenOnly,
      evolutionOrTradeOnly: evolutionOrTradeOnly,
    );
  }

  String _emptyMessageForMode() {
    if (_mode == _DexMode.journey) {
      return _encounterFilter == DexEncounterFilter.all
          ? AppZh.dexJourneyEmpty
          : AppZh.dexFilterEmpty;
    }
    return switch (_encounterFilter) {
      DexEncounterFilter.caught => AppZh.dexCaughtEmpty,
      DexEncounterFilter.seen => AppZh.dexSeenEmpty,
      DexEncounterFilter.unseen => AppZh.dexUnknown,
      DexEncounterFilter.evolutionOrTrade => AppZh.dexFilterEmpty,
      DexEncounterFilter.all => AppZh.dexFilterEmpty,
    };
  }

  int get _filteredTotalCount {
    if (!dexFilterController.hasActiveFilter) {
      return 0;
    }
    return dexRepository
        .filterByEncounter(
          _scopedReferenceEntries,
          _progress,
          _encounterFilter,
          evolutionOrTradeIds: _evolutionOrTradeMissingIds,
        )
        .length;
  }

  /// Region progress line, e.g. `#152–251 · 已见 6 / 已捕 6 / 共 100`.
  String? get _scopeProgressLine {
    if (_mode != _DexMode.national) {
      return null;
    }
    final stats = _scopeStats;
    final generation = _browseScope.generation;
    if (generation != null) {
      return AppZh.dexGenerationProgress(
        generation,
        stats.seen,
        stats.caught,
        stats.total,
      );
    }
    if (_region == DexRegionalPokedex.national) return null;
    final (start, end) = DexScope.idRangeForScope(
      _region,
      gameEdition: gameEditionRepository.edition,
    );
    return AppZh.dexRegionProgress(
      start,
      end,
      stats.seen,
      stats.caught,
      stats.total,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleEntries;
    final columns = DeviceLayout.dexGridColumns(context);
    final aspectRatio = DeviceLayout.dexCardAspectRatio(context);
    final loading =
        _bootstrapPending ||
        (dexFilterController.hasActiveFilter
            ? _loadingReferenceFilter
            : _mode == _DexMode.national
            ? (_loadingChunk || _loadingRegion)
            : _loadingJourney);
    final padding = DeviceLayout.pagePadding(context);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                padding.top,
                padding.right,
                0,
              ),
              child: _DexTopBar(onSearch: _openSpeciesFilter),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent - 240) {
                    _loadMoreVisible();
                  }
                  return false;
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        padding.left,
                        6,
                        padding.right,
                        8,
                      ),
                      // Edition is fixed page chrome. Async scope/filter content
                      // reveals below it after the route has settled.
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SecondaryPageSubtitle(
                              text:
                                  gameEditionRepository.edition.selectedLabel,
                            ),
                            const SizedBox(height: 12),
                            TitoListReveal(
                              key: const ValueKey('dex-header-reveal'),
                              delay: _headerRevealDelay(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Square handheld: keep the top area short — at most one
                                  // info line (region progress when 城都/关东 is active).
                                  if (_scopeProgressLine != null) ...[
                                    Text(
                                      _scopeProgressLine!,
                                      style: SecondaryTypography.onPage(
                                        context,
                                      ).body14,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: squareGap(context)),
                                  ] else if (!DeviceLayout.useSquareDashboard(
                                    context,
                                  )) ...[
                                    Text(
                                      AppZh.dexScopeNote,
                                      style: SecondaryTypography.onPage(
                                        context,
                                      ).body14,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: squareGap(context)),
                                  ],
                                  if (dexFilterController.hasActiveFilter) ...[
                                    DexFilterBanner(
                                      filter: dexFilterController.currentFilter,
                                      loading: _loadingReferenceFilter,
                                      onClear: dexFilterController.clearFilter,
                                    ),
                                    SizedBox(height: squareGap(context)),
                                  ],
                                  Text(
                                    [
                                      if (_mode == _DexMode.journey)
                                        AppZh.dexTabJourney,
                                      _browseScope.titleZh,
                                      if (_encounterFilter !=
                                          DexEncounterFilter.all)
                                        switch (_encounterFilter) {
                                          DexEncounterFilter.caught =>
                                            AppZh.dexFilterCaught,
                                          DexEncounterFilter.seen =>
                                            AppZh.dexEncounterSeen,
                                          DexEncounterFilter.unseen =>
                                            AppZh.dexEncounterUnseen,
                                          DexEncounterFilter.evolutionOrTrade =>
                                            AppZh.dexEncounterEvolutionOrTrade,
                                          DexEncounterFilter.all =>
                                            AppZh.dexFilterAll,
                                        },
                                    ].join(' · '),
                                    style: SecondaryTypography.onPage(
                                      context,
                                    ).small12,
                                  ),
                                  SizedBox(height: squareGap(context)),
                                  if (_error != null)
                                    StickerCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            AppZh.dexLoadFailed,
                                            style: SecondaryTypography
                                                .onCard
                                                .body14
                                                .copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _error!,
                                            style: SecondaryTypography
                                                .onCard
                                                .small12
                                                .copyWith(
                                                  color: TitoColors.mutedInk,
                                                  height: 1.45,
                                                ),
                                          ),
                                          const SizedBox(height: 12),
                                          FilledButton(
                                            onPressed: () {
                                              setState(() => _error = null);
                                              if (_mode == _DexMode.national) {
                                                _loadMore();
                                              } else {
                                                _setMode(_DexMode.journey);
                                              }
                                            },
                                            child: Text(AppZh.dexRetry),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (visible.isEmpty && loading)
                                    LayoutBuilder(
                                      builder: (context, constraints) =>
                                          TitoDexGridSkeleton(
                                            crossAxisCount: columns,
                                            childAspectRatio: aspectRatio,
                                            itemCount: _skeletonTileCount(
                                              context,
                                              width: constraints.maxWidth,
                                              columns: columns,
                                              aspectRatio: aspectRatio,
                                            ),
                                          ),
                                    )
                                  else if (visible.isEmpty)
                                    StickerCard(
                                      child: Text(
                                        _emptyMessageForMode(),
                                        style: SecondaryTypography.onCard.body14
                                            .copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (visible.isNotEmpty && _error == null)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          padding.left,
                          0,
                          padding.right,
                          0,
                        ),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                                childAspectRatio: aspectRatio,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final entry = visible[index];
                            final status = dexRepository.statusFor(
                              entry.id,
                              _progress,
                            );
                            return TitoListReveal(
                              key: ValueKey<String>(
                                'dex-grid-entry-${entry.id}-${entry.formKey ?? ''}',
                              ),
                              replayKey: _revealReplayKey,
                              delay: _cardRevealDelay(index, columns),
                              child: PokemonMiniCard(
                                summary: entry,
                                status: status,
                                compact: DeviceLayout.isCompact(context),
                                onTap: () {
                                  _saveBrowseSession();
                                  final detailFuture = dexRepository.getDetail(
                                    entry.id,
                                  );
                                  context.push(
                                    Uri(
                                      path: '/dex/${entry.id}',
                                      queryParameters: {
                                        if (entry.formKey != null)
                                          'form': entry.formKey!,
                                      },
                                    ).toString(),
                                    extra: PokemonDetailTransition(
                                      summary: entry,
                                      detailFuture: detailFuture,
                                    ),
                                  );
                                },
                                onLongPress: _isSaveLinked
                                    ? null
                                    : () => _cycleManualMark(entry.id, status),
                              ),
                            );
                          }, childCount: visible.length),
                        ),
                      ),
                    if (_mode == _DexMode.national &&
                        _loadingChunk &&
                        visible.isNotEmpty &&
                        !dexFilterController.hasActiveFilter)
                      SliverPadding(
                        padding: padding.copyWith(top: 8),
                        sliver: SliverToBoxAdapter(
                          child: TitoDexGridSkeleton(
                            crossAxisCount: columns,
                            itemCount: columns,
                            childAspectRatio: aspectRatio,
                          ),
                        ),
                      ),
                    if (dexFilterController.hasActiveFilter &&
                        _filterVisibleCount < _filteredTotalCount)
                      SliverPadding(
                        padding: padding.copyWith(top: 8, bottom: 4),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            AppZh.dexLoadingProgress(
                              _filterVisibleCount,
                              _filteredTotalCount,
                            ),
                            textAlign: TextAlign.center,
                            style: SecondaryTypography.onPage(context).body14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: padding.right,
          bottom: 16,
          child: IgnorePointer(
            ignoring: !_showScrollToTop,
            child: AnimatedOpacity(
              opacity: _showScrollToTop ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: _ScrollToTopButton(onTap: _scrollToTop),
            ),
          ),
        ),
      ],
    );
  }

  double squareGap(BuildContext context) =>
      DeviceLayout.useSquareDashboard(context) ? 6 : 8;

  /// Enough skeleton tiles to fill the viewport (at least two rows, capped so
  /// an unusually tall window does not build hundreds of placeholders), so a
  /// slow first load never shows a short stub of six cards above an empty
  /// page. The list scrolls, so overshooting by a row is harmless.
  int _skeletonTileCount(
    BuildContext context, {
    required double width,
    required int columns,
    required double aspectRatio,
  }) {
    if (!width.isFinite || width <= 0 || columns <= 0 || aspectRatio <= 0) {
      return columns * 2;
    }
    const spacing = 6.0;
    final tileWidth = (width - spacing * (columns - 1)) / columns;
    final rowExtent = tileWidth / aspectRatio + spacing;
    final viewport = MediaQuery.sizeOf(context).height;
    final rows = (viewport / rowExtent).ceil().clamp(2, 12);
    return rows * columns;
  }
}

/// Scroll-to-top action. Trainer's Journal / Solid Plastic keep the
/// soft-yellow sticker disc with a themed stroke; Flat UI uses the stock
/// small Material FAB so it matches the rest of the Material surface.
class _ScrollToTopButton extends StatelessWidget {
  const _ScrollToTopButton({required this.onTap});

  final VoidCallback onTap;

  static String get _label => AppZh.dexScrollToTop;

  @override
  Widget build(BuildContext context) {
    if (appVisualStyle.usesFlatUi) {
      return FloatingActionButton.small(
        heroTag: null,
        tooltip: _label,
        onPressed: onTap,
        child: const Icon(Icons.vertical_align_top_rounded),
      );
    }
    final side = appVisualStyle.usesSolidPlastic
        ? BorderSide(
            color: Colors.white.withValues(alpha: 0.8),
            width: TitoBorders.glass,
          )
        : const BorderSide(color: TitoColors.ink, width: TitoBorders.card);
    return Semantics(
      button: true,
      label: _label,
      child: Material(
        color: TitoColors.softYellow,
        shape: CircleBorder(side: side),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.vertical_align_top_rounded,
              color: TitoColors.deepBlue,
            ),
          ),
        ),
      ),
    );
  }
}

class _DexTopBar extends StatelessWidget {
  const _DexTopBar({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SecondaryPageAppBar(title: AppZh.navDex, showSettings: false),
        ),
        _DexTopBarAction(
          icon: Icons.search_rounded,
          label: AppZh.dexFilterAction,
          onTap: onSearch,
        ),
      ],
    );
  }
}

/// Compact search-and-filter entry for the dex top bar.
class _DexTopBarAction extends StatelessWidget {
  const _DexTopBarAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  static const _height = 34.0;

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DeviceLayout.rMd(context));
    final scheme = Theme.of(context).colorScheme;
    final shellColor = appVisualStyle.usesFlatUi
        ? scheme.primary
        : TitoColors.card;
    // Outline pill on the page header: card-weight stroke in the cream
    // themes, plastic hairline in Solid Plastic (colour stays the shell tint
    // so the label and icon read as one control).
    final strokeWidth = appVisualStyle.usesSolidPlastic
        ? TitoBorders.glass
        : TitoBorders.card;
    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: radius,
      child: StickerPressable(
        borderRadius: radius,
        // Outline pill on the gradient header — sink physics only.
        ownShadow: false,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Container(
              height: _height,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: shellColor, width: strokeWidth),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: shellColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: SecondaryTypography.onPage(context).small12.copyWith(
                      color: shellColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
