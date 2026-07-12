import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/dex/dex_models.dart';
import '../features/dex/dex_progress.dart';
import '../features/dex/dex_repository.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/error_text.dart';
import '../theme/device_layout.dart';
import '../theme/tito_font_scale.dart';
import '../widgets/dex_sprite_image.dart';
import '../widgets/handheld_input.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';
import 'search/battle_hub_tab.dart';
import 'search/reference_hub_tab.dart';

// v0.4.0: §7.4 search hub tabs — search | reference | battle.
enum _SearchHubTab { search, reference, battle }

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _recentQueriesKey = 'search_page_recent_queries_v1';
  static const _maxRecentQueries = 5;

  final _controller = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  String? _error;
  List<PokemonSummary> _results = const [];
  DexProgress _progress = const DexProgress(caughtIds: {}, seenIds: {});
  List<String> _recentQueries = const [];
  // v0.4.0: default to search tab.
  _SearchHubTab _hubTab = _SearchHubTab.search;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _loadRecentQueries();
  }

  Future<void> _loadProgress() async {
    final progress = dexRepository.progressFor(widget.journey);
    if (!mounted) {
      return;
    }
    setState(() => _progress = progress);
  }

  Future<void> _loadRecentQueries() async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList(_recentQueriesKey) ?? const [];
    if (!mounted) {
      return;
    }
    setState(() {
      _recentQueries = recent.take(_maxRecentQueries).toList();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(value);
    });
  }

  Future<void> _rememberRecentQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final updated = [
      trimmed,
      ..._recentQueries.where((entry) => entry != trimmed),
    ].take(_maxRecentQueries).toList();
    if (listEquals(updated, _recentQueries)) {
      return;
    }
    setState(() => _recentQueries = updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentQueriesKey, updated);
  }

  void _applyQuery(String query) {
    _controller
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    _onQueryChanged(query);
    setState(() {});
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final results = await dexRepository.search(trimmed);
      if (!mounted || _controller.text.trim() != trimmed) {
        return;
      }
      await _rememberRecentQuery(trimmed);
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = formatUserFacingError(error);
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TitoFontScale(
      multiplier: 1.0,
      // TextField requires a Material ancestor; the route shell doesn't
      // provide one (pages render straight into TitoPageContainer).
      child: Material(
        type: MaterialType.transparency,
        child: SecondaryPageScaffold(
          title: '${AppZh.navSearch} · ${localizeGame(widget.journey.game)}',
          children: [
            _SearchHubSegmentedControl(
              selected: _hubTab,
              onChanged: (tab) => setState(() => _hubTab = tab),
            ),
            const SizedBox(height: 16),
            switch (_hubTab) {
              _SearchHubTab.search => _SearchTabContent(
                  controller: _controller,
                  onQueryChanged: _onQueryChanged,
                  recentQueries: _recentQueries,
                  onApplyQuery: _applyQuery,
                  query: _controller.text.trim(),
                  searching: _searching,
                  error: _error,
                  results: _results,
                  progress: _progress,
                ),
              _SearchHubTab.reference => const ReferenceHubTab(),
              _SearchHubTab.battle => BattleHubTab(journey: widget.journey),
            },
          ],
        ),
      ),
    );
  }
}

class _SearchHubSegmentedControl extends StatelessWidget {
  const _SearchHubSegmentedControl({
    required this.selected,
    required this.onChanged,
  });

  final _SearchHubTab selected;
  final ValueChanged<_SearchHubTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_SearchHubTab>(
      segments: const [
        ButtonSegment(
          value: _SearchHubTab.search,
          label: Text(AppZh.navSearch),
        ),
        ButtonSegment(
          value: _SearchHubTab.reference,
          label: Text(AppZh.dexReferenceTitle),
        ),
        ButtonSegment(
          value: _SearchHubTab.battle,
          label: Text(AppZh.searchHubBattle),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (values) => onChanged(values.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TitoColors.deepBlue;
          }
          return TitoColors.card;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TitoColors.card;
          }
          return TitoColors.deepBlue.withValues(alpha: 0.35);
        }),
        side: WidgetStateProperty.all(
          const BorderSide(color: TitoColors.card, width: 2),
        ),
      ),
    );
  }
}

class _SearchTabContent extends StatelessWidget {
  const _SearchTabContent({
    required this.controller,
    required this.onQueryChanged,
    required this.recentQueries,
    required this.onApplyQuery,
    required this.query,
    required this.searching,
    required this.error,
    required this.results,
    required this.progress,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final List<String> recentQueries;
  final ValueChanged<String> onApplyQuery;
  final String query;
  final bool searching;
  final String? error;
  final List<PokemonSummary> results;
  final DexProgress progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StickerCard(
          variant: StickerVariant.deep,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppZh.searchPrompt,
                style: SecondaryTypography.onGradient.h15,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                onChanged: onQueryChanged,
                spellCheckConfiguration:
                    const SpellCheckConfiguration.disabled(),
                style: SecondaryTypography.onCard.small12.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  hintText: AppZh.searchPlaceholder,
                  hintStyle: SecondaryTypography.onCard.small12.copyWith(
                    color: TitoColors.mutedInk,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: TitoColors.deepBlue,
                  ),
                  filled: true,
                  fillColor: TitoColors.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(TitoRadii.md),
                    borderSide: const BorderSide(
                      color: TitoColors.ink,
                      width: 3,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(TitoRadii.md),
                    borderSide: const BorderSide(
                      color: TitoColors.ink,
                      width: 3,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(TitoRadii.md),
                    borderSide: const BorderSide(
                      color: TitoColors.softYellow,
                      width: 3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (recentQueries.isNotEmpty) ...[
          const SizedBox(height: 12),
          StickerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppZh.searchRecent, style: SecondaryTypography.onCard.h15),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: recentQueries
                      .map(
                        (recent) => _SearchQueryChip(
                          label: recent,
                          onTap: () => onApplyQuery(recent),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (query.isEmpty)
          const _SearchIdlePlaceholder()
        else if (searching)
          const Center(child: CircularProgressIndicator())
        else if (error != null)
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
                Text(
                  error!,
                  style: SecondaryTypography.onCard.small12.copyWith(
                    color: TitoColors.mutedInk,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          )
        else if (results.isEmpty)
          StickerCard(
            child: Text(
              AppZh.searchNoResults,
              style: SecondaryTypography.onCard.body14.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final entry = results[index];
              final status = dexRepository.statusFor(entry.id, progress);
              return _SearchResultRow(
                entry: entry,
                status: status,
                onTap: () => context.push('/dex/${entry.id}'),
              );
            },
          ),
        const SizedBox(height: 16),
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppZh.dexReferenceTitle,
                style: SecondaryTypography.onCard.h15,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    onPressed: () => context.push('/dex/moves'),
                    label: Text(AppZh.dexReferenceMoves),
                  ),
                  ActionChip(
                    onPressed: () => context.push('/dex/abilities'),
                    label: Text(AppZh.dexReferenceAbilities),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchIdlePlaceholder extends StatelessWidget {
  const _SearchIdlePlaceholder();

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      variant: StickerVariant.sky,
      child: Text(
        AppZh.searchEmptyHint,
        style: SecondaryTypography.onCard.small12.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SearchQueryChip extends StatelessWidget {
  const _SearchQueryChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      backgroundColor: TitoColors.card,
      side: const BorderSide(color: TitoColors.ink, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      label: Text(
        label,
        style: SecondaryTypography.onCard.small12.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.entry,
    required this.status,
    required this.onTap,
  });

  final PokemonSummary entry;
  final DexEncounterStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final variant = switch (status) {
      DexEncounterStatus.caught => StickerVariant.mint,
      DexEncounterStatus.seen => StickerVariant.sky,
      DexEncounterStatus.unknown => StickerVariant.cream,
    };

    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: BorderRadius.circular(DeviceLayout.rLg(context)),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            StickerCard(
              variant: variant,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  DexSpriteImage(
                    source: entry.displaySpritePath,
                    height: 48,
                    width: 48,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${entry.id.toString().padLeft(3, '0')} ${entry.nameZh}',
                          style: SecondaryTypography.onCard.body14.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TypeChipRow(
                          types: entry.types.map(typeNameZh).toList(),
                          typeKeys: entry.types,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (status == DexEncounterStatus.caught)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: TitoColors.mint,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
