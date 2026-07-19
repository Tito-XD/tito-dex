import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/dex/dex_game_scope.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
import '../features/dex/dex_settings_repository.dart';
import '../features/dex/type_chart.dart';
import '../features/game/game_edition.dart';
import '../features/game/game_edition_repository.dart';
import '../features/game/game_catalog.dart';
import '../l10n/app_zh.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/error_text.dart';
import '../theme/tito_font_scale.dart';
import '../widgets/handheld_input.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/pokemon_detail_sections.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';
import '../widgets/sticker_pressable.dart';
import '../widgets/tito_skeleton.dart';
import '../widgets/tito_skeleton_gate.dart';
import '../widgets/tito_animated_size_switcher.dart';

enum _MoveMethodFilter { level, machine, egg, tutor }

class PokemonDetailPage extends StatefulWidget {
  const PokemonDetailPage({super.key, required this.pokemonId});

  final int pokemonId;

  @override
  State<PokemonDetailPage> createState() => _PokemonDetailPageState();
}

class _PokemonDetailPageState extends State<PokemonDetailPage> {
  PokemonDetail? _detail;
  List<PokemonAbility> _abilities = const [];
  (String, String)? _errorCopy;
  bool _loading = true;
  int _currentTabIndex = 0;
  GameEdition _gameEdition = defaultGameEdition;
  GameEdition _moveGameEdition = defaultGameEdition;
  GameEdition _obtainGameEdition = defaultGameEdition;
  _MoveMethodFilter _moveMethodFilter = _MoveMethodFilter.level;

  @override
  void initState() {
    super.initState();
    gameEditionRepository.addListener(_onGlobalEditionChanged);
    _loadDefaultMoveVersion();
    _loadDetail();
  }

  @override
  void dispose() {
    gameEditionRepository.removeListener(_onGlobalEditionChanged);
    super.dispose();
  }

  void _onGlobalEditionChanged() {
    final edition = gameEditionRepository.edition;
    if (_gameEdition.slug == edition.slug &&
        _moveGameEdition.slug == edition.slug &&
        _obtainGameEdition.slug == edition.slug) {
      return;
    }
    setState(() {
      _gameEdition = edition;
      _moveGameEdition = edition;
      _obtainGameEdition = edition;
    });
  }

  Future<void> _loadDefaultMoveVersion() async {
    final edition = await dexSettingsRepository.loadDefaultGameEdition();
    if (!mounted) {
      return;
    }
    setState(() {
      _gameEdition = edition;
      _moveGameEdition = edition;
      _obtainGameEdition = edition;
    });
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _errorCopy = null;
    });
    try {
      final detail = await dexRepository.getDetail(widget.pokemonId);
      final abilities = await dexRepository.abilitiesForPokemon(
        widget.pokemonId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _abilities = abilities;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorCopy = splitUserFacingError(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final errorCopy = _errorCopy;
    final padding = DeviceLayout.pagePadding(context);

    return TitoFontScale(
      multiplier: 1.0,
      // This page owns the only warm-white bottom bar in the app — match
      // the system nav bar to it instead of the global deep blue (v0.6.7).
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          systemNavigationBarColor: TitoColors.card,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Column(
        children: [
          Expanded(
            child: TitoSkeletonGate(
              loading: _loading,
              skeleton: ListView(
                padding: padding,
                children: const [
                  TitoDetailHeaderSkeleton(),
                  SizedBox(height: 12),
                  TitoCardSkeleton(height: 140),
                  SizedBox(height: 12),
                  TitoCardSkeleton(height: 88),
                ],
              ),
              child: errorCopy != null
                  ? _ErrorBody(copy: errorCopy, onRetry: _loadDetail)
                  : detail == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: padding.copyWith(bottom: 12),
                      children: [
                        const SecondaryPageAppBar(
                          title: AppZh.navDex,
                          showSettings: false,
                        ),
                        const SizedBox(height: 8),
                        PokemonDetailHeader(
                          detail: detail,
                          compact: true,
                          showSettingsAction: false,
                        ),
                        const SizedBox(height: 12),
                        // Keyed tab-body swap without a custom transition.
                        TitoAnimatedSizeSwitcher(
                          switchKey: ValueKey<int>(_currentTabIndex),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _tabSections(detail, _currentTabIndex),
                          ),
                        ),
                        const SizedBox(height: 72),
                      ],
                    ),
            ),
          ),
          _DetailBottomTabs(
            currentIndex: _currentTabIndex,
            onSelected: (index) {
              if (_currentTabIndex != index) {
                setState(() => _currentTabIndex = index);
              }
            },
          ),
        ],
        ),
      ),
    );
  }

  List<Widget> _tabSections(PokemonDetail detail, int tabIndex) {
    return switch (tabIndex) {
      0 => _introSections(detail),
      1 => _basicSections(detail),
      2 => _obtainSections(detail),
      _ => _movesSections(detail),
    };
  }

  List<FlavorTextEntry> _flavorEntriesForEdition(PokemonDetail detail) {
    // v0.4.0 §7.3: show all CDN flavor entries; carousel starts on global edition.
    return detail.flavorEntries;
  }

  int _flavorInitialIndex(PokemonDetail detail) {
    final entries = detail.flavorEntries;
    if (entries.isEmpty) {
      return 0;
    }
    int indexFor(GameEdition edition) => entries.indexWhere(
      (entry) =>
          entry.versionGroup == edition.dataVersionGroupKey ||
          entry.gameEdition == edition.slug,
    );
    final primary = indexFor(_gameEdition);
    if (primary >= 0) {
      return primary;
    }
    final fallback = gameEditionFromSlug(_gameEdition.fallbackSlug);
    if (fallback != null) {
      final fb = indexFor(fallback);
      if (fb >= 0) {
        return fb;
      }
    }
    return 0;
  }

  List<(String, List<ObtainLocationEntry>)> _allObtainGroups(
    PokemonDetail detail,
  ) {
    final seen = <String>{};
    final groups = <(String, List<ObtainLocationEntry>)>[];
    for (final edition in GameEdition.all) {
      final key = edition.dataVersionGroupKey;
      if (seen.contains(key)) {
        continue;
      }
      final locations = detail.obtainLocationsByGame[key];
      if (locations != null && locations.isNotEmpty) {
        seen.add(key);
        groups.add((key, locations));
      }
    }
    for (final entry in detail.obtainLocationsByGame.entries) {
      if (entry.value.isEmpty || seen.contains(entry.key)) {
        continue;
      }
      seen.add(entry.key);
      groups.add((entry.key, entry.value));
    }
    if (groups.isEmpty && detail.obtainLocations.isNotEmpty) {
      groups.add(('heartgold-soulsilver', detail.obtainLocations));
    }
    return groups;
  }

  List<Widget> _introSections(PokemonDetail detail) => [
    FlavorTextCarousel(
      entries: _flavorEntriesForEdition(detail),
      initialPage: _flavorInitialIndex(detail),
      gameEdition: _gameEdition,
      onPickEdition: () async {
        final picked = await showGameEditionPicker(
          context,
          selected: _gameEdition,
        );
        if (picked != null && mounted) {
          setState(() => _gameEdition = picked);
          await dexSettingsRepository.saveDefaultGameEdition(picked);
        }
      },
    ),
    const SizedBox(height: 12),
    IntroMetaCard(detail: detail),
    const SizedBox(height: 12),
    AbilitiesCard(abilities: _abilities),
    const SizedBox(height: 12),
    StickerCard(
      child: Text(
        AppZh.dexApiNote,
        style: SecondaryTypography.onCard.small12.copyWith(
          color: TitoColors.mutedInk,
          height: 1.4,
        ),
      ),
    ),
  ];

  List<Widget> _basicSections(PokemonDetail detail) {
    return [
      if (detail.baseStats != null) ...[
        BaseStatsSection(stats: detail.baseStats!),
        const SizedBox(height: 12),
      ],
      InteractiveTypeEffectivenessCard(
        types: detail.summary.types,
        abilities: _abilities,
        generation: _gameEdition.generation,
        abilityPickerLabel: AppZh.dexAbilityFilter,
      ),
      const SizedBox(height: 12),
      StickerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppZh.dexStabEffective, style: SecondaryTypography.onCard.h15),
            const SizedBox(height: 8),
            TypeChipRow(
              types: detail.stabSuperEffective,
              typeKeys: detail.stabSuperEffective
                  .map(typeEnForZh)
                  .whereType<String>()
                  .toList(),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _obtainSections(PokemonDetail detail) {
    // v0.6.7 fix: the obtain tab used to dump every version group and
    // ignored the edition pickers entirely — now it follows its own
    // selected edition, same pattern as the moves tab.
    final obtainGroups = _allObtainGroups(detail);
    final editionKey = _obtainGameEdition.dataVersionGroupKey;
    final matchIndex = obtainGroups.indexWhere(
      (group) => group.$1 == editionKey,
    );
    final locations = matchIndex >= 0 ? obtainGroups[matchIndex].$2 : null;

    final sections = <Widget>[
      HandheldFocusDecorator(
        onActivate: () => _pickObtainGameEdition(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _pickObtainGameEdition,
            child: Text(
              AppZh.dexObtainScope(gameEditionLabelZh(_obtainGameEdition)),
              style: SecondaryTypography.onGradient.body14.copyWith(
                decoration: TextDecoration.underline,
                decorationColor: TitoColors.skyBlue,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      if (locations != null && locations.isNotEmpty)
        ObtainLocationsCard(
          locations: locations,
          gameLabel: gameEditionLabelForVersionGroup(editionKey),
        )
      else
        StickerCard(
          child: Text(
            AppZh.dexObtainEmptyVersion,
            style: SecondaryTypography.onCard.body14.copyWith(
              color: TitoColors.mutedInk,
            ),
          ),
        ),
    ];

    if (detail.evolutionChain != null) {
      sections.addAll([
        const SizedBox(height: 12),
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppZh.dexEvolution, style: SecondaryTypography.onCard.h15),
              const SizedBox(height: 12),
              EvolutionChainVerticalView(
                root: detail.evolutionChain!,
                highlightId: detail.summary.id,
              ),
            ],
          ),
        ),
      ]);
    }

    return sections;
  }

  Future<void> _pickObtainGameEdition() async {
    final picked = await showGameEditionGridPicker(
      context,
      selected: _obtainGameEdition,
    );
    if (picked != null && mounted) {
      setState(() => _obtainGameEdition = picked);
      await dexSettingsRepository.saveDefaultGameEdition(picked);
    }
  }

  static List<PokemonMove> _movesForMethod(
    _MoveMethodFilter filter,
    PokemonMoveSet moveSet,
  ) => switch (filter) {
    _MoveMethodFilter.level => moveSet.levelUp,
    _MoveMethodFilter.machine => moveSet.machine,
    _MoveMethodFilter.egg => moveSet.egg,
    _MoveMethodFilter.tutor => moveSet.tutor,
  };

  List<Widget> _movesSections(PokemonDetail detail) {
    final moveSetKey = gameEditionMoveSetKey(_moveGameEdition);
    final (moveSetSourceKey, moveSet) = detail.resolvedMoveSetForKey(
      moveSetKey,
    );
    final moveSetBorrowed =
        moveSetSourceKey != null && moveSetSourceKey != moveSetKey;

    // Species without level-up moves (or without the currently selected
    // method) land on their first non-empty method instead of a blank panel.
    var effectiveFilter = _moveMethodFilter;
    if (_movesForMethod(effectiveFilter, moveSet).isEmpty) {
      for (final candidate in _MoveMethodFilterBar._order) {
        if (_movesForMethod(candidate, moveSet).isNotEmpty) {
          effectiveFilter = candidate;
          break;
        }
      }
    }

    return [
      _MoveMethodFilterBar(
        selected: effectiveFilter,
        emptyMethods: {
          for (final entry in _MoveMethodFilterBar._order)
            if (_movesForMethod(entry, moveSet).isEmpty) entry,
        },
        onSelected: (filter) => setState(() => _moveMethodFilter = filter),
      ),
      const SizedBox(height: 12),
      HandheldFocusDecorator(
        onActivate: () => _pickMoveGameEdition(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _pickMoveGameEdition,
            child: Text(
              AppZh.dexMovesScope(gameEditionLabelZh(_moveGameEdition)),
              style: SecondaryTypography.onGradient.body14.copyWith(
                decoration: TextDecoration.underline,
                decorationColor: TitoColors.skyBlue,
              ),
            ),
          ),
        ),
      ),
      if (moveSetBorrowed) ...[
        const SizedBox(height: 6),
        Text(
          AppZh.dexDataFallbackNote(
            gameEditionLabelForVersionGroup(moveSetSourceKey),
          ),
          style: SecondaryTypography.onGradient.small12.copyWith(
            color: TitoColors.softYellow,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
      const SizedBox(height: 12),
      // Keyed move-method panel swap without a custom transition.
      TitoAnimatedSizeSwitcher(
        switchKey: ValueKey<_MoveMethodFilter>(effectiveFilter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _movePanelsForFilter(effectiveFilter, moveSet),
        ),
      ),
    ];
  }

  List<Widget> _movePanelsForFilter(
    _MoveMethodFilter filter,
    PokemonMoveSet moveSet,
  ) {
    return switch (filter) {
      _MoveMethodFilter.level => [
        MoveCategoryPanel(
          title: moveMethodLabelZh('level-up'),
          moves: moveSet.levelUp,
          showLevel: true,
        ),
      ],
      _MoveMethodFilter.machine => [
        MoveCategoryPanel(
          title: moveMethodLabelZh('machine'),
          moves: moveSet.machine,
        ),
      ],
      _MoveMethodFilter.egg => [
        MoveCategoryPanel(title: moveMethodLabelZh('egg'), moves: moveSet.egg),
      ],
      _MoveMethodFilter.tutor => [
        MoveCategoryPanel(
          title: moveMethodLabelZh('tutor'),
          moves: moveSet.tutor,
        ),
      ],
    };
  }

  Future<void> _pickMoveGameEdition() async {
    final picked = await showGameEditionGridPicker(
      context,
      selected: _moveGameEdition,
    );
    if (picked != null && mounted) {
      setState(() => _moveGameEdition = picked);
      await dexSettingsRepository.saveDefaultGameEdition(picked);
    }
  }
}

class _MoveMethodFilterBar extends StatelessWidget {
  const _MoveMethodFilterBar({
    required this.selected,
    required this.onSelected,
    this.emptyMethods = const {},
  });

  final _MoveMethodFilter selected;
  final ValueChanged<_MoveMethodFilter> onSelected;

  /// Methods with no moves for the current game — rendered muted.
  final Set<_MoveMethodFilter> emptyMethods;

  static const _order = [
    _MoveMethodFilter.level,
    _MoveMethodFilter.machine,
    _MoveMethodFilter.egg,
    _MoveMethodFilter.tutor,
  ];

  static const _labels = {
    _MoveMethodFilter.level: AppZh.dexMoveFilterLevel,
    _MoveMethodFilter.machine: AppZh.dexMoveFilterMachine,
    _MoveMethodFilter.egg: AppZh.dexMoveFilterEgg,
    _MoveMethodFilter.tutor: AppZh.dexMoveFilterTutor,
  };

  @override
  Widget build(BuildContext context) {
    // v0.6.7: these were flat ink-bordered boxes that read as labels, not
    // buttons — restyle as pressable sticker chips (same language as the
    // bottom tabs): solid drop shadow, coral when active, muted when the
    // method has no moves for the current game.
    return Row(
      children: [
        for (final entry in _order) ...[
          if (entry != _order.first) const SizedBox(width: 6),
          Expanded(
            child: () {
              final isEmpty = emptyMethods.contains(entry);
              final isSelected = selected == entry;
              final radius = BorderRadius.circular(TitoRadii.sm);
              return HandheldFocusDecorator(
                onActivate: () => onSelected(entry),
                child: StickerPressable(
                  borderRadius: radius,
                  child: Material(
                    color: isSelected
                        ? TitoColors.coral
                        : isEmpty
                        ? TitoColors.card.withValues(alpha: 0.55)
                        : TitoColors.card,
                    borderRadius: radius,
                    child: InkWell(
                      onTap: () => onSelected(entry),
                      borderRadius: radius,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          border: Border.all(
                            color: isEmpty
                                ? TitoColors.ink.withValues(alpha: 0.4)
                                : TitoColors.ink,
                            width: TitoBorders.element,
                          ),
                        ),
                        child: Text(
                          _labels[entry]!,
                          textAlign: TextAlign.center,
                          style: SecondaryTypography.onCard.small12.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? const Color(0xFF4A1B0C)
                                : isEmpty
                                ? TitoColors.mutedInk
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }(),
          ),
        ],
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.copy, required this.onRetry});

  final (String, String) copy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: DeviceLayout.pagePadding(context),
        child: StickerCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                copy.$1,
                style: SecondaryTypography.onCard.body14.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                copy.$2,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onRetry,
                child: const Text(AppZh.dexRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBottomTabs extends StatelessWidget {
  const _DetailBottomTabs({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const _labels = [
    AppZh.dexTabIntro,
    AppZh.dexTabBasic,
    AppZh.dexTabObtain,
    AppZh.dexTabMoves,
  ];

  @override
  Widget build(BuildContext context) {
    // v0.6.7 sticker tabs (detail template): four mini sticker cards,
    // active one goes coral; the press sinks like every other sticker.
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: const BoxDecoration(
        color: TitoColors.card,
        border: Border(top: BorderSide(color: TitoColors.ink, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(_labels.length, (index) {
            final selected = index == currentIndex;
            final radius = BorderRadius.circular(TitoRadii.sm);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == _labels.length - 1 ? 0 : 8,
                ),
                child: HandheldFocusDecorator(
                  onActivate: () => onSelected(index),
                  child: StickerPressable(
                    borderRadius: radius,
                    child: Material(
                      color: selected ? TitoColors.coral : TitoColors.card,
                      borderRadius: radius,
                      child: InkWell(
                        borderRadius: radius,
                        onTap: () => onSelected(index),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            border: Border.all(
                              color: TitoColors.ink,
                              width: TitoBorders.element,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Text(
                            _labels[index],
                            textAlign: TextAlign.center,
                            style: SecondaryTypography.onCard.small12.copyWith(
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? const Color(0xFF4A1B0C)
                                  : TitoColors.mutedInk,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
