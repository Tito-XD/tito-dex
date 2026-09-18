import '../../features/companion/battle_party_damage.dart';
import '../../features/companion/battle_move_rules.dart';
import '../../features/companion/battle_learnset.dart';
import '../../widgets/battle_move_picker.dart';
import '../../l10n/app_locale.dart';
import '../../widgets/battle_team_editor.dart';
import '../../widgets/battle_party_results.dart';
import 'package:flutter/material.dart';

import '../../features/companion/battle_game_scope.dart';
import '../../features/companion/battle_session.dart';
import '../../widgets/battle_party_picker.dart';
import '../../features/companion/battle_handoff.dart';
import '../../features/companion/battle_math.dart';
import '../../features/companion/battle_tools_service.dart';
import '../../features/dex/battle_effectiveness.dart';
import '../../features/dex/dex_models.dart';
import '../../features/dex/dex_repository.dart';
import '../../features/dex/type_chart.dart';
import '../../features/game/game_edition_repository.dart';
import '../../l10n/app_zh.dart';
import '../../models/journey.dart';
import '../../theme/app_visual_style.dart';
import '../../theme/error_text.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import '../../theme/trainer_journal.dart';
import '../../widgets/companion_tool_fields.dart';
import '../../widgets/battle_tool_panels.dart';
import '../../widgets/secondary_page_scaffold.dart';
import '../../widgets/sticker_card.dart';
import '../../widgets/tito_loading_panel.dart';

class QuickDamagePage extends StatefulWidget {
  const QuickDamagePage({
    super.key,
    required this.journey,
    this.embedded = false,
    this.session,
  });

  final CurrentJourney journey;
  final bool embedded;
  final BattleSession? session;

  @override
  State<QuickDamagePage> createState() => _QuickDamagePageState();
}

class _QuickDamagePageState extends State<QuickDamagePage> {
  late final BattleSession _session =
      widget.session ??
      BattleSession(
        level: battleScopeForEdition(
          gameEditionRepository.edition,
        ).defaultLevel,
      );
  void _edit(VoidCallback change) {
    setState(change);
    _session.changed();
  }

  CachedMove? _selectedMove;
  int? _movePokemonId;
  String? _moveVersion;
  bool _isCriticalHit = false;
  bool _defenderScreened = false;
  bool _isSpreadMove = false;
  FieldCondition _weather = FieldCondition.none;
  TerrainCondition _terrain = TerrainCondition.none;
  BattleMoveProfile? get _profile => battleMoveProfile(
    _selectedMove,
    battleScopeForEdition(gameEditionRepository.edition).generation,
    attacker: _session.attacker,
    weather: _weather.slug,
  );
  MoveCategory get _damageCategory => _profile == null
      ? _session.category
      : _profile!.physical
      ? MoveCategory.physical
      : MoveCategory.special;
  BattleStat get _attackStat => battleOffensiveStat(
    _selectedMove,
    _damageCategory == MoveCategory.physical,
  );
  BattleStat get _defenseStat => battleDefensiveStat(
    _selectedMove,
    _damageCategory == MoveCategory.physical,
  );
  TextEditingController get _attackController =>
      (_selectedMove?.id == 492 ? _session.defender : _session.attacker)
          .raw[_attackStat]!;
  TextEditingController get _defenseController =>
      _session.defender.raw[_defenseStat]!;
  Map<String, TypeDamageRelations>? _relations;
  String? _error;
  bool _loading = true;
  List<PokemonSummary> _attackerSuggestions = const [];
  List<PokemonSummary> _defenderSuggestions = const [];

  @override
  void initState() {
    super.initState();
    _relations = battleToolsService.cachedTypeRelations;
    _loading = _relations == null;
    if (_loading) _loadRelations();
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePartyHandoff());
  }

  @override
  void dispose() {
    if (widget.session == null) _session.dispose();
    super.dispose();
  }

  Future<void> _loadRelations() async {
    try {
      final relations = await battleToolsService.loadTypeRelations();
      if (!mounted) {
        return;
      }
      _edit(() {
        _relations = relations;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _edit(() {
        _error = formatUserFacingError(error);
        _loading = false;
      });
    }
  }

  void _retryLoadRelations() {
    _edit(() {
      _loading = true;
      _error = null;
    });
    _relations = battleToolsService.cachedTypeRelations;
    _loading = _relations == null;
    if (_loading) _loadRelations();
  }

  Future<void> _consumePartyHandoff() async {
    if (battlePartyHandoff.isEmpty) return;
    final member = battlePartyHandoff.member!;
    final moveId = battlePartyHandoff.moveId;
    battlePartyHandoff.clear();
    await _applyPartyMember(member, preferredMoveId: moveId);
  }

  Future<void> _applyPartyMember(
    PartyMember member, {
    int? preferredMoveId,
  }) async {
    final speciesId = member.speciesId;
    if (speciesId == null) return;
    final summary = await dexRepository.getSummary(speciesId);
    if (!mounted) return;
    await _session.attacker.selectPokemon(summary, member: member);
    if (!mounted) return;
    final legal = battleLearnset(
      _session.attacker.detail,
      gameEditionRepository.edition.dataVersionGroupKey,
    );
    final moveId = preferredMoveId ?? member.moveIds.firstOrNull;
    final move = legal.where((m) => m.id == moveId).firstOrNull;
    if (move != null) _chooseMove(move);
  }

  void _chooseMove(CachedMove? move) => _edit(() {
    _selectedMove = move;
    _movePokemonId = _session.attacker.pokemonId;
    _moveVersion = gameEditionRepository.edition.dataVersionGroupKey;
    _session.category = move?.category == 'special'
        ? MoveCategory.special
        : MoveCategory.physical;
  });

  Future<void> _searchAttacker(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _edit(() => _attackerSuggestions = const []);
      return;
    }
    final results = await dexRepository.search(trimmed);
    if (!mounted || _session.attacker.query.text.trim() != trimmed) {
      return;
    }
    _edit(() => _attackerSuggestions = results.take(6).toList());
  }

  Future<void> _searchDefender(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _edit(() => _defenderSuggestions = const []);
      return;
    }
    final results = await dexRepository.search(trimmed);
    if (!mounted || _session.defender.query.text.trim() != trimmed) {
      return;
    }
    _edit(() => _defenderSuggestions = results.take(6).toList());
  }

  Future<void> _applyAttacker(PokemonSummary summary) async {
    _edit(() => _attackerSuggestions = const []);
    await _session.attacker.selectPokemon(summary);
  }

  Future<void> _applyDefender(PokemonSummary summary) async {
    _edit(() => _defenderSuggestions = const []);
    await _session.defender.selectPokemon(summary);
  }

  void _clearLinkedAttacker() => _edit(_session.attacker.clearIdentity);
  void _clearLinkedDefender() => _edit(_session.defender.clearIdentity);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([gameEditionRepository, _session]),
      builder: (context, _) {
        final edition = gameEditionRepository.edition;
        final scope = battleScopeForEdition(edition);
        final relations = _relations;
        final selectedMove =
            _movePokemonId == _session.attacker.pokemonId &&
                _moveVersion == edition.dataVersionGroupKey
            ? battleLearnset(
                _session.attacker.detail,
                edition.dataVersionGroupKey,
              ).where((m) => m.id == _selectedMove?.id).firstOrNull
            : null;
        final estimate = relations == null
            ? null
            : estimatePartyMove(
                attacker: _session.attacker,
                defender: _session.defender,
                move: selectedMove,
                relations: relations,
                generation: scope.generation,
                weatherSlug: _weather.slug,
                terrainSlug: _terrain.slug,
                critical: _isCriticalHit,
                screened: _defenderScreened,
                spread: _isSpreadMove,
              );
        final profile = battleMoveProfile(
          selectedMove,
          scope.generation,
          attacker: _session.attacker,
          weather: _weather.slug,
        );

        // The full estimate leads one continuous page; a small live summary
        // takes over only after it scrolls out of view.
        return CompanionToolScaffold(
          transitionKey: _session.teamMode,
          embedded: widget.embedded,
          title: AppZh.companionToolQuickDamage,
          subtitle: edition.label,
          resultSummary: _session.teamMode && relations != null
              ? BattlePartyResults(
                  session: _session,
                  party: widget.journey.party,
                  compact: true,
                  relations: relations,
                  generation: scope.generation,
                  weatherSlug: _weather.slug,
                  terrainSlug: _terrain.slug,
                  critical: _isCriticalHit,
                  screened: _defenderScreened,
                  spread: _isSpreadMove,
                )
              : Text(
                  estimate == null
                      ? AppZh.companionDamageResultTitle
                      : '${estimate.minDamage}–${estimate.maxDamage} HP · ${estimate.minPercent.toStringAsFixed(1)}–${estimate.maxPercent.toStringAsFixed(1)}%',
                ),
          result: _session.teamMode && relations != null
              ? BattlePartyResults(
                  session: _session,
                  party: widget.journey.party,
                  relations: relations,
                  generation: scope.generation,
                  weatherSlug: _weather.slug,
                  terrainSlug: _terrain.slug,
                  critical: _isCriticalHit,
                  screened: _defenderScreened,
                  spread: _isSpreadMove,
                )
              : estimate != null
              ? _DamageResultCard(estimate: estimate, compact: true)
              : StickerCard(
                  child: Text(
                    selectedMove == null
                        ? AppLocale.pick(
                            zh: '选择进攻方和它在当前游戏可学的招式，即可计算伤害。',
                            en: 'Choose an attacker and a move it can learn in this game.',
                          )
                        : battleMoveIssue(
                                _session.attacker,
                                _session.defender,
                                selectedMove,
                                scope.generation,
                              ) ??
                              AppZh.battleTeamMoveUnsupported,
                    style: SecondaryTypography.onCard.body14,
                  ),
                ),
          scopeSelector: BattleSegmentedControl<bool>(
            key: const ValueKey('battle-scope'),
            value: _session.teamMode,
            options: {
              false: AppZh.battleDuelAnalysis,
              true: AppZh.battleTeamAnalysis,
            },
            onChanged: (value) => _edit(() => _session.teamMode = value),
          ),
          children: [
            if (_loading)
              TitoLoadingPanel(message: AppZh.companionLoading, compact: true)
            else if (_error != null)
              StickerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _error!,
                      style: SecondaryTypography.onCard.small12.copyWith(
                        color: TitoColors.mutedInk,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _retryLoadRelations,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(AppZh.dexRetry),
                    ),
                  ],
                ),
              )
            else ...[
              BattleCombatants(
                showAttacker: !_session.teamMode,
                attacker: CompanionSectionCard(
                  padding: const EdgeInsets.all(10),
                  title: AppZh.battleAttacker,
                  children: [
                    BattlePartyPicker(
                      journey: widget.journey,
                      combatant: _session.attacker,
                    ),
                    PokemonSearchField(
                      compact: true,
                      controller: _session.attacker.query,
                      hintText: AppZh.companionAttackerSearchHint,
                      suggestions: _attackerSuggestions,
                      onQueryChanged: _searchAttacker,
                      onPokemonSelected: _applyAttacker,
                      prefixIcon: Icons.sports_martial_arts_rounded,
                    ),
                    const SizedBox(height: 8),
                    BattleDraftNotice(combatant: _session.attacker),
                    LinkedOrManualTypePicker(
                      linkedPokemonId: _session.attacker.pokemonId,
                      label: AppZh.battleTypes,
                      selected: _session.attacker.types,
                      onManualChanged: (types) {
                        _edit(() => _session.attacker.types = types);
                        _clearLinkedAttacker();
                      },
                    ),
                    const SizedBox(height: 8),
                    CompanionNumberField(
                      inline: true,
                      label: AppZh.companionStatLevel,
                      controller: _session.attacker.level,
                      max: 100,
                      onChanged: (_) => _edit(() {}),
                    ),
                    const SizedBox(height: 8),
                    CompanionNumberField(
                      inline: true,
                      label: _attackStat.label,
                      controller: _attackController,
                      max: 999,
                      onChanged: (_) => _edit(() {}),
                    ),
                    const SizedBox(height: 8),
                    CompanionAbilitySection(
                      compact: true,
                      pokemonLabel: AppZh.battleAbility,
                      manualLabel: AppZh.battleAbility,
                      manualOptions: {
                        ...kManualDefensiveAbilityOptions,
                        ...kManualAttackerAbilityOptions,
                      },
                      pokemonOptions: defensiveAbilityOptionsFrom(
                        _session.attacker.abilities,
                      ),
                      linkedPokemonId: _session.attacker.pokemonId,
                      selectedSlug: _session.attacker.abilitySlug,
                      onChanged: (slug) =>
                          _edit(() => _session.attacker.abilitySlug = slug),
                    ),
                    const SizedBox(height: 8),
                    BattleMoreOptions(
                      storageId: 'attacker',
                      children: [
                        HeldItemPicker(
                          compact: true,
                          selected: _session.attacker.heldItem,
                          onChanged: (value) => _edit(() {
                            _session.attacker.heldItem = value;
                            _session.attacker.unsupportedItem = false;
                          }),
                          typeBoostItemType:
                              _session.attacker.typeBoostItemType,
                          onTypeBoostChanged: (type) => _edit(
                            () => _session.attacker.typeBoostItemType = type,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StatusConditionPicker(
                          compact: true,
                          selected: _session.attacker.status,
                          onChanged: (value) =>
                              _edit(() => _session.attacker.status = value),
                        ),
                        const SizedBox(height: 8),
                        if (scope.generation >= 9)
                          TerastalPicker(
                            label: AppZh.battleTerastal,
                            enabled: true,
                            terastallized: _session.attacker.terastallized,
                            teraType: _session.attacker.teraType,
                            fallbackTypes: _session.attacker.types,
                            generation: scope.generation,
                            onTerastallizedChanged: (value) => _edit(
                              () => _session.attacker.terastallized = value,
                            ),
                            onTeraTypeChanged: (type) =>
                                _edit(() => _session.attacker.teraType = type),
                          ),
                      ],
                    ),
                  ],
                ),
                defender: CompanionSectionCard(
                  padding: const EdgeInsets.all(10),
                  title: AppZh.companionTypeDefenderTitle,
                  children: [
                    BattlePartyPicker(
                      journey: widget.journey,
                      combatant: _session.defender,
                    ),
                    PokemonSearchField(
                      compact: true,
                      controller: _session.defender.query,
                      hintText: AppZh.companionDefenderSearchHint,
                      suggestions: _defenderSuggestions,
                      onQueryChanged: _searchDefender,
                      onPokemonSelected: _applyDefender,
                      prefixIcon: Icons.shield_rounded,
                    ),
                    const SizedBox(height: 8),
                    BattleDraftNotice(combatant: _session.defender),
                    LinkedOrManualTypePicker(
                      linkedPokemonId: _session.defender.pokemonId,
                      label: AppZh.battleTypes,
                      selected: _session.defender.types,
                      onManualChanged: (types) {
                        if (types.isNotEmpty) {
                          _edit(() {
                            _session.defender.types = types;
                            _session.defender.teraType = defaultTeraTypeFor(
                              types,
                              scope.generation,
                            );
                          });
                          _clearLinkedDefender();
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    CompanionNumberField(
                      inline: true,
                      label: AppZh.companionDefenderHp,
                      controller: _session.defender.raw[BattleStat.hp]!,
                      max: 999,
                      onChanged: (_) => _edit(() {}),
                    ),
                    const SizedBox(height: 8),
                    CompanionNumberField(
                      inline: true,
                      label:
                          _session.teamMode ||
                              _defenseStat == BattleStat.defense
                          ? AppZh.companionDefenseStat
                          : AppZh.companionSpDefenseStat,
                      controller: _session.teamMode
                          ? _session.defender.raw[BattleStat.defense]!
                          : _defenseController,
                      max: 999,
                      onChanged: (_) => _edit(() {}),
                    ),
                    const SizedBox(height: 8),
                    if (_session.teamMode) ...[
                      CompanionNumberField(
                        inline: true,
                        label: AppZh.companionSpDefenseStat,
                        controller:
                            _session.defender.raw[BattleStat.specialDefense]!,
                        max: 999,
                        onChanged: (_) => _edit(() {}),
                      ),
                      const SizedBox(height: 8),
                    ],
                    CompanionAbilitySection(
                      compact: true,
                      pokemonLabel: AppZh.battleAbility,
                      manualLabel: AppZh.battleAbility,
                      manualOptions: {
                        ...kManualDefensiveAbilityOptions,
                        ...kManualAttackerAbilityOptions,
                      },
                      pokemonOptions: defensiveAbilityOptionsFrom(
                        _session.defender.abilities,
                      ),
                      linkedPokemonId: _session.defender.pokemonId,
                      selectedSlug: _session.defender.abilitySlug,
                      onChanged: (slug) =>
                          _edit(() => _session.defender.abilitySlug = slug),
                    ),
                    const SizedBox(height: 8),
                    BattleMoreOptions(
                      storageId: 'defender',
                      children: [
                        HeldItemPicker(
                          compact: true,
                          selected: _session.defender.heldItem,
                          onChanged: (value) => _edit(() {
                            _session.defender.heldItem = value;
                            _session.defender.unsupportedItem = false;
                          }),
                          typeBoostItemType:
                              _session.defender.typeBoostItemType,
                          onTypeBoostChanged: (type) => _edit(
                            () => _session.defender.typeBoostItemType = type,
                          ),
                        ),
                        const SizedBox(height: 8),
                        BattleToggleChip(
                          label: AppZh.companionDefenderScreen,
                          value: _defenderScreened,
                          onChanged: (value) =>
                              _edit(() => _defenderScreened = value),
                        ),
                        const SizedBox(height: 8),
                        if (scope.generation >= 9)
                          TerastalPicker(
                            label: AppZh.battleTerastal,
                            enabled: true,
                            terastallized: _session.defender.terastallized,
                            teraType: _session.defender.teraType,
                            fallbackTypes: _session.defender.types,
                            generation: scope.generation,
                            onTerastallizedChanged: (value) => _edit(
                              () => _session.defender.terastallized = value,
                            ),
                            onTeraTypeChanged: (type) =>
                                _edit(() => _session.defender.teraType = type),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_session.teamMode)
                BattleTeamEditor(session: _session, party: widget.journey.party)
              else
                CompanionSectionCard(
                  padding: const EdgeInsets.all(10),
                  title: AppZh.battleMoveInputs,
                  children: [
                    BattleMovePicker(
                      detail: _session.attacker.detail,
                      versionGroup: edition.dataVersionGroupKey,
                      value: selectedMove,
                      onChanged: _chooseMove,
                    ),
                    if (selectedMove != null)
                      Text(
                        '${typeNameZh(profile?.type ?? selectedMove.type)} · ${profile?.physical == false
                            ? AppZh.companionSpAttackStat
                            : profile?.physical == true
                            ? AppZh.companionAttackStat
                            : AppLocale.pick(zh: '变化', en: 'Status')} · ${AppZh.companionMovePower} ${profile?.power ?? '—'}',
                        style: SecondaryTypography.onCard.small12,
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              StickerCard(
                child: BattleMoreOptions(
                  title: AppZh.battleFieldOptions,
                  storageId: 'field',
                  children: [
                    FieldConditionPicker(
                      label: AppZh.companionWeatherPick,
                      selected: _weather,
                      onChanged: (value) => _edit(() => _weather = value),
                    ),
                    const SizedBox(height: 8),
                    TerrainConditionPicker(
                      label: AppZh.companionTerrainPick,
                      selected: _terrain,
                      onChanged: (value) => _edit(() => _terrain = value),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        BattleToggleChip(
                          label: AppZh.companionCriticalHit,
                          value: _isCriticalHit,
                          onChanged: (value) =>
                              _edit(() => _isCriticalHit = value),
                        ),
                        if (!_session.teamMode)
                          BattleToggleChip(
                            label: AppZh.companionSpreadMove,
                            value: _isSpreadMove,
                            onChanged: (value) =>
                                _edit(() => _isSpreadMove = value),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      scope.damageNote,
                      style: SecondaryTypography.onCard.small12,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppZh.companionDamageFacility(scope.facilityLabel),
                      style: SecondaryTypography.onCard.small12,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppZh.companionDamageAssumptions,
                      style: SecondaryTypography.onCard.small12,
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Result card (battle template): the single accent focus of the page —
/// deep-blue card, oversized soft-yellow percentage, and an HP bar split
/// into mint-safe / coral-damage segments. [compact] drops the extra verdict
/// and assumptions so the result stays glanceable before the input form.
class _DamageResultCard extends StatelessWidget {
  const _DamageResultCard({required this.estimate, this.compact = false});

  final DamageEstimate estimate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final minPct = estimate.minPercent;
    final maxPct = estimate.maxPercent;
    final bigPercent = (maxPct - minPct) < 0.5
        ? '${maxPct.round()}%'
        : '${minPct.round()}–${maxPct.round()}%';
    final damageFraction = (maxPct / 100).clamp(0.0, 1.0);

    return StickerCard(
      variant: StickerVariant.deep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.companionDamageResultTitle,
            style: SecondaryTypography.onGradient.small12.copyWith(
              fontWeight: FontWeight.w800,
              color: TitoColors.skyBlue,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                bigPercent,
                style: SecondaryTypography.onGradient.h15.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 34 * -0.03,
                  color: TitoColors.softYellow,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${estimate.minDamage} – ${estimate.maxDamage} · '
                  '${estimate.verdictZh}',
                  style: SecondaryTypography.onGradient.small12.copyWith(
                    fontWeight: FontWeight.w800,
                    color: TitoColors.skyBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              // HP bar rail: a translucent white wash over the deep card so
              // the mint/coral split reads on every theme; ink outline only
              // where the theme draws ink.
              return Container(
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: appVisualStyle.usesFlatUi
                      ? null
                      : Border.all(
                          color: appVisualStyle.usesTrainerJournal
                              ? TrainerJournal.smallEdge
                              : TitoColors.ink,
                          width: appVisualStyle.usesTrainerJournal
                              ? TitoBorders.journalHairline
                              : TitoBorders.element,
                        ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: width * (1 - damageFraction),
                      child: const ColoredBox(color: TitoColors.mint),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: width * damageFraction,
                      child: const ColoredBox(color: TitoColors.coral),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          if (!compact) ...[
            Text(
              '${AppZh.companionDamageDefense}：${estimate.tankVerdictZh}',
              style: SecondaryTypography.onGradient.body14,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            AppZh.companionDamageModifiers(
              formatTypeMultiplier(estimate.typeMultiplier),
              estimate.stabMultiplier == 1.0
                  ? '1'
                  : estimate.stabMultiplier.toStringAsFixed(1),
            ),
            style: SecondaryTypography.onGradient.small12.copyWith(
              color: TitoColors.skyBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (estimate.extraMultiplier != 1) ...[
            const SizedBox(height: 4),
            Text(
              AppZh.companionDamageExtra(
                estimate.extraMultiplier.toStringAsFixed(2),
              ),
              style: SecondaryTypography.onGradient.small12.copyWith(
                color: TitoColors.skyBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (!compact) ...[
            const SizedBox(height: 8),
            Text(
              AppZh.companionDamageAssumptions,
              style: SecondaryTypography.onGradient.small12.copyWith(
                color: TitoColors.skyBlue,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
