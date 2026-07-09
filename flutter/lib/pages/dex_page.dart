import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/companion/companion_art.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
import '../features/parser/hgss_format.dart';
import '../theme/error_text.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../navigation/back_navigation.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
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

enum _DexListFilter { all, seen, journey, caught }

class _DexPageState extends State<DexPage> {
  static const _chunkSize = 18;

  int _loadedThrough = 0;
  bool _loadingChunk = false;
  bool _loadingFilter = false;
  _DexListFilter _filter = _DexListFilter.all;
  List<PokemonSummary> _summaries = const [];
  List<PokemonSummary> _filteredSummaries = const [];
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

  Set<int> get _seenIds => {..._caughtIds, ..._journeyIds};

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

  Future<void> _setFilter(_DexListFilter filter) async {
    if (_filter == filter && filter == _DexListFilter.all) {
      return;
    }

    setState(() {
      _filter = filter;
      _error = null;
      if (filter == _DexListFilter.all) {
        _filteredSummaries = const [];
        _loadingFilter = false;
      } else {
        _loadingFilter = true;
      }
    });

    if (filter == _DexListFilter.all) {
      return;
    }

    final ids = switch (filter) {
      _DexListFilter.seen => _seenIds,
      _DexListFilter.journey => _journeyIds,
      _DexListFilter.caught => _caughtIds,
      _DexListFilter.all => <int>{},
    };

    try {
      final entries = await dexRepository.getSummariesForIds(ids);
      if (!mounted) {
        return;
      }
      setState(() {
        _filteredSummaries = entries;
        _loadingFilter = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _formatDexError(error);
        _loadingFilter = false;
        _filteredSummaries = const [];
      });
    }
  }

  List<PokemonSummary> get _visibleEntries {
    return switch (_filter) {
      _DexListFilter.all => _summaries,
      _ => _filteredSummaries,
    };
  }

  String _emptyMessageForFilter() {
    return switch (_filter) {
      _DexListFilter.journey => AppZh.dexJourneyEmpty,
      _DexListFilter.caught => AppZh.dexCaughtEmpty,
      _DexListFilter.seen => AppZh.dexSeenEmpty,
      _DexListFilter.all => AppZh.dexJourneyEmpty,
    };
  }

  @override
  Widget build(BuildContext context) {
    final caughtCount = _caughtIds.length;
    final seenCount = _seenIds.length;
    final visible = _visibleEntries;
    final columns = DeviceLayout.dexGridColumns(context);
    final aspectRatio = DeviceLayout.dexCardAspectRatio(context);
    final loading =
        _filter == _DexListFilter.all ? _loadingChunk : _loadingFilter;
    final padding = DeviceLayout.pagePadding(context);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 240 &&
            _filter == _DexListFilter.all) {
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
                _DexTopBar(onSearch: () => context.push('/search')),
                SizedBox(height: squareGap(context)),
                Text(
                  '${AppZh.navDex} · ${localizeGame(widget.journey.game)}',
                  style: context.tito.pageTitleOnGradient,
                ),
                SizedBox(height: squareGap(context)),
                Text(
                  AppZh.dexScopeNote,
                  style: context.tito.pageSubtitleOnGradient,
                  maxLines: DeviceLayout.useSquareDashboard(context) ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: squareGap(context) + 2),
                _DexStatsRow(
                  seenCount: seenCount,
                  caughtCount: caughtCount,
                  selected: _filter,
                  onSelected: _setFilter,
                ),
                SizedBox(height: squareGap(context)),
                _DexFilterBar(
                  current: _filter,
                  onSelected: _setFilter,
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
                            if (_filter == _DexListFilter.all) {
                              _loadMore();
                            } else {
                              _setFilter(_filter);
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
                      _emptyMessageForFilter(),
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
          if (_filter == _DexListFilter.all &&
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
          if (_filter == _DexListFilter.all &&
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
    );
  }

  double squareGap(BuildContext context) =>
      DeviceLayout.useSquareDashboard(context) ? 6 : 8;
}

class _DexTopBar extends StatelessWidget {
  const _DexTopBar({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final square = DeviceLayout.useSquareDashboard(context);
    final controlSize = DeviceLayout.dexBackControlSize(context);
    final iconSize = DeviceLayout.dexBackIconSize(context);
    final barHeight = DeviceLayout.headerBarHeight(context);

    return SizedBox(
      height: barHeight,
      child: Row(
        children: [
          HandheldFocusDecorator(
            onActivate: () => TitoBackNavigation.navigateBack(context, '/dex'),
            child: TextButton.icon(
              onPressed: () => TitoBackNavigation.navigateBack(context, '/dex'),
              style: TextButton.styleFrom(
                foregroundColor: TitoColors.card,
                padding: EdgeInsets.symmetric(
                  horizontal: square ? 10 : 8,
                  vertical: square ? 8 : 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                Icons.arrow_back_rounded,
                size: iconSize,
                color: TitoColors.card,
              ),
              label: Text(
                AppZh.navDex,
                style: context.tito.cardBodyStrong.copyWith(
                  color: TitoColors.card,
                  fontSize: controlSize,
                ),
              ),
            ),
          ),
          const Spacer(),
          HandheldFocusDecorator(
            onActivate: onSearch,
            borderRadius: BorderRadius.circular(TitoRadii.md),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSearch,
                borderRadius: BorderRadius.circular(TitoRadii.md),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: DeviceLayout.dim(context, square ? 12.0 : 10.0),
                    vertical: DeviceLayout.dim(context, square ? 8.0 : 6.0),
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(TitoRadii.md),
                    border: Border.all(color: TitoColors.card, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: TitoColors.card,
                        size: iconSize,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppZh.navSearch,
                        style: context.tito.cardBodyStrong.copyWith(
                          color: TitoColors.card,
                          fontSize: controlSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DexFilterBar extends StatelessWidget {
  const _DexFilterBar({
    required this.current,
    required this.onSelected,
  });

  final _DexListFilter current;
  final ValueChanged<_DexListFilter> onSelected;

  static const _options = [
    (_DexListFilter.all, AppZh.dexTabNational, Icons.grid_view_rounded),
    (_DexListFilter.journey, AppZh.dexTabJourney, Icons.groups_rounded),
    (_DexListFilter.caught, AppZh.dexCaught, Icons.catching_pokemon_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (filter, label, icon) in _options) ...[
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: filter == _DexListFilter.caught ? 0 : 6,
              ),
              child: _DexFilterChip(
                label: label,
                icon: icon,
                selected: current == filter,
                onTap: () => onSelected(filter),
              ),
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
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TitoRadii.md),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? TitoColors.softYellow : TitoColors.card,
            borderRadius: BorderRadius.circular(TitoRadii.md),
            border: Border.all(color: TitoColors.ink, width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: TitoColors.ink,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tito.chip,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DexStatsRow extends StatelessWidget {
  const _DexStatsRow({
    required this.seenCount,
    required this.caughtCount,
    required this.selected,
    required this.onSelected,
  });

  final int seenCount;
  final int caughtCount;
  final _DexListFilter selected;
  final ValueChanged<_DexListFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DexStatCard(
            label: AppZh.dexSeen,
            value: '$seenCount',
            variant: StickerVariant.sky,
            selected: selected == _DexListFilter.seen,
            onTap: () => onSelected(_DexListFilter.seen),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _DexStatCard(
            label: AppZh.dexCaught,
            value: '$caughtCount',
            variant: StickerVariant.mint,
            selected: selected == _DexListFilter.caught,
            onTap: () => onSelected(_DexListFilter.caught),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _DexStatCard(
            label: '全国',
            value: '$hgssMaxNationalDexId',
            variant: StickerVariant.cream,
            selected: selected == _DexListFilter.all,
            onTap: () => onSelected(_DexListFilter.all),
          ),
        ),
      ],
    );
  }
}

class _DexStatCard extends StatelessWidget {
  const _DexStatCard({
    required this.label,
    required this.value,
    required this.variant,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final StickerVariant variant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TitoRadii.md),
        child: StickerCard(
          variant: selected ? StickerVariant.softYellow : variant,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: context.tito.captionStrong,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: context.tito.cardValueLarge.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
