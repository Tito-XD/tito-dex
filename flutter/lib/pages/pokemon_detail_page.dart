import 'package:flutter/material.dart';

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
        _moveGameEdition.slug == edition.slug) {
      return;
    }
    setState(() {
      _gameEdition = edition;
      _moveGameEdition = edition;
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
    });
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _errorCopy = null;
    });
    try {
      final detail = await dexRepository.getDetail(widget.pokemonId);
      final abilities = await dexRepository.abilitiesForPokemon(widget.pokemonId);
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
                ? _ErrorBody(
                    copy: errorCopy,
                    onRetry: _loadDetail,
                  )
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
                          // v0.4.1: AnimatedSize tab body (experimental)
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
            Text(
              AppZh.dexStabEffective,
              style: SecondaryTypography.onCard.h15,
            ),
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
    final obtainGroups = _allObtainGroups(detail);
    final sections = <Widget>[
      if (obtainGroups.isNotEmpty)
        ...[
          for (var i = 0; i < obtainGroups.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            ObtainLocationsCard(
              locations: obtainGroups[i].$2,
              gameLabel: gameEditionLabelForVersionGroup(obtainGroups[i].$1),
            ),
          ],
        ]
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
              Text(
                AppZh.dexEvolution,
                style: SecondaryTypography.onCard.h15,
              ),
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

  List<Widget> _movesSections(PokemonDetail detail) {
    final moveSetKey = gameEditionMoveSetKey(_moveGameEdition);
    final moveSet = detail.moveSetForKey(moveSetKey);

    return [
      _MoveMethodFilterBar(
        selected: _moveMethodFilter,
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
      const SizedBox(height: 12),
      // v0.4.1: AnimatedSize move method panels (experimental)
      TitoAnimatedSizeSwitcher(
        switchKey: ValueKey<_MoveMethodFilter>(_moveMethodFilter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _movePanelsForFilter(moveSet),
        ),
      ),
    ];
  }

  List<Widget> _movePanelsForFilter(PokemonMoveSet moveSet) {
    return switch (_moveMethodFilter) {
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
          MoveCategoryPanel(
            title: moveMethodLabelZh('egg'),
            moves: moveSet.egg,
          ),
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
  });

  final _MoveMethodFilter selected;
  final ValueChanged<_MoveMethodFilter> onSelected;

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
    return Row(
      children: [
        for (final entry in _order) ...[
          if (entry != _order.first) const SizedBox(width: 5),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelected(entry),
                borderRadius: BorderRadius.circular(TitoRadii.sm),
                child: Ink(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: selected == entry
                        ? TitoColors.softYellow
                        : TitoColors.card,
                    borderRadius: BorderRadius.circular(TitoRadii.sm),
                    border: Border.all(color: TitoColors.ink, width: 2),
                  ),
                  child: Text(
                    _labels[entry]!,
                    textAlign: TextAlign.center,
                    style: SecondaryTypography.onCard.small12.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
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
    return Container(
      decoration: const BoxDecoration(
        color: TitoColors.card,
        border: Border(
          top: BorderSide(color: TitoColors.ink, width: 2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(_labels.length, (index) {
            final selected = index == currentIndex;
            return Expanded(
              child: HandheldFocusDecorator(
                onActivate: () => onSelected(index),
                child: Material(
                  color: selected
                      ? TitoColors.softYellow
                      : Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelected(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
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
        ),
      ),
    );
  }
}
