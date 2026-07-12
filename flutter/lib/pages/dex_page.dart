import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/companion/companion_art.dart';
import '../features/game/game_edition.dart';
import '../features/game/game_edition_repository.dart';
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
import '../navigation/back_navigation.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_font_scale.dart';
import '../widgets/handheld_input.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/sticker_card.dart';
import '../widgets/tito_skeleton.dart';

class DexPage extends StatefulWidget {
  const DexPage({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  State<DexPage> createState() => _DexPageState();
}

enum _DexMode { national, journey }

class _DexPageState extends State<DexPage> {
  static const _chunkSize = 18;

  int _loadedThrough = 0;
  bool _loadingChunk = false;
  bool _loadingJourney = false;
  _DexMode _mode = _DexMode.national;
  DexRegionalPokedex _region = DexRegionalPokedex.national;
  GameEdition _gameEdition = defaultGameEdition;
  DexEncounterFilter _encounterFilter = DexEncounterFilter.all;
  List<PokemonSummary> _summaries = const [];
  List<PokemonSummary> _journeySummaries = const [];
  final Map<DexRegionalPokedex, List<PokemonSummary>> _regionCache = {};
  bool _loadingRegion = false;
  DexProgress _progress = const DexProgress(caughtIds: {}, seenIds: {});
  Set<int> _journeyIds = const {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDefaultGameVersion();
    _bootstrap();
  }

  Future<void> _loadDefaultGameVersion() async {
    final edition = await dexSettingsRepository.loadDefaultGameEdition();
    if (!mounted) {
      return;
    }
    setState(() {
      _gameEdition = edition;
      _region = edition.defaultRegionalPokedex;
    });
  }

  Future<void> _bootstrap() async {
    try {
      _journeyIds = _resolveJourneyIds();
      final progress = dexRepository.progressFor(widget.journey);
      if (!mounted) {
        return;
      }
      setState(() => _progress = progress);
      await _loadMore();
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
      final id = member.speciesId ??
          speciesIdForName(member.species) ??
          knownSpeciesIdForLabel(member.species);
      if (id != null) {
        ids.add(id);
      }
    }
    final companionId = speciesIdForName(widget.journey.companion) ??
        knownSpeciesIdForLabel(widget.journey.companion);
    if (companionId != null) {
      ids.add(companionId);
    }
    return ids;
  }

  Future<void> _loadMore() async {
    if (_loadingChunk || _loadedThrough >= titodexMaxNationalDexId) {
      return;
    }

    setState(() => _loadingChunk = true);
    try {
      final start = _loadedThrough + 1;
      final end = (_loadedThrough + _chunkSize).clamp(1, titodexMaxNationalDexId);
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

  Future<void> _setMode(_DexMode mode) async {
    if (_mode == mode && mode == _DexMode.national) {
      // Re-activating the selected national tab cycles the regional scope —
      // reachable with a plain A-press on the D-pad (no tiny dropdown needed).
      final scopes = DexRegionalPokedex.values;
      final next = scopes[(scopes.indexOf(_region) + 1) % scopes.length];
      _setRegion(next);
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
        gameEdition: _gameEdition,
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

    return dexRepository.filterSummaries(
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
    final visible = _summaries
        .where((entry) => summaryMatchesRegionalPokedex(entry, _region));
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

  /// Region progress line, e.g. `#152–251 · 已见 6 / 已捕 6 / 共 100`.
  String? get _regionProgressLine {
    if (_mode != _DexMode.national || _region == DexRegionalPokedex.national) {
      return null;
    }
    final stats = _scopeStats;
    final (start, end) = DexScope.idRangeForScope(
      _region,
      gameEdition: _gameEdition,
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
    final loading = _mode == _DexMode.national
        ? (_loadingChunk || _loadingRegion)
        : _loadingJourney;
    final padding = DeviceLayout.pagePadding(context);

    return TitoFontScale(
      multiplier: 1.0,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 240 &&
              _mode == _DexMode.national) {
            _loadMore();
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: padding.copyWith(bottom: 8),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  _DexTopBar(
                    gameTitle: _gameEdition.labelZh,
                    onSearch: () => context.push('/search'),
                    onReference: () => _showReferenceMenu(context),
                  ),
                  SizedBox(height: squareGap(context)),
                  _DexGameEditionBar(
                    selected: _gameEdition,
                    onSelected: (edition) async {
                      setState(() {
                        _gameEdition = edition;
                        _region = edition.defaultRegionalPokedex;
                      });
                      await dexSettingsRepository.saveDefaultGameEdition(edition);
                      await gameEditionRepository.save(edition);
                    },
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
                  _DexScopeBar(
                    mode: _mode,
                    region: _region,
                    scopeStats: _scopeStats,
                    journeyCount: _journeyIds.length,
                    onModeSelected: _setMode,
                    onRegionSelected: _setRegion,
                  ),
                  if (_mode == _DexMode.national) ...[
                    SizedBox(height: squareGap(context)),
                    _DexEncounterFilterBar(
                      filter: _encounterFilter,
                      onSelected: (filter) {
                        setState(() => _encounterFilter = filter);
                      },
                    ),
                  ],
                  SizedBox(height: squareGap(context)),
                  if (_error != null)
                    StickerCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            AppZh.dexLoadFailed,
                            style: SecondaryTypography.onCard.body14.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: SecondaryTypography.onCard.small12.copyWith(
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
                ]),
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
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: aspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = visible[index];
                      final status = dexRepository.statusFor(
                        entry.id,
                        _progress,
                      );
                      return PokemonMiniCard(
                        summary: entry,
                        status: status,
                        compact: DeviceLayout.isCompact(context),
                      );
                    },
                    childCount: visible.length,
                  ),
                ),
              ),
            if (_mode == _DexMode.national &&
                _loadingChunk &&
                visible.isNotEmpty)
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
            if (_mode == _DexMode.national &&
                _region == DexRegionalPokedex.national &&
                _loadedThrough < titodexMaxNationalDexId)
              SliverPadding(
                padding: padding.copyWith(top: 8, bottom: 4),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    AppZh.dexLoadingProgress(
                      _loadedThrough,
                      titodexMaxNationalDexId,
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
                    Shadow(
                      color: Color(0x4018283B),
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        HandheldFocusDecorator(
          onActivate: onSearch,
          borderRadius: BorderRadius.circular(DeviceLayout.rMd(context)),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSearch,
              borderRadius: BorderRadius.circular(DeviceLayout.rMd(context)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(DeviceLayout.rMd(context)),
                  border: Border.all(color: TitoColors.card, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: TitoColors.card,
                      size: backIcon * 0.72,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppZh.navSearch,
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
        ),
        const SizedBox(width: 6),
        HandheldFocusDecorator(
          onActivate: onReference,
          borderRadius: BorderRadius.circular(DeviceLayout.rMd(context)),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onReference,
              borderRadius: BorderRadius.circular(DeviceLayout.rMd(context)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(DeviceLayout.rMd(context)),
                  border: Border.all(color: TitoColors.card, width: 2),
                ),
                child: Text(
                  AppZh.dexReferenceTitle,
                  style: SecondaryTypography.onGradient.small12.copyWith(
                    color: TitoColors.card,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DexGameEditionBar extends StatelessWidget {
  const _DexGameEditionBar({
    required this.selected,
    required this.onSelected,
  });

  final GameEdition selected;
  final ValueChanged<GameEdition> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: GameEdition.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final edition = GameEdition.all[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _DexFilterChip(
              label: edition.labelZh,
              selected: selected.slug == edition.slug,
              onTap: () => onSelected(edition),
              compact: true,
            ),
          );
        },
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
    required this.onRegionSelected,
  });

  final _DexMode mode;
  final DexRegionalPokedex region;
  final DexScopeStats scopeStats;
  final int journeyCount;
  final ValueChanged<_DexMode> onModeSelected;
  final ValueChanged<DexRegionalPokedex> onRegionSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DexModeTab(
            selected: mode == _DexMode.national,
            title: AppZh.dexTabNational,
            subtitle: AppZh.dexScopeProgress(
              scopeStats.caught,
              scopeStats.seen,
              scopeStats.total,
            ),
            count: scopeStats.total,
            showRegionMenu: true,
            region: region,
            onTap: () => onModeSelected(_DexMode.national),
            onRegionSelected: onRegionSelected,
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
    this.showRegionMenu = false,
    this.region = DexRegionalPokedex.national,
    this.onRegionSelected,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final int count;
  final VoidCallback onTap;
  final bool showRegionMenu;
  final DexRegionalPokedex region;
  final ValueChanged<DexRegionalPokedex>? onRegionSelected;

  @override
  Widget build(BuildContext context) {
    final radius = DeviceLayout.rMd(context);
    final square = DeviceLayout.useSquareDashboard(context);

    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
                  Text(
                    '$count',
                    style: SecondaryTypography.onCard.meta14.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              if (showRegionMenu && selected)
                // Whole subtitle line opens the region menu — big tap target.
                PopupMenuButton<DexRegionalPokedex>(
                  padding: EdgeInsets.zero,
                  tooltip: '切换地区图鉴',
                  onSelected: onRegionSelected,
                  itemBuilder: (context) {
                    return DexRegionalPokedex.values
                        .map(
                          (scope) => PopupMenuItem(
                            value: scope,
                            child: Text(regionalPokedexLabelZh(scope)),
                          ),
                        )
                        .toList();
                  },
                  child: _subtitleRow(context, withMenuArrow: true),
                )
              else
                _subtitleRow(context),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _subtitleRow(BuildContext context, {bool withMenuArrow = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SecondaryTypography.onCard.meta14.copyWith(
              fontWeight: FontWeight.w600,
              color: TitoColors.mutedInk,
            ),
          ),
        ),
        if (withMenuArrow)
          const Icon(
            Icons.arrow_drop_down_rounded,
            size: 18,
            color: TitoColors.ink,
          ),
      ],
    );
  }
}

class _DexFilterChip extends StatelessWidget {
  const _DexFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

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
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 4,
              vertical: 4,
            ),
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
                fontSize: compact ? 10 : 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
