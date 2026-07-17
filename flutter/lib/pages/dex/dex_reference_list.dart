import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dex/dex_filter.dart';
import '../../features/dex/dex_models.dart';
import '../../features/dex/type_chart.dart';
import '../../l10n/app_zh.dart';
import '../../theme/device_layout.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import '../../widgets/dex_reference_detail.dart';
import '../../widgets/handheld_input.dart';
import '../../widgets/secondary_page_scaffold.dart';
import '../../widgets/sticker_card.dart';
import '../../widgets/tito_list_reveal.dart';
import '../../widgets/tito_loading_panel.dart';
import '../../widgets/type_badge.dart';

typedef DexReferenceFilter<T> = bool Function(T entry, String query);

class DexReferenceListPage<T> extends StatefulWidget {
  const DexReferenceListPage({
    super.key,
    required this.title,
    required this.loadEntries,
    required this.filterEntry,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.detailSheet,
  });

  final String title;
  final Future<List<T>> Function() loadEntries;
  final DexReferenceFilter<T> filterEntry;
  final String Function(T entry) primaryLabel;
  final String Function(T entry) secondaryLabel;
  final void Function(BuildContext context, T entry) detailSheet;

  @override
  State<DexReferenceListPage<T>> createState() =>
      _DexReferenceListPageState<T>();
}

class _DexReferenceListPageState<T> extends State<DexReferenceListPage<T>> {
  final _queryController = TextEditingController();
  List<T> _entries = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _queryController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await widget.loadEntries();
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<T> get _visible {
    final query = _queryController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _entries;
    }
    return _entries
        .where((entry) => widget.filterEntry(entry, query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return SecondaryPageScaffold(
      title: widget.title,
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
        if (_loading)
          const TitoLoadingPanel(message: AppZh.referenceLoading, compact: true)
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
              AppZh.dexReferenceEmpty,
              style: SecondaryTypography.onCard.body14,
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = visible[index];
              return TitoListReveal(
                delay: TitoListReveal.staggerDelay(index),
                child: HandheldFocusDecorator(
                  onActivate: () => widget.detailSheet(context, entry),
                  borderRadius: BorderRadius.circular(
                    DeviceLayout.rMd(context),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => widget.detailSheet(context, entry),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.primaryLabel(entry),
                                    style: SecondaryTypography.onCard.body14
                                        .copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.secondaryLabel(entry),
                                    style: SecondaryTypography.onCard.small12
                                        .copyWith(color: TitoColors.mutedInk),
                                  ),
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
              );
            },
          ),
      ],
    );
  }
}

void showMoveDetailSheet(BuildContext context, CachedMove move) {
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

void showAbilityDetailSheet(BuildContext context, CachedAbility ability) {
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
