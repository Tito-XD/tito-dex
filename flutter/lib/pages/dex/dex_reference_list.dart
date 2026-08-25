import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dex/dex_filter.dart';
import '../../features/dex/dex_models.dart';
import '../../features/dex/type_chart.dart';
import '../../l10n/app_zh.dart';
import '../../navigation/tito_route_work.dart';
import '../../theme/device_layout.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import '../../widgets/dex_reference_detail.dart';
import '../../widgets/handheld_input.dart';
import '../../widgets/secondary_page_scaffold.dart';
import '../../widgets/sticker_card.dart';
import '../../widgets/sticker_pressable.dart';
import '../../widgets/tito_list_reveal.dart';
import '../../widgets/tito_loading_panel.dart';
import '../../widgets/type_badge.dart';

typedef DexReferenceFilter<T> = bool Function(T entry, String query);

/// Optional category filter configuration for the reference list.
class DexReferenceCategoryFilter<T> {
  const DexReferenceCategoryFilter({
    required this.options,
    required this.label,
    required this.filter,
  });

  /// Ordered category labels (null = "全部").
  final List<String?> options;
  final String Function(T entry) label;
  final bool Function(T entry, String? category) filter;
}

class DexReferenceListPage<T> extends StatefulWidget {
  const DexReferenceListPage({
    super.key,
    required this.title,
    required this.loadEntries,
    required this.filterEntry,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.detailSheet,
    this.subtitle,
    this.leadingBuilder,
    this.categoryFilter,
    this.gridMode = false,
    this.initialQuery,
    this.initialEntryId,
    this.openInitialEntry = false,
    this.entryId,
    this.includeEntry,
    this.scopeNotice,
    this.scopedDetailSheet,
  });

  final String title;
  final String? subtitle;
  final Future<List<T>> Function() loadEntries;
  final DexReferenceFilter<T> filterEntry;
  final String Function(T entry) primaryLabel;
  final String Function(T entry) secondaryLabel;
  final void Function(BuildContext context, T entry) detailSheet;
  final Widget? Function(T entry)? leadingBuilder;
  final DexReferenceCategoryFilter<T>? categoryFilter;
  final bool gridMode;
  final String? initialQuery;
  final int? initialEntryId;
  final bool openInitialEntry;
  final int Function(T entry)? entryId;
  final bool Function(T entry)? includeEntry;
  final String? Function(T entry)? scopeNotice;
  final void Function(BuildContext context, T entry, String? scopeNotice)?
  scopedDetailSheet;

  @override
  State<DexReferenceListPage<T>> createState() =>
      _DexReferenceListPageState<T>();
}

class _DexReferenceListPageState<T> extends State<DexReferenceListPage<T>> {
  static const _searchDebounce = Duration(milliseconds: 200);
  static const _initialBatchSize = 36;
  static const _batchSize = 36;
  static const _loadMoreThreshold = 320.0;

  late final TextEditingController _queryController;
  late String _appliedQuery;

  List<T> _entries = const [];
  List<T> _visibleEntries = const [];
  Map<String?, int> _categoryCounts = const {};
  String? _selectedCategory;
  Timer? _queryDebounce;
  bool _loading = true;
  bool _initialLoadScheduled = false;
  bool _batchScheduled = false;
  String? _error;
  bool _initialEntryOpened = false;
  int _loadGeneration = 0;
  int _materializedCount = 0;

  String get _resultReplayKey =>
      '$_appliedQuery\u0000${_selectedCategory ?? 'all'}';

  Object _entryRevealIdentity(T entry) =>
      widget.entryId?.call(entry) ?? widget.primaryLabel(entry);

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    _appliedQuery = _queryController.text.trim().toLowerCase();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialLoadScheduled) {
      return;
    }
    _initialLoadScheduled = true;
    unawaited(_loadWhenRoutePainted());
  }

  Future<void> _loadWhenRoutePainted() async {
    if (!await waitForIncomingRoutePainted(context) || !mounted) {
      return;
    }
    await _load();
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    _queryDebounce?.cancel();
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await widget.loadEntries();
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _entries = entries;
        _loading = false;
        _rebuildCategoryCounts();
        _rebuildVisibleEntries();
      });
      _openInitialEntryIfRequested();
    } catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _onQueryChanged() {
    _queryDebounce?.cancel();
    _queryDebounce = Timer(_searchDebounce, () {
      if (!mounted) {
        return;
      }
      final query = _queryController.text.trim().toLowerCase();
      if (query == _appliedQuery) {
        return;
      }
      setState(() {
        _appliedQuery = query;
        _rebuildVisibleEntries();
      });
    });
  }

  void _selectCategory(String? category) {
    if (category == _selectedCategory) {
      return;
    }
    setState(() {
      _selectedCategory = category;
      _rebuildVisibleEntries();
    });
  }

  void _rebuildCategoryCounts() {
    final filter = widget.categoryFilter;
    if (filter == null) {
      _categoryCounts = const {};
      return;
    }
    final counts = <String?, int>{null: _entries.length};
    for (final entry in _entries) {
      final label = filter.label(entry);
      counts[label] = (counts[label] ?? 0) + 1;
    }
    _categoryCounts = Map<String?, int>.unmodifiable(counts);
  }

  void _rebuildVisibleEntries() {
    final categoryFilter = widget.categoryFilter;
    final category = _selectedCategory;
    final filtered = <T>[];
    for (final entry in _entries) {
      if (!_isInitialEntry(entry) &&
          !(widget.includeEntry?.call(entry) ?? true)) {
        continue;
      }
      if (categoryFilter != null &&
          category != null &&
          !categoryFilter.filter(entry, category)) {
        continue;
      }
      if (_appliedQuery.isNotEmpty &&
          !widget.filterEntry(entry, _appliedQuery)) {
        continue;
      }
      filtered.add(entry);
    }
    _visibleEntries = List<T>.unmodifiable(filtered);
    _materializedCount = math.min(_initialBatchSize, _visibleEntries.length);
  }

  List<T> get _visible => _visibleEntries;

  bool get _hasMore => !_loading && _materializedCount < _visibleEntries.length;

  void _materializeNextBatch() {
    if (!_hasMore) {
      return;
    }
    setState(() {
      _materializedCount = math.min(
        _materializedCount + _batchSize,
        _visibleEntries.length,
      );
    });
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical ||
        notification.metrics.extentAfter > _loadMoreThreshold ||
        !_hasMore ||
        _batchScheduled) {
      return false;
    }
    _batchScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _batchScheduled = false;
      if (mounted) {
        _materializeNextBatch();
      }
    });
    return false;
  }

  bool _isInitialEntry(T entry) {
    final initialId = widget.initialEntryId;
    final entryId = widget.entryId;
    return initialId != null && entryId != null && entryId(entry) == initialId;
  }

  void _openInitialEntryIfRequested() {
    if (!widget.openInitialEntry || _initialEntryOpened) return;
    final target = _entries.where(_isInitialEntry).firstOrNull;
    if (target == null) return;
    _initialEntryOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openDetail(context, target);
    });
  }

  void _openDetail(BuildContext context, T entry) {
    final notice = widget.scopeNotice?.call(entry);
    final scoped = widget.scopedDetailSheet;
    if (scoped != null) {
      scoped(context, entry, notice);
      return;
    }
    widget.detailSheet(context, entry);
  }

  Widget _buildItemGrid(List<T> items) {
    final columns = DeviceLayout.dexGridColumns(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final entry = items[index];
        final initialScopeNotice = _isInitialEntry(entry)
            ? widget.scopeNotice?.call(entry)
            : null;
        return TitoListReveal(
          key: ValueKey<Object>(_entryRevealIdentity(entry)),
          replayKey: _resultReplayKey,
          delay: TitoListReveal.staggerDelay(index),
          child: _GridItemCard(
            label: widget.primaryLabel(entry),
            leading: widget.leadingBuilder?.call(entry),
            scopeNotice: initialScopeNotice,
            onTap: () => _openDetail(ctx, entry),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allVisible = _visible;
    final visible = allVisible.take(_materializedCount).toList(growable: false);

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: SecondaryPageScaffold(
        title: widget.title,
        subtitle: widget.subtitle,
        children: [
          StickerCard(
            child: TextField(
              controller: _queryController,
              decoration: InputDecoration(
                hintText: AppZh.dexReferenceSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TitoRadii.md),
                  borderSide: const BorderSide(color: TitoColors.ink, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.categoryFilter != null)
            _CategoryFilterChips(
              options: widget.categoryFilter!.options,
              counts: _categoryCounts,
              selected: _selectedCategory,
              onSelected: _selectCategory,
            ),
          if (_loading)
            const TitoLoadingPanel(
              message: AppZh.referenceLoading,
              compact: true,
            )
          else if (_error != null)
            StickerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppZh.dexLoadFailed,
                    style: SecondaryTypography.onCard.body14.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_error!, style: SecondaryTypography.onCard.small12),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _load,
                    child: const Text(AppZh.dexRetry),
                  ),
                ],
              ),
            )
          else if (visible.isEmpty)
            StickerCard(
              child: Text(
                widget.initialEntryId != null
                    ? AppZh.dexReferenceDataMissing
                    : AppZh.dexReferenceEmpty,
                style: SecondaryTypography.onCard.body14,
              ),
            )
          else if (widget.gridMode)
            _buildItemGrid(visible)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visible.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = visible[index];
                final initialScopeNotice = _isInitialEntry(entry)
                    ? widget.scopeNotice?.call(entry)
                    : null;
                return TitoListReveal(
                  key: ValueKey<Object>(_entryRevealIdentity(entry)),
                  replayKey: _resultReplayKey,
                  delay: TitoListReveal.staggerDelay(index),
                  child: HandheldFocusDecorator(
                    onActivate: () => _openDetail(context, entry),
                    borderRadius: BorderRadius.circular(
                      DeviceLayout.rMd(context),
                    ),
                    child: StickerPressable(
                      borderRadius: BorderRadius.circular(
                        DeviceLayout.rMd(context),
                      ),
                      ownShadow: false,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openDetail(context, entry),
                          borderRadius: BorderRadius.circular(
                            DeviceLayout.rMd(context),
                          ),
                          child: StickerCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                if (widget.leadingBuilder != null) ...[
                                  widget.leadingBuilder!(entry) ??
                                      const SizedBox(width: 4),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.primaryLabel(entry),
                                        style: SecondaryTypography.onCard.body14
                                            .copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.secondaryLabel(entry),
                                        style: SecondaryTypography
                                            .onCard
                                            .small12
                                            .copyWith(
                                              color: TitoColors.mutedInk,
                                            ),
                                      ),
                                      if (initialScopeNotice != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          initialScopeNotice,
                                          key: const Key(
                                            'dex-reference-scope-notice',
                                          ),
                                          style: SecondaryTypography
                                              .onCard
                                              .small12
                                              .copyWith(
                                                color: TitoColors.coral,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: TitoColors.mutedInk,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton(
                  key: const Key('dex-reference-load-more'),
                  onPressed: _materializeNextBatch,
                  child: Text(
                    '继续显示 · ${visible.length}/${allVisible.length}',
                    style: SecondaryTypography.onCard.small12.copyWith(
                      fontWeight: FontWeight.w800,
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

void showMoveDetailSheet(
  BuildContext context,
  CachedMove move, {
  String? scopeNotice,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (scopeNotice != null) ...[
                  ReferenceScopeNotice(message: scopeNotice),
                  const SizedBox(height: 12),
                ],
                Text(
                  move.nameZh,
                  style: SecondaryTypography.onCard.h15.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  move.nameEn,
                  style: SecondaryTypography.onCard.small12.copyWith(
                    color: TitoColors.mutedInk,
                  ),
                ),
                const SizedBox(height: 12),
                TitoTypeBadge(typeEn: move.type, size: TypeBadgeSize.medium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      moveCategoryIcon(move.category),
                      size: 18,
                      color: TitoColors.ink,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        formatMoveStatLine(
                          category: move.category,
                          power: move.power,
                          accuracy: move.accuracy,
                          pp: move.pp,
                        ),
                        style: SecondaryTypography.onCard.body14.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (move.descriptionZh?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  StickerCard(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      move.descriptionZh!,
                      style: SecondaryTypography.onCard.body14,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    dexFilterController.setFilter(
                      DexFilter(
                        learnsMoveId: move.id,
                        labelZh: AppZh.dexFilterMoveLabel(move.nameZh),
                      ),
                    );
                    // push (not go) keeps the reference page underneath, so
                    // system back returns there instead of leaving the app.
                    context.push('/dex');
                  },
                  child: Text(AppZh.dexReferenceViewMoveLearners),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void showAbilityDetailSheet(
  BuildContext context,
  CachedAbility ability, {
  String? scopeNotice,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final pokemonCount = ability.pokemonIds.length;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (scopeNotice != null) ...[
                ReferenceScopeNotice(message: scopeNotice),
                const SizedBox(height: 12),
              ],
              Text(
                ability.nameZh,
                style: SecondaryTypography.onCard.h15.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                ability.nameEn,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ability.descriptionZh.isEmpty
                    ? AppZh.dexReferenceNoDescription
                    : ability.descriptionZh,
                style: SecondaryTypography.onCard.body14,
              ),
              if (pokemonCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  AppZh.dexReferencePokemonCount(pokemonCount),
                  style: SecondaryTypography.onCard.small12.copyWith(
                    color: TitoColors.mutedInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: pokemonCount == 0
                    ? null
                    : () {
                        Navigator.pop(context);
                        dexFilterController.setFilter(
                          DexFilter(
                            abilityId: ability.id,
                            labelZh: AppZh.dexFilterAbilityLabel(
                              ability.nameZh,
                            ),
                          ),
                        );
                        context.push('/dex');
                      },
                child: Text(AppZh.dexReferenceViewAbilityPokemon),
              ),
            ],
          ),
        ),
      );
    },
  );
}

bool filterCachedMove(CachedMove move, String query) {
  return move.nameZh.contains(query) ||
      move.nameEn.toLowerCase().contains(query) ||
      typeNameZh(move.type).contains(query) ||
      move.id.toString().contains(query);
}

bool filterCachedAbility(CachedAbility ability, String query) {
  return ability.nameZh.contains(query) ||
      ability.nameEn.toLowerCase().contains(query) ||
      ability.descriptionZh.contains(query) ||
      ability.id.toString().contains(query);
}

class _GridItemCard extends StatelessWidget {
  const _GridItemCard({
    required this.label,
    this.leading,
    this.scopeNotice,
    required this.onTap,
  });
  final String label;
  final Widget? leading;
  final String? scopeNotice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: BorderRadius.circular(DeviceLayout.rMd(context)),
      child: GestureDetector(
        onTap: onTap,
        child: StickerCard(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(height: 8)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: SecondaryTypography.onCard.body14.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (scopeNotice != null) ...[
                const SizedBox(height: 3),
                Text(
                  scopeNotice!,
                  key: const Key('dex-reference-scope-notice'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: SecondaryTypography.onCard.small12.copyWith(
                    color: TitoColors.coral,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryFilterChips extends StatelessWidget {
  const _CategoryFilterChips({
    required this.options,
    required this.counts,
    required this.selected,
    required this.onSelected,
  });

  final List<String?> options;
  final Map<String?, int> counts;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cat = options[index];
          final sel = selected == cat;
          final count = counts[cat] ?? 0;
          return FilterChip(
            selected: sel,
            label: Text(
              '${cat ?? "全部"} ($count)',
              style: const TextStyle(fontSize: 11),
            ),
            onSelected: (_) => onSelected(sel ? null : cat),
            backgroundColor: TitoColors.card,
            selectedColor: TitoColors.mint,
            checkmarkColor: TitoColors.deepBlue,
            side: BorderSide(
              color: sel
                  ? TitoColors.mint
                  : TitoColors.ink.withValues(alpha: 0.2),
            ),
          );
        },
      ),
    );
  }
}
