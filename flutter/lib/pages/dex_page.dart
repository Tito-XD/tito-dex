import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/companion/companion_art.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_progress.dart';
import '../features/dex/dex_repository.dart';
import '../features/dex/dex_scope.dart';
import '../features/game/game_edition.dart';
import '../features/game/game_edition_controller.dart';
import '../features/parser/hgss_format.dart';
import '../theme/error_text.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
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
  // v0.4.0: 11 CDN-backed regional pokedex tabs (replaces 3-value DexRegionalScope).
  DexRegionalPokedex _region = DexRegionalPokedex.national;
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
    // v0.4.0: React to global GameEdition changes from home picker / dex bar.
    gameEditionController.addListener(_onGameEditionChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    gameEditionController.removeListener(_onGameEditionChanged);
    super.dispose();
  }

  GameEdition get _edition => gameEditionController.edition;

  // v0.4.0: Browse scope pairs global edition with selected regional pokedex.
  DexScope get _dexScope => DexScope(
        gameVersion: _edition.toDexGameVersion() ?? DexGameVersion.hgss,
        regionalScope: _region,
      );

  void _onGameEditionChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _summaries = const [];
      _loadedThrough = 0;
      _regionCache.clear();
      _error = null;
    });
    _loadMore();
    if (_region != DexRegionalPokedex.national) {
      _loadRegion(_region);
    }
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
        gameVersion: _dexScope.gameVersion,
      );
      final entries = await dexRepository.getSummaryRange(start, end);
      if (!mounted) {
        return;
      }
      setState(() {
        _regionCache[region] = entries;
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
    final scope = _dexScope;
    final Iterable<PokemonSummary> entries;
    if (_mode == _DexMode.journey) {
      entries = _journeySummaries;
    } else if (_region != DexRegionalPokedex.national &&
        _regionCache.containsKey(_region)) {
      entries = _regionCache[_region]!;
    } else {
      // v0.4.0: Filter via DexScope.speciesInScope (11 regions + edition).
      entries = _summaries.where(scope.speciesInScope);
    }

    return dexRepository.filterSummaries(
      entries,
      _progress,
      _encounterFilter,
    );
  }

  // v0.4.0: HGSS save ranges for national/kanto/johto; summary-based for others.
  DexScopeStats get _scopeStats {
    final gameVersion = _dexScope.gameVersion;
    if (_region == DexRegionalPokedex.national ||
        _region == DexRegionalPokedex.kanto ||
        _region == DexRegionalPokedex.johto) {
      return _progress.statsFor(_region, gameVersion: gameVersion);
    }
    final summaries = _regionCache[_region] ?? _summaries;
    return _progress.statsForSummaries(
      region: _region,
      gameVersion: gameVersion,
      summaries: summaries,
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
    final (start, end) = _dexScope.idRange;
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
                    gameTitle: localizeGame(widget.journey.game),
                    onSearch: () => context.push('/search'),
                    onReference: () => _showReferenceMenu(context),
                  ),
                  SizedBox(height: squareGap(context)),
                  _DexGameEditionBar(
                    selected: _edition,
                    compact: DeviceLayout.useSquareDashboard(context),
                    onSelected: (edition) async {
                      // v0.4.0: Persist globally; listener reloads browse data.
                      await gameEditionController.setEdition(edition);
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
                    edition: _edition,
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
    this.compact = false,
  });

  final GameEdition selected;
  final ValueChanged<GameEdition> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // v0.4.0: Square handheld — current edition + "更多" grouped bottom sheet.
    if (compact) {
      return Row(
        children: [
          Expanded(
            child: _DexFilterChip(
              label: selected.labelZh,
              selected: true,
              onTap: () => _showEditionPicker(context),
            ),
          ),
          const SizedBox(width: 5),
          _DexFilterChip(
            label: '更多',
            selected: false,
            onTap: () => _showEditionPicker(context),
          ),
        ],
      );
    }

    // v0.4.0: Portrait — horizontal scroll of all 23 GameEdition chips.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final edition in GameEdition.values) ...[
            if (edition != GameEdition.values.first) const SizedBox(width: 5),
            _DexFilterChip(
              label: edition.homeBadgeLabel,
              selected: selected == edition,
              onTap: () => onSelected(edition),
            ),
          ],
          const SizedBox(width: 5),
          _DexFilterChip(
            label: '更多',
            selected: false,
            onTap: () => _showEditionPicker(context),
          ),
        ],
      ),
    );
  }

  void _showEditionPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final group in gameEditionPickerGroups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    group.key,
                    style: SecondaryTypography.onCard.body14.copyWith(
                      fontWeight: FontWeight.w800,
                      color: TitoColors.mutedInk,
                    ),
                  ),
                ),
                for (final edition in group.value)
                  ListTile(
                    title: Text(edition.labelZh),
                    trailing: selected == edition
                        ? const Icon(Icons.check_rounded, color: TitoColors.ink)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      onSelected(edition);
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DexScopeBar extends StatelessWidget {
  const _DexScopeBar({
    required this.mode,
    required this.region,
    required this.edition,
    required this.scopeStats,
    required this.journeyCount,
    required this.onModeSelected,
    required this.onRegionSelected,
  });

  final _DexMode mode;
  final DexRegionalPokedex region;
  final GameEdition edition;
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
            edition: edition,
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
    this.edition = GameEdition.hgss,
    this.onRegionSelected,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final int count;
  final VoidCallback onTap;
  final bool showRegionMenu;
  final DexRegionalPokedex region;
  final GameEdition edition;
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
                // v0.4.0: All 11 DexRegionalPokedex values; defaults highlighted per edition.
                PopupMenuButton<DexRegionalPokedex>(
                  padding: EdgeInsets.zero,
                  tooltip: '切换地区图鉴',
                  onSelected: onRegionSelected,
                  itemBuilder: (context) {
                    final defaults =
                        defaultRegionsForEdition(edition).toSet();
                    return DexRegionalPokedex.values
                        .map(
                          (pokedex) => PopupMenuItem(
                            value: pokedex,
                            child: Row(
                              children: [
                                if (defaults.contains(pokedex))
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: TitoColors.skyBlue,
                                    ),
                                  )
                                else
                                  const SizedBox(width: 22),
                                Expanded(
                                  child: Text(
                                    pokedex.labelZh,
                                    style: TextStyle(
                                      fontWeight: defaults.contains(pokedex)
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
