import '../../widgets/battle_team_editor.dart';
import '../../widgets/battle_party_results.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../../features/companion/battle_game_scope.dart';
import '../../features/companion/battle_session.dart';
import '../../widgets/battle_party_picker.dart';
import '../../features/companion/battle_math.dart';
import '../../features/dex/battle_effectiveness.dart';
import '../../features/dex/dex_models.dart';
import '../../features/dex/dex_repository.dart';
import '../../features/game/game_edition_repository.dart';
import '../../l10n/app_zh.dart';
import '../../models/journey.dart';
import '../../theme/secondary_typography.dart';
import '../../widgets/companion_tool_fields.dart';
import '../../widgets/battle_tool_panels.dart';
import '../../widgets/secondary_page_scaffold.dart';
import '../../widgets/sticker_card.dart';

class StatCalcPage extends StatefulWidget {
  const StatCalcPage({
    super.key,
    required this.journey,
    this.embedded = false,
    this.session,
    this.onHandoffToDamage,
  });

  final CurrentJourney journey;
  final bool embedded;
  final BattleSession? session;
  final VoidCallback? onHandoffToDamage;

  @override
  State<StatCalcPage> createState() => _StatCalcPageState();
}

class _StatCalcPageState extends State<StatCalcPage> {
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

  bool _editingDefender = false;
  BattleCombatant get _combatant =>
      _editingDefender ? _session.defender : _session.attacker;
  BattleStat _stat = BattleStat.attack;
  List<PokemonSummary> _suggestions = const [];

  @override
  void dispose() {
    if (widget.session == null) _session.dispose();
    super.dispose();
  }

  Future<void> _searchPokemon(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _edit(() => _suggestions = const []);
      return;
    }
    final combatant = _combatant;
    final results = await dexRepository.search(trimmed);
    if (!mounted ||
        combatant != _combatant ||
        _combatant.query.text.trim() != trimmed) {
      return;
    }
    _edit(() => _suggestions = results.take(6).toList());
  }

  Future<void> _applyPokemon(PokemonSummary summary) async {
    final combatant = _combatant;
    _edit(() => _suggestions = const []);
    await combatant.selectPokemon(summary);
  }

  String get _applyToDamageLabel => AppZh.battleViewDamage;

  void _applyToDamage(int result) {
    if (_stat == BattleStat.specialAttack ||
        _stat == BattleStat.specialDefense) {
      _session.category = MoveCategory.special;
    } else if (_stat == BattleStat.attack || _stat == BattleStat.defense) {
      _session.category = MoveCategory.physical;
    }
    _session.changed();
    final onHandoff = widget.onHandoffToDamage;
    if (onHandoff != null) {
      onHandoff();
    } else {
      context.push('/search/companion/quick-damage');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([gameEditionRepository, _session]),
      builder: (context, _) {
        final edition = gameEditionRepository.edition;
        final scope = battleScopeForEdition(edition);
        final result = _combatant.effectiveStat(
          _stat,
          generation: scope.generation,
        );

        return CompanionToolScaffold(
          transitionKey: _session.teamMode,
          embedded: widget.embedded,
          title: AppZh.companionToolStatCalc,
          subtitle: edition.label,
          resultSummary: Text(
            _session.teamMode
                ? '${AppZh.battleTeamStats} · ${_session.teamCount(widget.journey.party)}'
                : '${_stat.label} · $result',
          ),
          result: _session.teamMode
              ? BattlePartyResults(
                  session: _session,
                  party: widget.journey.party,
                  generation: scope.generation,
                )
              : StickerCard(
                  variant: StickerVariant.deep,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        AppZh.companionStatResultTitle,
                        style: SecondaryTypography.onGradient.small12,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$result',
                                  key: const ValueKey('battle-stat-value'),
                                  style: SecondaryTypography.onGradient.h15
                                      .copyWith(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                Text(
                                  _stat.label,
                                  style: SecondaryTypography.onGradient.body14,
                                ),
                              ],
                            ),
                          ),
                          if (_stat != BattleStat.speed)
                            Flexible(
                              child: FilledButton.tonal(
                                onPressed: () => _applyToDamage(result),
                                child: Text(
                                  _applyToDamageLabel,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppZh.companionStatResultHint,
                        style: SecondaryTypography.onGradient.small12,
                      ),
                    ],
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
            if (_session.teamMode)
              BattleTeamEditor(session: _session, party: widget.journey.party)
            else
              CompanionSectionCard(
                padding: const EdgeInsets.all(10),
                title: AppZh.companionStatInputsTitle,
                children: [
                  CompanionSelectField<bool>(
                    value: _editingDefender,
                    options: {
                      false: AppZh.battleAttacker,
                      true: AppZh.companionTypeDefenderTitle,
                    },
                    onChanged: (value) => _edit(() {
                      _editingDefender = value;
                      _suggestions = const [];
                    }),
                  ),
                  BattlePartyPicker(
                    journey: widget.journey,
                    combatant: _combatant,
                  ),
                  PokemonSearchField(
                    compact: true,
                    controller: _combatant.query,
                    hintText: AppZh.companionPokemonSearchHint,
                    suggestions: _suggestions,
                    onQueryChanged: _searchPokemon,
                    onPokemonSelected: _applyPokemon,
                  ),
                  const SizedBox(height: 8),
                  BattleDraftNotice(combatant: _combatant),
                  StatPicker(
                    selected: _stat,
                    onChanged: (value) {
                      _edit(() => _stat = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CompanionNumberField(
                          label: AppZh.companionStatBase,
                          controller: _combatant.base[_stat]!,
                          max: 255,
                          onChanged: (_) {
                            _edit(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CompanionNumberField(
                          label: AppZh.companionStatLevel,
                          controller: _combatant.level,
                          max: 100,
                          onChanged: (_) => _edit(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CompanionNumberField(
                          label: AppZh.companionStatIv,
                          controller: _combatant.iv[_stat]!,
                          max: 31,
                          onChanged: (_) => _edit(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CompanionNumberField(
                          label: AppZh.companionStatEv,
                          controller: _combatant.ev[_stat]!,
                          max: 252,
                          onChanged: (_) => _edit(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  NaturePicker(
                    selected: _combatant.nature,
                    onChanged: (value) =>
                        _edit(() => _combatant.nature = value),
                  ),
                  const SizedBox(height: 8),
                  BattleMoreOptions(
                    children: [
                      CompanionAbilitySection(
                        compact: true,
                        pokemonLabel: AppZh.battleAbility,
                        manualLabel: AppZh.battleAbility,
                        manualOptions: {
                          ...kManualDefensiveAbilityOptions,
                          ...kManualAttackerAbilityOptions,
                        },
                        pokemonOptions: defensiveAbilityOptionsFrom(
                          _combatant.abilities,
                        ),
                        linkedPokemonId: _combatant.pokemonId,
                        selectedSlug: _combatant.abilitySlug,
                        onChanged: (slug) =>
                            _edit(() => _combatant.abilitySlug = slug),
                      ),
                      const SizedBox(height: 8),
                      HeldItemPicker(
                        compact: true,
                        selected: _combatant.heldItem,
                        onChanged: (value) =>
                            _edit(() => _combatant.heldItem = value),
                      ),
                      const SizedBox(height: 8),
                      StatusConditionPicker(
                        compact: true,
                        selected: _combatant.status,
                        onChanged: (value) =>
                            _edit(() => _combatant.status = value),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppZh.companionStatFacilityNote(scope.facilityLabel),
                        style: SecondaryTypography.onCard.small12,
                      ),
                    ],
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
