import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/companion/companion_art.dart';
import '../features/game/journey_capability.dart';
import '../features/game/game_edition_repository.dart';
import '../features/dex/dex_filter.dart';
import '../features/dex/dex_game_scope.dart';
import '../features/dex/dex_regional_picker.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_progress.dart';
import '../features/dex/dex_repository.dart';
import '../features/dex/dex_scope.dart';
import '../features/parser/hgss_format.dart';
import '../theme/error_text.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../navigation/back_navigation.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_font_scale.dart';
import '../widgets/dex_filter_banner.dart';
import '../widgets/handheld_input.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/sticker_card.dart';
import '../widgets/tito_list_reveal.dart';
import '../widgets/tito_skeleton.dart';
import '../widgets/tito_animated_size_switcher.dart';

class DexPage extends StatefulWidget {
  const DexPage({
    super.key,
    required this.journey,
    this.onManualDexMarkChanged,
  });

  final CurrentJourney journey;
  final ValueChanged<CurrentJourney>? onManualDexMarkChanged;

  @override
  State<DexPage> createState() => _DexPageState();
}

enum _DexMode { national, journey }

class _DexPageState extends State<DexPage> {
  static const _chunkSize = 18;

  late final DateTime _openedAt;

  int _loadedThrough = 0;
  bool _loadingChunk = false;
  bool _loadingJourney = false;
  _DexMode _mode = _DexMode.national;
  DexRegionalPokedex _region = DexRegionalPokedex.national;
  DexEncounterFilter _encounterFilter = DexEncounterFilter.all;
  List<PokemonSummary> _summaries = const [];
  List<PokemonSummary> _journeySummaries = const [];
  List<PokemonSummary> _referenceFilteredSummaries = const [];
  bool _loadingReferenceFilter = false;
  int _filterVisibleCount = 0;
  final Map<DexRegionalPokedex, List<PokemonSummary>> _regionCache = {};
  bool _loadingRegion = false;
  DexProgress _progress = const DexProgress(caughtIds: {}, seenIds: {});
  Set<int> _journeyIds = const {};
  String? _error;

  /// Whether this page instance was opened by a reference drill-down. Such
  /// pages are pushed on top of the reference list; popping them clears the
  /// filter so the dex underneath (and later visits) show the full list.
  var _openedWithReferenceFilter = false;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _openedWithReferenceFilter = dexFilterController.hasActiveFilter;
    gameEditionRepository.addListener(_onEditionChanged);
    dexFilterController.addListener(_onReferenceFilterChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    gameEditionRepository.removeListener(_onEditionChanged);
    dexFilterController.removeListener(_onReferenceFilterChanged);
    if (_openedWithReferenceFilter) {
      dexFilterController.clearFilter();
    }
    super.dispose();
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
  }

  void _onReferenceFilterChanged() {
    _loadReferenceFilter();
  }

  Future<void> _loadReferenceFilter() async {
    if (!dexFilterController.hasActiveFilter) {
      if (!mounted) {
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
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _referenceFilteredSummaries = entries;
        _filterVisibleCount = _chunkSize.clamp(0, entries.length);
        _loadingReferenceFilter = false;
        _mode = _DexMode.national;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
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
      _journeyIds = _resolveJourneyIds();
      final progress = dexRepository.progressFor(
        widget.journey,
        manualDexMarks: !_isSaveLinked,
      );
      if (!mounted) {
        return;
      }
      setState(() => _progress = progress);
      if (dexFilterController.hasActiveFilter) {
        await _loadReferenceFilter();
      } else {
        await _loadMore();
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
        ).showSnackBar(const SnackBar(content: Text(AppZh.dexManualMarkSeen)));
      case DexEncounterStatus.seen:
        if (!caughtIds.contains(id)) {
          caughtIds = [...caughtIds, id];
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppZh.dexManualMarkCaught)),
        );
      case DexEncounterStatus.caught:
        seenIds = seenIds.where((value) => value != id).toList();
        caughtIds = caughtIds.where((value) => value != id).toList();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppZh.dexManualMarkClear)));
    }

    final updated = widget.journey.copyWith(
      manualDexSeenIds: seenIds,
      manualDexCaughtIds: caughtIds,
    );
    widget.onManualDexMarkChanged!(updated);
    setState(() {
      _progress = dexRepository.progressFor(updated, manualDexMarks: true);
    });
  }

  void _loadMoreVisible() {
    if (dexFilterController.hasActiveFilter) {
      if (_filterVisibleCount >= _referenceFilteredSummaries.length) {
        return;
      }
      setState(() {
        _filterVisibleCount = (_filterVisibleCount + _chunkSize).clamp(
          0,
          _referenceFilteredSummaries.length,
        );
      });
      return;
    }
    _loadMore();
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

  Duration _cardRevealDelay(int index, int columns) {
    // Let the page shell finish first. If data arrives later than the shell,
    // cards start immediately while preserving their row-by-row cadence.
    final elapsedMs = DateTime.now().difference(_openedAt).inMilliseconds;
    final shellWaitMs = math.max(0, 620 - elapsedMs);
    final row = index ~/ columns;
    final staggerMs = math.min(row, 7) * 42;
    return Duration(milliseconds: shellWaitMs + staggerMs);
  }

  /// Header text/tool bars reveal just as the shell expansion lands — a beat
  /// ahead of the first card row.
  Duration _headerRevealDelay() {
    final elapsedMs = DateTime.now().difference(_openedAt).inMilliseconds;
    return Duration(milliseconds: math.max(0, 440 - elapsedMs));
  }

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

  Future<void> _onNationalTabTap() async {
    if (_mode != _DexMode.national) {
      await _setMode(_DexMode.national);
      return;
    }
    if (!mounted) {
      return;
    }
    final picked = await showRegionalPokedexPicker(
      context,
      selected: _region,
      gameEdition: gameEditionRepository.edition,
    );
    if (picked != null && picked != _region) {
      _setRegion(picked);
    }
  }

  void _setRegion(DexRegionalPokedex region) {
    setState(() {
      _region = region;
      _mode = _DexMode.national;
      _error = null;
    });
    if (region != DexRegionalPokedex.national) {
      _loadRegion(region);
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
        _referenceFilteredSummaries,
        _progress,
        _encounterFilter,
      );
      if (_filterVisibleCount <= 0) {
        return filtered;
      }
      return filtered.take(_filterVisibleCount).toList(growable: false);
    }

    final Iterable<PokemonSummary> entries;
    if (_mode == _DexMode.journey) {
      entries = _journeySummaries;
    } else if (_region != DexRegionalPokedex.national &&
        _regionCache.containsKey(_region)) {
      entries = _regionCache[_region]!;
    } else {
      entries = _summaries.where(
        (entry) => summaryMatchesRegionalPokedex(entry, _region),
      );
    }

    return dexRepository.filterByEncounter(
      entries,
      _progress,
      _encounterFilter,
    );
  }

  DexScopeStats get _scopeStats {
    final legacyScope = regionalScopeFromPokedex(_region);
    if (_region == DexRegionalPokedex.national ||
        _region == DexRegionalPokedex.johto ||
        _region == DexRegionalPokedex.kanto) {
      return _progress.statsFor(legacyScope);
    }
    final visible = _summaries.where(
      (entry) => summaryMatchesRegionalPokedex(entry, _region),
    );
    var caught = 0;
    var seenOnly = 0;
    for (final entry in visible) {
      final status = _progress.statusFor(entry.id);
      if (status == DexEncounterStatus.caught) {
        caught++;
      } else if (status == DexEncounterStatus.seen) {
        seenOnly++;
      }
    }
    final total = visible.length;
    return DexScopeStats(
      scope: legacyScope,
      total: total,
      caught: caught,
      seenOnly: seenOnly,
      unseen: total - caught - seenOnly,
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
      DexEncounterFilter.all => AppZh.dexJourneyEmpty,
    };
  }

  int get _filteredTotalCount {
    if (!dexFilterController.hasActiveFilter) {
      return 0;
    }
    return dexRepository
        .filterByEncounter(
          _referenceFilteredSummaries,
          _progress,
          _encounterFilter,
        )
        .length;
  }

  /// Region progress line, e.g. `#152–251 · 已见 6 / 已捕 6 / 共 100`.
  String? get _regionProgressLine {
    if (_mode != _DexMode.national || _region == DexRegionalPokedex.national) {
      return null;
    }
    final stats = _scopeStats;
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
    final loading = dexFilterController.hasActiveFilter
        ? _loadingReferenceFilter
        : _mode == _DexMode.national
        ? (_loadingChunk || _loadingRegion)
        : _loadingJourney;
    final padding = DeviceLayout.pagePadding(context);

    return TitoFontScale(
      multiplier: 1.0,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 240) {
            _loadMoreVisible();
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: padding.copyWith(bottom: 8),
              // The header block fades in on the same clock as the grid
              // cards below, so the text no longer pops in ahead of them.
              sliver: SliverToBoxAdapter(
                child: TitoListReveal(
                  key: const ValueKey('dex-header-reveal'),
                  delay: _headerRevealDelay(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DexTopBar(
                        gameTitle: gameEditionRepository.edition.labelZh,
                        onSearch: () => context.push('/search'),
                        onReference: () => _showReferenceMenu(context),
                      ),
                      SizedBox(height: squareGap(context)),
                      // Square handheld: keep the top area short — at most one
                      // info line (region progress when 城都/关东 is active).
                      if (_regionProgressLine != null) ...[
                        Text(
                          _regionProgressLine!,
                          style: SecondaryTypography.onGradient.body14,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: squareGap(context)),
                      ] else if (!DeviceLayout.useSquareDashboard(context)) ...[
                        Text(
                          AppZh.dexScopeNote,
                          style: SecondaryTypography.onGradient.body14,
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
                      _DexScopeBar(
                        mode: _mode,
                        region: _region,
                        scopeStats: _scopeStats,
                        journeyCount: _journeyIds.length,
                        onModeSelected: _setMode,
                        onNationalRegionPicker: _onNationalTabTap,
                      ),
                      // Keyed encounter-filter swap without a custom transition.
                      TitoAnimatedSizeSwitcher(
                        switchKey: ValueKey<bool>(_mode == _DexMode.national),
                        child: _mode == _DexMode.national
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(height: squareGap(context)),
                                  _DexEncounterFilterBar(
                                    filter: _encounterFilter,
                                    onSelected: (filter) {
                                      setState(() => _encounterFilter = filter);
                                    },
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      SizedBox(height: squareGap(context)),
                      if (_error != null)
                        StickerCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                AppZh.dexLoadFailed,
                                style: SecondaryTypography.onCard.body14
                                    .copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: SecondaryTypography.onCard.small12
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
                                child: const Text(AppZh.dexRetry),
                              ),
                            ],
                          ),
                        )
                      else if (visible.isEmpty && loading)
                        TitoDexGridSkeleton(
                          crossAxisCount: columns,
                          childAspectRatio: aspectRatio,
                        )
                      else if (visible.isEmpty)
                        StickerCard(
                          child: Text(
                            _emptyMessageForMode(),
                            style: SecondaryTypography.onCard.body14.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (visible.isNotEmpty && _error == null)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, 0),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: aspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final entry = visible[index];
                    final status = dexRepository.statusFor(entry.id, _progress);
                    return TitoListReveal(
                      key: ValueKey<String>('dex-grid-entry-${entry.id}'),
                      delay: _cardRevealDelay(index, columns),
                      child: PokemonMiniCard(
                        summary: entry,
                        status: status,
                        compact: DeviceLayout.isCompact(context),
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
                    style: SecondaryTypography.onGradient.body14.copyWith(
                      color: TitoColors.skyBlue,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double squareGap(BuildContext context) =>
      DeviceLayout.useSquareDashboard(context) ? 6 : 8;

  void _showReferenceMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.sports_martial_arts_rounded),
                title: Text(AppZh.dexReferenceMoves),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/dex/moves');
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: Text(AppZh.dexReferenceAbilities),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/dex/abilities');
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DexTopBar extends StatelessWidget {
  const _DexTopBar({
    required this.gameTitle,
    required this.onSearch,
    required this.onReference,
  });

  final String gameTitle;
  final VoidCallback onSearch;
  final VoidCallback onReference;

  @override
  Widget build(BuildContext context) {
    final backIcon = DeviceLayout.backIconSize(context);

    return Row(
      children: [
        Expanded(
          child: HandheldFocusDecorator(
            onActivate: () => TitoBackNavigation.navigateBack(context, '/dex'),
            child: TextButton.icon(
              onPressed: () => TitoBackNavigation.navigateBack(context, '/dex'),
              style: TextButton.styleFrom(
                foregroundColor: TitoColors.card,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
              ),
              icon: Icon(
                Icons.arrow_back_rounded,
                size: backIcon,
                color: TitoColors.card,
              ),
              label: Text(
                '${AppZh.navDex} · $gameTitle',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SecondaryTypography.onGradient.title.copyWith(
                  letterSpacing: -0.5,
                  shadows: const [
                    Shadow(color: Color(0x4018283B), offset: Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ),
        ),
        _DexTopBarAction(
          icon: Icons.search_rounded,
          label: AppZh.navSearch,
          onTap: onSearch,
        ),
        const SizedBox(width: 6),
        _DexTopBarAction(
          icon: Icons.menu_book_rounded,
          label: AppZh.dexReferenceTitle,
          onTap: onReference,
        ),
      ],
    );
  }
}

/// Shared pill for the dex top bar — one height, padding, and icon size so
/// 搜索 and 常用资料 read as siblings.
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
    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: radius,
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
              border: Border.all(color: TitoColors.card, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: TitoColors.card, size: 16),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: SecondaryTypography.onGradient.small12.copyWith(
                    color: TitoColors.card,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DexScopeBar extends StatelessWidget {
  const _DexScopeBar({
    required this.mode,
    required this.region,
    required this.scopeStats,
    required this.journeyCount,
    required this.onModeSelected,
    required this.onNationalRegionPicker,
  });

  final _DexMode mode;
  final DexRegionalPokedex region;
  final DexScopeStats scopeStats;
  final int journeyCount;
  final ValueChanged<_DexMode> onModeSelected;
  final VoidCallback onNationalRegionPicker;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DexModeTab(
            selected: mode == _DexMode.national,
            title: AppZh.dexRegionalDexTitle(regionalPokedexLabelZh(region)),
            subtitle: AppZh.dexScopeProgress(
              scopeStats.caught,
              scopeStats.seen,
              scopeStats.total,
            ),
            count: scopeStats.total,
            showRegionPicker: true,
            regionPickerActive: mode == _DexMode.national,
            onTap: () => onModeSelected(_DexMode.national),
            onRegionPickerTap: onNationalRegionPicker,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _DexModeTab(
            selected: mode == _DexMode.journey,
            title: AppZh.dexTabJourney,
            subtitle: AppZh.teamSubtitle(journeyCount),
            count: journeyCount,
            onTap: () => onModeSelected(_DexMode.journey),
          ),
        ),
      ],
    );
  }
}

class _DexEncounterFilterBar extends StatelessWidget {
  const _DexEncounterFilterBar({
    required this.filter,
    required this.onSelected,
  });

  final DexEncounterFilter filter;
  final ValueChanged<DexEncounterFilter> onSelected;

  static const _order = [
    DexEncounterFilter.all,
    DexEncounterFilter.seen,
    DexEncounterFilter.caught,
    DexEncounterFilter.unseen,
  ];

  static const _labels = {
    DexEncounterFilter.all: AppZh.dexFilterAll,
    DexEncounterFilter.seen: AppZh.dexFilterSeen,
    DexEncounterFilter.caught: AppZh.dexFilterCaught,
    DexEncounterFilter.unseen: AppZh.dexFilterUnseen,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final entry in _order) ...[
          if (entry != _order.first) const SizedBox(width: 5),
          Expanded(
            child: _DexFilterChip(
              label: _labels[entry]!,
              selected: filter == entry,
              onTap: () => onSelected(entry),
            ),
          ),
        ],
      ],
    );
  }
}

class _DexModeTab extends StatelessWidget {
  const _DexModeTab({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.onTap,
    this.showRegionPicker = false,
    this.regionPickerActive = false,
    this.onRegionPickerTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final int count;
  final VoidCallback onTap;
  final bool showRegionPicker;
  final bool regionPickerActive;
  final VoidCallback? onRegionPickerTap;

  @override
  Widget build(BuildContext context) {
    final radius = DeviceLayout.rMd(context);
    final square = DeviceLayout.useSquareDashboard(context);
    final openPicker = showRegionPicker && regionPickerActive && selected;

    return HandheldFocusDecorator(
      onActivate: openPicker ? (onRegionPickerTap ?? onTap) : onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: openPicker ? onRegionPickerTap : onTap,
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(radius),
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? TitoColors.softYellow : TitoColors.card,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: TitoColors.ink, width: 2),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: square ? 5 : 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SecondaryTypography.onCard.body14.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (openPicker)
                      const Padding(
                        padding: EdgeInsets.only(right: 2),
                        child: Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 18,
                          color: TitoColors.ink,
                        ),
                      ),
                    Text(
                      '$count',
                      style: SecondaryTypography.onCard.meta14.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SecondaryTypography.onCard.meta14.copyWith(
                    fontWeight: FontWeight.w600,
                    color: TitoColors.mutedInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DexFilterChip extends StatelessWidget {
  const _DexFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? TitoColors.softYellow : TitoColors.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: TitoColors.ink, width: 2),
            ),
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: SecondaryTypography.onCard.small12.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.2,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
