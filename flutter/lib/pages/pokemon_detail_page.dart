import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/dex/dex_game_scope.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
import '../features/dex/dex_settings_repository.dart';
import '../features/dex/type_chart.dart';
import '../features/dex/version_availability.dart';
import '../features/game/game_edition.dart';
import '../features/game/game_edition_repository.dart';
import '../l10n/app_zh.dart';
import '../l10n/localized_names.dart';
import '../navigation/tito_route_work.dart';
import '../theme/app_visual_style.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/trainer_journal.dart';
import '../theme/tito_motion.dart';
import '../theme/error_text.dart';
import '../widgets/handheld_input.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/dex_detail_controls.dart';
import '../widgets/dex_detail_picker_sheet.dart';
import '../widgets/pokemon_detail_sections.dart';
import '../widgets/pokemon_obtain_sections.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';
import '../widgets/sticker_pressable.dart';
import '../widgets/tito_skeleton.dart';
import '../widgets/tito_skeleton_gate.dart';
import '../widgets/tito_animated_size_switcher.dart';

enum _MoveMethodFilter { level, machine, egg, tutor }

class PokemonDetailPage extends StatefulWidget {
  const PokemonDetailPage({
    super.key,
    required this.pokemonId,
    this.transitionSummary,
    this.initialDetail,
    this.initialDetailFuture,
    this.initialFormKey,
    this.initialObtainVersion,
  });

  final int pokemonId;
  final PokemonSummary? transitionSummary;

  /// Optional already-decoded detail. A prefetched local bundle entry can land
  /// immediately without replacing the shared-element target mid-flight.
  final PokemonDetail? initialDetail;

  /// A detail read started by the tapped Dex card. It overlaps route motion
  /// without decoding the same bundle entry twice.
  final Future<PokemonDetail>? initialDetailFuture;

  /// Deep-link targets from `/dex/:id?form=&version=`; form identity is checked
  /// against the detail and versions against the known reference scopes.
  final String? initialFormKey;
  final String? initialObtainVersion;

  @override
  State<PokemonDetailPage> createState() => _PokemonDetailPageState();
}

class _PokemonDetailPageState extends State<PokemonDetailPage> {
  PokemonDetail? _detail;
  List<PokemonAbility> _abilities = const [];
  (String, String)? _errorCopy;
  late bool _sharedElementRouteSettled;
  bool _sharedElementSettleRequested = false;
  bool _loading = true;
  int _currentTabIndex = 0;
  GameEdition _gameEdition = defaultGameEdition;
  bool _hasEditionOverride = false;
  _MoveMethodFilter _moveMethodFilter = _MoveMethodFilter.level;
  String? _selectedFormKey;
  Future<Map<String, HeldItemReference>> _heldItemReferencesFuture =
      Future.value(const {});
  Future<Map<int, PokemonDetail>> _chainDetailsFuture = Future.value(const {});

  @override
  void initState() {
    super.initState();
    _sharedElementRouteSettled = widget.transitionSummary == null;
    gameEditionRepository.addListener(_onGlobalEditionChanged);
    if (widget.transitionSummary == null) {
      _loadDefaultMoveVersion();
    } else {
      unawaited(_runAfterIncomingRoute(_loadDefaultMoveVersion));
    }
    if (widget.transitionSummary == null) {
      _loadDetail();
    } else {
      unawaited(_runAfterIncomingRoute(_loadDetail));
    }
    if (!_sharedElementRouteSettled) {
      unawaited(_settleSharedElementAfterIncomingRoute());
    }
  }

  Future<void> _settleSharedElementAfterIncomingRoute() async {
    if (_sharedElementSettleRequested) {
      return;
    }
    _sharedElementSettleRequested = true;
    final routeSettled = await waitForIncomingRouteSettled(context);
    if (!mounted || !routeSettled || _sharedElementRouteSettled) {
      return;
    }
    setState(() => _sharedElementRouteSettled = true);
  }

  @override
  void dispose() {
    gameEditionRepository.removeListener(_onGlobalEditionChanged);
    super.dispose();
  }

  void _onGlobalEditionChanged() {
    if (!mounted || _hasEditionOverride) return;
    setState(() => _gameEdition = gameEditionRepository.edition);
  }

  void _selectEdition(GameEdition edition) {
    setState(() {
      _hasEditionOverride = true;
      _gameEdition = edition;
    });
  }

  Future<void> _runAfterIncomingRoute(Future<void> Function() work) async {
    if (!await waitForIncomingRouteSettled(context) || !mounted) return;
    await work();
  }

  Future<void> _loadDefaultMoveVersion() async {
    final edition = await dexSettingsRepository.loadDefaultGameEdition();
    if (!mounted || _hasEditionOverride) return;
    setState(() => _gameEdition = edition);
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _errorCopy = null;
    });
    try {
      final prefetched = widget.initialDetail;
      final detail =
          prefetched ??
          await (widget.initialDetailFuture ??
              dexRepository.getDetail(widget.pokemonId));
      final abilities = prefetched == null
          ? await dexRepository.abilitiesForPokemon(widget.pokemonId)
          : prefetched.abilities;
      if (!mounted) {
        return;
      }
      final linkedForm = widget.initialFormKey;
      final linkedVersion = widget.initialObtainVersion;
      final selectedFormKey =
          (linkedForm != null &&
              detail.forms.any((form) => form.key == linkedForm))
          ? linkedForm
          : detail.defaultForm?.key;
      final displayDetail = _detailForFormKey(detail, selectedFormKey);
      setState(() {
        _detail = detail;
        _abilities = abilities;
        _selectedFormKey = selectedFormKey;
        if (linkedVersion != null) {
          final linkedEdition = GameEdition.all
              .where(
                (game) => dexDetailExactVersions(game).contains(linkedVersion),
              )
              .firstOrNull;
          if (linkedEdition != null) {
            _gameEdition = linkedEdition.withFlavor(linkedVersion);
            _hasEditionOverride = true;
          }
        }
        _prepareObtainSupport(displayDetail);
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
    final displayDetail = detail == null ? null : _displayDetail(detail);
    final errorCopy = _errorCopy;
    final padding = DeviceLayout.pagePadding(context);
    final bodyPadding = EdgeInsets.fromLTRB(padding.left, 8, padding.right, 12);
    final transitionHeader = widget.transitionSummary == null
        ? null
        : PokemonDetailTransitionHeader(summary: widget.transitionSummary!);
    final keepSharedElementTarget =
        transitionHeader != null && !_sharedElementRouteSettled;

    // Let the page theme continue through the tabs and system navigation area.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
        systemNavigationBarIconBrightness:
            Theme.of(context).scaffoldBackgroundColor.computeLuminance() > .45
            ? Brightness.dark
            : Brightness.light,
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              padding.top,
              padding.right,
              0,
            ),
            child: SecondaryPageAppBar(
              title: AppZh.navDex,
              showSettings: false,
            ),
          ),
          Expanded(
            child: keepSharedElementTarget
                ? ListView(
                    key: const ValueKey('pokemon-detail-shared-element-stage'),
                    padding: bodyPadding,
                    children: [transitionHeader],
                  )
                : TitoSkeletonGate(
                    loading: _loading,
                    // Shared-element entries skip the skeleton cards: the
                    // geometry-aligned transition header stays put and the
                    // real content fills in with its arrival animation, so
                    // nothing flashes when the detail data lands. Deep links
                    // (no transition summary) keep the full skeleton.
                    skeleton: ListView(
                      padding: bodyPadding,
                      children: [
                        if (transitionHeader != null)
                          transitionHeader
                        else ...[
                          const TitoDetailHeaderSkeleton(),
                          const SizedBox(height: 12),
                          const TitoCardSkeleton(height: 140),
                          const SizedBox(height: 12),
                          const TitoCardSkeleton(height: 88),
                        ],
                      ],
                    ),
                    placeholder: transitionHeader == null
                        ? const SizedBox.shrink()
                        : ListView(
                            padding: bodyPadding,
                            children: [transitionHeader],
                          ),
                    child: errorCopy != null
                        ? _ErrorBody(copy: errorCopy, onRetry: _loadDetail)
                        : displayDetail == null
                        ? const SizedBox.shrink()
                        : ListView(
                            padding: bodyPadding,
                            children: [
                              // The fill lines (dex label, genus subtitle)
                              // fade in once when the loaded header first
                              // appears; the progress is owned here so the
                              // Hero shuttle's copy stays fully opaque.
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: TitoMotion.disabled(context) ? 1 : 0,
                                  end: 1,
                                ),
                                duration: TitoMotion.duration(
                                  context,
                                  TitoMotion.standard,
                                ),
                                curve: Curves.easeOutCubic,
                                builder: (context, fill, _) =>
                                    PokemonDetailHeader(
                                      detail: displayDetail,
                                      compact: true,
                                      showSettingsAction: false,
                                      fillProgress: fill,
                                    ),
                              ),
                              _DetailArrival(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    DexDetailControls(
                                      speciesNameZh:
                                          _detail?.summary.displayName ?? '',
                                      forms: displayDetail.forms,
                                      selectedFormKey: _selectedFormKey,
                                      edition: _gameEdition,
                                      onEditionChanged: _selectEdition,
                                      onFormChanged: (form) {
                                        setState(() {
                                          _selectedFormKey = form.key;
                                          _prepareObtainSupport(
                                            _detail!.forForm(form),
                                          );
                                          _abilities =
                                              form.abilities.isEmpty &&
                                                  (form.isDefault ||
                                                      form.isCosmetic)
                                              ? _detail!.abilities
                                              : form.abilities;
                                        });
                                      },
                                    ),
                                    // Keyed tab-body swap without a custom transition.
                                    TitoAnimatedSizeSwitcher(
                                      switchKey: ValueKey<int>(
                                        _currentTabIndex,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: _tabSections(
                                          displayDetail,
                                          _currentTabIndex,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height:
                                          _DetailBottomTabs.listBottomClearance,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
          ),
          _DetailBottomTabs(
            selectedColor: typeTileColor(
              displayDetail?.summary.types.firstOrNull ?? 'normal',
            ),
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

  PokemonDetail _displayDetail(PokemonDetail detail) {
    return _detailForFormKey(detail, _selectedFormKey);
  }

  PokemonDetail _detailForFormKey(PokemonDetail detail, String? selectedKey) {
    if (selectedKey == null) {
      return detail;
    }
    for (final form in detail.forms) {
      if (form.key == selectedKey) {
        return detail.forForm(form);
      }
    }
    return detail;
  }

  EvolutionNode? _filteredEvolutionChain(PokemonDetail detail) =>
      detail.evolutionChain?.filteredForForm(
        _selectedFormKey,
        rootSpritePath: _selectedForm?.localSpritePath,
      );

  void _prepareObtainSupport(PokemonDetail detail) {
    _heldItemReferencesFuture = detail.heldItems.isEmpty
        ? Future.value(const {})
        : dexRepository
              .getReferenceEntries('items.json')
              .then(heldItemReferencesBySlug)
              .catchError((Object _) => <String, HeldItemReference>{});
    final chain = _filteredEvolutionChain(detail);
    _chainDetailsFuture = chain == null
        ? Future.value(const {})
        : _loadChainDetails(chain);
  }

  Future<Map<int, PokemonDetail>> _loadChainDetails(EvolutionNode chain) async {
    final ids = <int>{};
    void collect(EvolutionNode node) {
      ids.add(node.id);
      for (final child in node.children) {
        collect(child);
      }
    }

    collect(chain);
    final details = await Future.wait(ids.map(dexRepository.getDetail));
    return {for (final detail in details) detail.summary.id: detail};
  }

  PokemonFormDetail? get _selectedForm {
    final detail = _detail;
    final key = _selectedFormKey;
    if (detail == null || key == null) {
      return null;
    }
    for (final form in detail.forms) {
      if (form.key == key) {
        return form;
      }
    }
    return null;
  }

  /// Fallback annotation for non-default forms whose data is borrowed or
  /// incomplete — so "空白" and "游戏中不存在" stop looking identical.
  Widget? _formDataQualityNote(BuildContext context) {
    final form = _selectedForm;
    if (form == null) {
      return null;
    }
    // This note sits directly on the page background (not inside a card), so
    // it reads with the theme-aware page ink; only the status labels keep an
    // accent so "blank" and "not in this game" stay distinguishable.
    final pageStyle = SecondaryTypography.onPage(context).small12;
    final statusColor = appVisualStyle.usesFlatUi
        ? Theme.of(context).colorScheme.tertiary
        : TitoColors.softYellow;
    final statusLabels = pokemonFormStatusLabels(
      form,
      versionGroup: _gameEdition.dataVersionGroupKey,
    );
    final introduced = form.introducedVersionGroup == null
        ? null
        : AppZh.dexFormIntroducedIn(
            gameEditionLabelForVersionGroup(form.introducedVersionGroup!),
          );
    final String? qualityCopy;
    if (form.inheritsFromDefault) {
      qualityCopy = AppZh.dexFormDataInherited;
    } else if (form.dataCompleteness == 'partial') {
      qualityCopy = AppZh.dexFormDataPartial;
    } else {
      qualityCopy = null;
    }
    if (statusLabels.isEmpty && qualityCopy == null && introduced == null) {
      return null;
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final label in statusLabels)
          Text(
            '· $label',
            style: pageStyle.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        if (qualityCopy != null)
          Text(
            qualityCopy,
            style: pageStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        if (introduced != null)
          Text(
            introduced,
            style: pageStyle.copyWith(fontWeight: FontWeight.w700),
          ),
      ],
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
    if (_gameEdition.isGeneral) return detail.flavorEntries;
    final exact = _gameEdition.selectedFlavor;
    final versions = exact == null ? null : accessibleEncounterVersions(exact);
    return detail.flavorEntries
        .where(
          (entry) => versions != null
              ? versions.contains(entry.version)
              : entry.versionGroup == _gameEdition.dataVersionGroupKey ||
                    _gameEdition.flavorVersions.contains(entry.version),
        )
        .toList();
  }

  int _flavorInitialIndex(PokemonDetail detail) => 0;

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
      key: ValueKey(
        'flavor-${_gameEdition.slug}-${_gameEdition.selectedFlavor}-$_selectedFormKey',
      ),
      entries: _flavorEntriesForEdition(detail),
      initialPage: _flavorInitialIndex(detail),
      gameEdition: _gameEdition,
    ),
    const SizedBox(height: 12),
    IntroMetaCard(detail: detail),
    const SizedBox(height: 12),
    AbilitiesCard(abilities: _abilitiesForEdition(detail)),
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

  List<PokemonAbility> _abilitiesForEdition(PokemonDetail detail) {
    if (_gameEdition.isGeneral) return detail.abilities;
    if (_gameEdition.generation < 3) return const [];
    return detail.abilitiesByGame[_gameEdition.dataVersionGroupKey] ??
        (detail.abilities.isNotEmpty ? detail.abilities : _abilities);
  }

  List<Widget> _basicSections(PokemonDetail detail) {
    final qualityNote = _formDataQualityNote(context);
    return [
      if (qualityNote != null) ...[qualityNote, const SizedBox(height: 8)],
      if (detail.baseStats != null) ...[
        BaseStatsSection(stats: detail.baseStats!),
        const SizedBox(height: 12),
      ],
      InteractiveTypeEffectivenessCard(
        types: detail.summary.types,
        abilities: _abilitiesForEdition(detail),
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
    if (_gameEdition.isGeneral) return _generalObtainSections(detail);
    final obtainGroups = _allObtainGroups(detail);
    final editionKey = _gameEdition.dataVersionGroupKey;
    final exactVersions =
        encounterVersionsByVersionGroup[editionKey] ?? const <String>[];
    final selectedVersion =
        _gameEdition.selectedFlavor ??
        (exactVersions.length == 1 ? exactVersions.single : null);
    final List<ObtainLocationEntry>? locations;
    if (selectedVersion != null) {
      locations = [
        for (final version in accessibleEncounterVersions(selectedVersion))
          ...?detail.obtainLocationsByVersion[version],
      ];
    } else {
      final matchIndex = obtainGroups.indexWhere(
        (group) => group.$1 == editionKey,
      );
      locations = matchIndex >= 0 ? obtainGroups[matchIndex].$2 : null;
    }

    final sections = <Widget>[
      if (locations != null && locations.isNotEmpty)
        ObtainLocationsCard(
          locations: locations,
          gameLabel: selectedVersion == null
              ? gameEditionLabelForVersionGroup(editionKey)
              : flavorVersionLabelZh(selectedVersion),
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

    final heldItemVersionKeys = selectedVersion == null
        ? exactVersions
        : accessibleEncounterVersions(selectedVersion).toList();
    if (detail.heldItems.isNotEmpty && heldItemVersionKeys.isNotEmpty) {
      sections.addAll([
        const SizedBox(height: 12),
        PokemonHeldItemsCard(
          items: detail.heldItems,
          versionKeys: heldItemVersionKeys,
          referencesFuture: _heldItemReferencesFuture,
        ),
      ]);
    }

    final evolutionChain = _filteredEvolutionChain(detail);
    if (evolutionChain != null) {
      sections.addAll([
        const SizedBox(height: 12),
        VersionChainPlanningCard(
          chain: evolutionChain,
          currentDetail: detail,
          versionGroup: editionKey,
          exactVersion: selectedVersion,
          onPickVersion: () async {
            final selected = await showDexEditionPicker(
              context,
              selected: _gameEdition,
              exactOnly: true,
            );
            if (mounted && selected != null) _selectEdition(selected);
          },
          detailsFuture: _chainDetailsFuture,
        ),
        const SizedBox(height: 12),
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppZh.dexEvolution, style: SecondaryTypography.onCard.h15),
              const SizedBox(height: 12),
              EvolutionChainVerticalView(
                root: evolutionChain,
                highlightId: detail.summary.id,
              ),
            ],
          ),
        ),
      ]);
    }

    return sections;
  }

  List<Widget> _generalObtainSections(PokemonDetail detail) {
    final chain = _filteredEvolutionChain(detail);
    return [
      if (chain != null)
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppZh.dexEvolution, style: SecondaryTypography.onCard.h15),
              const SizedBox(height: 12),
              EvolutionChainVerticalView(
                root: chain,
                highlightId: detail.summary.id,
              ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      for (final group in _allObtainGroups(detail)) ...[
        ObtainLocationsCard(
          locations: group.$2,
          gameLabel: gameEditionLabelForVersionGroup(group.$1),
        ),
        const SizedBox(height: 8),
      ],
      if (_allObtainGroups(detail).isEmpty)
        StickerCard(child: Text(AppZh.dexNoObtainData)),
    ];
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
    final moveSetKey = gameEditionMoveSetKey(_gameEdition);
    final (moveSetSourceKey, moveSet) = _gameEdition.isGeneral
        ? (
            null,
            PokemonMoveSet.combined(
              detail.moveSets.isEmpty
                  ? [detail.moveSet]
                  : detail.moveSets.values,
            ),
          )
        : detail.resolvedMoveSetForKey(moveSetKey);
    final moveSetBorrowed =
        moveSetSourceKey != null && moveSetSourceKey != moveSetKey;
    final availableMethods = _MoveMethodFilterBar._order
        .where((method) => _movesForMethod(method, moveSet).isNotEmpty)
        .toList();
    if (availableMethods.isEmpty) {
      // Same empty-state card the 获取 tab shows, so a species with no move
      // data for this edition never renders a blank panel.
      return [
        StickerCard(
          child: Text(
            AppZh.dexNoMoveData,
            style: SecondaryTypography.onCard.body14.copyWith(
              color: TitoColors.mutedInk,
            ),
          ),
        ),
      ];
    }

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
        availableMethods: availableMethods,
        onSelected: (filter) => setState(() => _moveMethodFilter = filter),
      ),
      if (_gameEdition.isGeneral &&
          effectiveFilter == _MoveMethodFilter.level) ...[
        const SizedBox(height: 8),
        Text(
          AppZh.dexMovesCrossVersionNote,
          style: SecondaryTypography.onPage(context).small12,
        ),
      ],
      if (moveSetBorrowed) ...[
        const SizedBox(height: 8),
        Text(
          AppZh.dexDataFallbackNote(
            gameEditionLabelForVersionGroup(moveSetSourceKey),
          ),
          style: SecondaryTypography.onPage(
            context,
          ).small12.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
      const SizedBox(height: 8),
      // Keyed move-method panel swap without a custom transition.
      TitoAnimatedSizeSwitcher(
        switchKey: ValueKey<int>(effectiveFilter.index),
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
          showLevel: !_gameEdition.isGeneral,
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
}

class _DetailSelectionMotion extends StatelessWidget {
  const _DetailSelectionMotion({
    required this.motionKey,
    required this.selected,
    required this.builder,
  });

  final Key motionKey;
  final bool selected;
  final Widget Function(BuildContext context, double selection) builder;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: selected ? 1 : 0),
      duration: TitoMotion.duration(context, TitoMotion.fast),
      curve: Curves.easeOutCubic,
      builder: (context, selection, _) {
        return Transform.translate(
          key: motionKey,
          offset: Offset(0, -1.5 * selection),
          child: Transform.scale(
            scale: 1 + 0.015 * selection,
            child: builder(context, selection),
          ),
        );
      },
    );
  }
}

class _MoveMethodFilterBar extends StatelessWidget {
  const _MoveMethodFilterBar({
    required this.selected,
    required this.onSelected,
    required this.availableMethods,
  });

  final _MoveMethodFilter selected;
  final ValueChanged<_MoveMethodFilter> onSelected;

  final List<_MoveMethodFilter> availableMethods;

  static const _order = [
    _MoveMethodFilter.level,
    _MoveMethodFilter.machine,
    _MoveMethodFilter.egg,
    _MoveMethodFilter.tutor,
  ];

  static Map<_MoveMethodFilter, String> get _labels => {
    _MoveMethodFilter.level: AppZh.dexMoveFilterLevel,
    _MoveMethodFilter.machine: AppZh.dexMoveFilterMachine,
    _MoveMethodFilter.egg: AppZh.dexMoveFilterEgg,
    _MoveMethodFilter.tutor: AppZh.dexMoveFilterTutor,
  };

  @override
  Widget build(BuildContext context) {
    final palette = _SelectionChipPalette.of(context);
    return Row(
      children: [
        for (final entry in availableMethods) ...[
          if (entry != availableMethods.first) const SizedBox(width: 6),
          Expanded(
            child: () {
              final isSelected = selected == entry;
              final radius = BorderRadius.circular(TitoRadii.sm);
              return _DetailSelectionMotion(
                motionKey: ValueKey('move-filter-motion-${entry.index}'),
                selected: isSelected,
                builder: (context, selection) => HandheldFocusDecorator(
                  onActivate: () => onSelected(entry),
                  child: StickerPressable(
                    borderRadius: radius,
                    child: Material(
                      color: Color.lerp(
                        palette.resting,
                        palette.selected,
                        selection,
                      ),
                      borderRadius: radius,
                      child: InkWell(
                        onTap: () => onSelected(entry),
                        borderRadius: radius,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            border: palette.border,
                          ),
                          child: Text(
                            _labels[entry]!,
                            textAlign: TextAlign.center,
                            style: SecondaryTypography.onCard.small12.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Color.lerp(
                                palette.restingText,
                                palette.selectedText,
                                selection,
                              ),
                            ),
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

/// Single-choice chip colours for the custom-drawn selection rows on this
/// page (move-method filter). These keep their hand-rolled motion, so they
/// cannot be Material chips, but they follow the same rules: soft-yellow
/// selection with an ink element stroke in Trainer's Journal, a milky plastic
/// hairline in Solid Plastic, and Material `secondaryContainer` with no ink
/// stroke in Flat UI.
class _SelectionChipPalette {
  const _SelectionChipPalette({
    required this.resting,
    required this.selected,
    required this.restingText,
    required this.selectedText,
    required this.border,
  });

  final Color resting;
  final Color selected;
  final Color restingText;
  final Color selectedText;
  final Border? border;

  factory _SelectionChipPalette.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (appVisualStyle.usesFlatUi) {
      return _SelectionChipPalette(
        resting: scheme.surfaceContainerLow,
        selected: scheme.secondaryContainer,
        restingText: scheme.onSurface,
        selectedText: scheme.onSecondaryContainer,
        border: null,
      );
    }
    if (appVisualStyle.usesSolidPlastic) {
      return _SelectionChipPalette(
        resting: TitoColors.card.withValues(alpha: 0.86),
        selected: TitoColors.softYellow.withValues(alpha: 0.92),
        restingText: TitoColors.ink,
        selectedText: TitoColors.ink,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: TitoBorders.glass,
        ),
      );
    }
    return _SelectionChipPalette(
      resting: TitoColors.card,
      selected: TitoColors.softYellow,
      restingText: TitoColors.ink,
      selectedText: TitoColors.ink,
      border: TrainerJournal.allElement(),
    );
  }
}

class _DetailArrival extends StatelessWidget {
  const _DetailArrival({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = TitoMotion.disabled(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: reduceMotion ? 1 : 0, end: 1),
      duration: TitoMotion.duration(context, TitoMotion.standard),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) {
        return Opacity(
          key: const ValueKey('pokemon-detail-content-arrival'),
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 6 * (1 - progress)),
            child: child,
          ),
        );
      },
      child: child,
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
              FilledButton(onPressed: onRetry, child: Text(AppZh.dexRetry)),
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
    required this.selectedColor,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final Color selectedColor;

  static List<String> get _labels => [
    AppZh.dexTabIntro,
    AppZh.dexTabBasic,
    AppZh.dexTabObtain,
    AppZh.dexTabMoves,
  ];

  /// Bottom inset the detail list keeps free so its last card clears this bar
  /// (bar padding + tab height + a breathing gap). Single source for the page.
  static const double listBottomClearance = 72;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Type tint on the selected tab is intentional; only the stroke follows
    // the theme (ink in Trainer's Journal, plastic hairline, none in Flat).
    final selectedText = selectedColor.computeLuminance() > .45
        ? TitoColors.ink
        : TitoColors.card;
    final Border? tabBorder = appVisualStyle.usesFlatUi
        ? null
        : appVisualStyle.usesSolidPlastic
        ? Border.all(
            color: Colors.white.withValues(alpha: 0.8),
            width: TitoBorders.glass,
          )
        : TrainerJournal.allElement();
    return Container(
      key: const ValueKey('detail-bottom-tabs'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(color: scheme.outline.withValues(alpha: .3)),
        ),
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
                child: _DetailSelectionMotion(
                  motionKey: ValueKey('detail-tab-motion-$index'),
                  selected: selected,
                  builder: (context, selection) => HandheldFocusDecorator(
                    onActivate: () => onSelected(index),
                    child: StickerPressable(
                      borderRadius: radius,
                      child: Material(
                        key: ValueKey('detail-tab-surface-$index'),
                        color: Color.lerp(
                          scheme.surface,
                          selectedColor,
                          selection,
                        ),
                        borderRadius: radius,
                        child: InkWell(
                          borderRadius: radius,
                          onTap: () => onSelected(index),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: radius,
                              border: tabBorder,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Text(
                              _labels[index],
                              textAlign: TextAlign.center,
                              style: SecondaryTypography.onCard.small12
                                  .copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Color.lerp(
                                      scheme.onSurfaceVariant,
                                      selectedText,
                                      selection,
                                    ),
                                  ),
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
