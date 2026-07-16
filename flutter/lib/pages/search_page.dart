import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/dex/dex_models.dart';
import '../features/dex/dex_progress.dart';
import '../features/dex/dex_repository.dart';
import '../features/dex/type_chart.dart';
import '../features/game/game_edition_repository.dart';
import '../pages/dex/dex_json_reference_page.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/error_text.dart';
import '../theme/device_layout.dart';
import '../theme/tito_font_scale.dart';
import '../widgets/companion_tools_panel.dart';
import '../widgets/dex_sprite_image.dart';
import '../widgets/handheld_input.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';
import '../widgets/tito_loading_panel.dart';
import '../widgets/tito_animated_size_switcher.dart';

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
  int _hubSegment = 0;
  bool _initialQueryApplied = false;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _loadRecentQueries();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialQueryApplied) {
      return;
    }
    final query = GoRouterState.of(context).uri.queryParameters['q'];
    if (query == null || query.isEmpty) {
      return;
    }
    _initialQueryApplied = true;
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _runSearch(query);
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
    final edition = gameEditionRepository.edition;

    return TitoFontScale(
      multiplier: 1.0,
      child: Material(
        type: MaterialType.transparency,
        child: SecondaryPageScaffold(
          title: '${AppZh.navSearch} · ${edition.labelZh}',
          children: [
            _SearchHubSegmentBar(
              selected: _hubSegment,
              onSelected: (index) => setState(() => _hubSegment = index),
            ),
            const SizedBox(height: 12),
            // Keyed content swap without a custom transition.
            TitoAnimatedSizeSwitcher(
              switchKey: ValueKey<int>(_hubSegment),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: switch (_hubSegment) {
                  0 => _searchSegment(context),
                  1 => _referenceSegment(context),
                  _ => _battleSegment(context),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Key get _searchResultsSwitchKey {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      return const ValueKey<String>('search-idle');
    }
    if (_searching) {
      return const ValueKey<String>('search-loading');
    }
    if (_error != null) {
      return ValueKey<String>('search-error-${_error.hashCode}');
    }
    if (_results.isEmpty) {
      return const ValueKey<String>('search-empty');
    }
    return ValueKey<String>('search-results-${_results.length}');
  }

  List<Widget> _searchSegment(BuildContext context) {
    final query = _controller.text.trim();

    return [
      StickerCard(
        variant: StickerVariant.deep,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppZh.searchPrompt, style: SecondaryTypography.onGradient.h15),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
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
                    width: TitoBorders.card,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TitoRadii.md),
                  borderSide: const BorderSide(
                    color: TitoColors.ink,
                    width: TitoBorders.card,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TitoRadii.md),
                  borderSide: const BorderSide(
                    color: TitoColors.softYellow,
                    width: TitoBorders.card,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      if (_recentQueries.isNotEmpty) ...[
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
                children: _recentQueries
                    .map(
                      (recent) => _SearchQueryChip(
                        label: recent,
                        onTap: () => _applyQuery(recent),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      TitoAnimatedSizeSwitcher(
        switchKey: _searchResultsSwitchKey,
        child: _searchResultsBody(context, query),
      ),
    ];
  }

  Widget _searchResultsBody(BuildContext context, String query) {
    if (query.isEmpty) {
      return const _SearchIdlePlaceholder();
    }
    if (_searching) {
      return const TitoLoadingPanel(
        message: AppZh.searchLoading,
        compact: true,
        showSkeleton: false,
      );
    }
    if (_error != null) {
      return StickerCard(
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
              _error!,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return StickerCard(
        child: Text(
          AppZh.searchNoResults,
          style: SecondaryTypography.onCard.body14.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final entry = _results[index];
        final status = dexRepository.statusFor(entry.id, _progress);
        return _SearchResultRow(
          entry: entry,
          status: status,
          onTap: () => context.push('/dex/${entry.id}'),
        );
      },
    );
  }

  List<Widget> _referenceSegment(BuildContext context) {
    return [
      StickerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppZh.searchHubDataTitle,
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
                ActionChip(
                  onPressed: () => openDexJsonReference(
                    context,
                    title: AppZh.searchRefNatures,
                    cdnPath: '/v3/natures.json',
                  ),
                  label: Text(AppZh.searchRefNatures),
                ),
                ActionChip(
                  onPressed: () => openDexJsonReference(
                    context,
                    title: AppZh.searchRefEggGroups,
                    cdnPath: '/v3/egg_groups.json',
                  ),
                  label: Text(AppZh.searchRefEggGroups),
                ),
                ActionChip(
                  onPressed: () => openDexJsonReference(
                    context,
                    title: AppZh.searchRefItems,
                    cdnPath: '/v3/items.json',
                  ),
                  label: Text(AppZh.searchRefItems),
                ),
                ActionChip(
                  onPressed: () => openDexJsonReference(
                    context,
                    title: AppZh.searchRefWeather,
                    cdnPath: '/v3/weather.json',
                  ),
                  label: Text(AppZh.searchRefWeather),
                ),
                ActionChip(
                  onPressed: () => openDexJsonReference(
                    context,
                    title: AppZh.searchRefTerrains,
                    cdnPath: '/v3/terrains.json',
                  ),
                  label: Text(AppZh.searchRefTerrains),
                ),
                ActionChip(
                  onPressed: () => openDexJsonReference(
                    context,
                    title: AppZh.searchRefStatus,
                    cdnPath: '/v3/status_conditions.json',
                  ),
                  label: Text(AppZh.searchRefStatus),
                ),
                ActionChip(
                  onPressed: () => context.push('/dex'),
                  label: Text(AppZh.searchHubRegionalDex),
                ),
                ActionChip(
                  onPressed: () => context.push('/dex/quiz'),
                  avatar: const Icon(Icons.help_center_rounded, size: 16),
                  label: Text(AppZh.quizTitle),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _battleSegment(BuildContext context) {
    return [
      ListenableBuilder(
        listenable: gameEditionRepository,
        builder: (context, _) {
          final edition = gameEditionRepository.edition;
          return StickerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppZh.searchHubBattleTitle,
                  style: SecondaryTypography.onCard.h15,
                ),
                const SizedBox(height: 4),
                Text(
                  AppZh.companionToolsSubtitle(edition.labelZh),
                  style: SecondaryTypography.onCard.small12.copyWith(
                    color: TitoColors.mutedInk,
                  ),
                ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 12),
      CompanionToolsPanel(journey: widget.journey),
    ];
  }
}

class _SearchHubSegmentBar extends StatelessWidget {
  const _SearchHubSegmentBar({
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  static const _labels = [
    AppZh.searchHubSearch,
    AppZh.searchHubReference,
    AppZh.searchHubBattle,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length, (index) {
        final isSelected = index == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(TitoRadii.sm),
                child: Ink(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? TitoColors.softYellow : TitoColors.card,
                    borderRadius: BorderRadius.circular(TitoRadii.sm),
                    border: Border.all(color: TitoColors.ink, width: 2),
                  ),
                  child: Text(
                    _labels[index],
                    textAlign: TextAlign.center,
                    style: SecondaryTypography.onCard.small12.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
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
