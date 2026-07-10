import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/companion/companion_art.dart';
import '../features/dex/dex_game_scope.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
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
import '../theme/tito_typography.dart';
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

/// Seen / caught filter — UI + local state; real seen flags land with the
/// HGSS `.sav` dex parser (docs/PARSER_PROPOSAL.md). Until then "seen" is
/// stubbed from journey-caught ids.
enum _DexStatusFilter { all, seen, caught, unseen }

class _DexPageState extends State<DexPage> {
  static const _chunkSize = 18;

  int _loadedThrough = 0;
  bool _loadingChunk = false;
  bool _loadingJourney = false;
  _DexMode _mode = _DexMode.national;
  DexRegionalScope _region = DexRegionalScope.national;
  _DexStatusFilter _statusFilter = _DexStatusFilter.all;
  List<PokemonSummary> _summaries = const [];
  List<PokemonSummary> _journeySummaries = const [];
  Set<int> _caughtIds = const {};
  Set<int> _journeyIds = const {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      _journeyIds = _resolveJourneyIds();
      final caught = await dexRepository.journeyCaughtIds(widget.journey);
      if (!mounted) {
        return;
      }
      setState(() => _caughtIds = caught);
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
    if (_loadingChunk || _loadedThrough >= hgssMaxNationalDexId) {
      return;
    }

    setState(() => _loadingChunk = true);
    try {
      final start = _loadedThrough + 1;
      final end = (_loadedThrough + _chunkSize).clamp(1, hgssMaxNationalDexId);
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

  void _setRegion(DexRegionalScope region) {
    setState(() {
      _region = region;
      _mode = _DexMode.national;
      _error = null;
    });
  }

  bool _matchesStatusFilter(int id) {
    return switch (_statusFilter) {
      _DexStatusFilter.all => true,
      // Seen stubbed to caught until the save parser provides seen flags.
      _DexStatusFilter.seen => _caughtIds.contains(id),
      _DexStatusFilter.caught => _caughtIds.contains(id),
      _DexStatusFilter.unseen => !_caughtIds.contains(id),
    };
  }

  List<PokemonSummary> get _visibleEntries {
    if (_mode == _DexMode.journey) {
      return _journeySummaries
          .where((entry) => _matchesStatusFilter(entry.id))
          .toList(growable: false);
    }

    final (start, end) = regionalDexIdRange(_region);
    return _summaries
        .where(
          (entry) =>
              entry.id >= start &&
              entry.id <= end &&
              _matchesStatusFilter(entry.id),
        )
        .toList(growable: false);
  }

  int get _nationalScopeTotal {
    final (start, end) = regionalDexIdRange(_region);
    return end - start + 1;
  }

  String _emptyMessageForMode() {
    if (_statusFilter != _DexStatusFilter.all) {
      return AppZh.dexFilterEmpty;
    }
    return _mode == _DexMode.journey
        ? AppZh.dexJourneyEmpty
        : AppZh.dexJourneyEmpty;
  }

  /// Region progress line, e.g. `#152–251 · 已见 6 / 已捕 6 / 共 100`.
  String? get _regionProgressLine {
    if (_mode != _DexMode.national || _region == DexRegionalScope.national) {
      return null;
    }
    final (start, end) = regionalDexIdRange(_region);
    final caught =
        _caughtIds.where((id) => id >= start && id <= end).length;
    // Seen == caught until the .sav dex parser lands.
    return AppZh.dexRegionProgress(start, end, caught, caught, end - start + 1);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleEntries;
    final columns = DeviceLayout.dexGridColumns(context);
    final aspectRatio = DeviceLayout.dexCardAspectRatio(context);
    final loading =
        _mode == _DexMode.national ? _loadingChunk : _loadingJourney;
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
                    nationalTotal: _nationalScopeTotal,
                    journeyCount: _journeyIds.length,
                    onModeSelected: _setMode,
                    onRegionSelected: _setRegion,
                  ),
                  SizedBox(height: squareGap(context)),
                  _DexStatusFilterBar(
                    selected: _statusFilter,
                    onSelected: (filter) =>
                        setState(() => _statusFilter = filter),
                  ),
                  SizedBox(height: squareGap(context)),
                  if (_error != null)
                    StickerCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            AppZh.dexLoadFailed,
                            style: context.tito.cardBodyEmphasis,
                          ),
                          const SizedBox(height: 8),
                          Text(_error!, style: context.tito.errorDetail),
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
                        style: context.tito.cardBodyStrong,
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
                        _caughtIds,
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
                _loadedThrough < hgssMaxNationalDexId)
              SliverPadding(
                padding: padding.copyWith(top: 8, bottom: 4),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    AppZh.dexLoadingProgress(
                      _loadedThrough,
                      hgssMaxNationalDexId,
                    ),
                    textAlign: TextAlign.center,
                    style: context.tito.pageSubtitleOnGradient,
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
}

class _DexTopBar extends StatelessWidget {
  const _DexTopBar({
    required this.gameTitle,
    required this.onSearch,
  });

  final String gameTitle;
  final VoidCallback onSearch;

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
      ],
    );
  }
}

class _DexScopeBar extends StatelessWidget {
  const _DexScopeBar({
    required this.mode,
    required this.region,
    required this.nationalTotal,
    required this.journeyCount,
    required this.onModeSelected,
    required this.onRegionSelected,
  });

  final _DexMode mode;
  final DexRegionalScope region;
  final int nationalTotal;
  final int journeyCount;
  final ValueChanged<_DexMode> onModeSelected;
  final ValueChanged<DexRegionalScope> onRegionSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DexModeTab(
            selected: mode == _DexMode.national,
            title: AppZh.dexTabNational,
            subtitle: regionalScopeLabelZh(region),
            count: nationalTotal,
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

class _DexModeTab extends StatelessWidget {
  const _DexModeTab({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.onTap,
    this.showRegionMenu = false,
    this.region = DexRegionalScope.national,
    this.onRegionSelected,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final int count;
  final VoidCallback onTap;
  final bool showRegionMenu;
  final DexRegionalScope region;
  final ValueChanged<DexRegionalScope>? onRegionSelected;

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
                    style: context.tito.cardValue.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
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
                  if (showRegionMenu && selected)
                    PopupMenuButton<DexRegionalScope>(
                      padding: EdgeInsets.zero,
                      tooltip: '切换地区图鉴',
                      onSelected: onRegionSelected,
                      itemBuilder: (context) {
                        return DexRegionalScope.values
                            .map(
                              (scope) => PopupMenuItem(
                                value: scope,
                                child: Text(regionalScopeLabelZh(scope)),
                              ),
                            )
                            .toList();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 18,
                            color: TitoColors.ink,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _DexStatusFilterBar extends StatelessWidget {
  const _DexStatusFilterBar({
    required this.selected,
    required this.onSelected,
  });

  final _DexStatusFilter selected;
  final ValueChanged<_DexStatusFilter> onSelected;

  static const _labels = <_DexStatusFilter, String>{
    _DexStatusFilter.all: AppZh.dexFilterAll,
    _DexStatusFilter.seen: AppZh.dexFilterSeen,
    _DexStatusFilter.caught: AppZh.dexFilterCaught,
    _DexStatusFilter.unseen: AppZh.dexFilterUnseen,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final filter in _DexStatusFilter.values) ...[
          if (filter != _DexStatusFilter.values.first) const SizedBox(width: 5),
          Expanded(
            child: _DexFilterChip(
              label: _labels[filter]!,
              selected: filter == selected,
              onTap: () => onSelected(filter),
            ),
          ),
        ],
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
              style: TitoTypography.style(
                fontSize: 11,
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
