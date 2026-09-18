import '../../widgets/battle_team_editor.dart';
import 'package:flutter/material.dart';

import '../../features/companion/battle_game_scope.dart';
import '../../features/companion/battle_session.dart';
import '../../widgets/battle_party_picker.dart';
import '../../widgets/battle_team_panel.dart';
import '../../features/companion/battle_tools_service.dart';
import '../../features/dex/battle_effectiveness.dart';
import '../../features/dex/dex_models.dart';
import '../../features/dex/dex_repository.dart';
import '../../features/dex/generation_type_chart.dart';
import '../../features/dex/type_chart.dart';
import '../../features/game/game_edition_repository.dart';
import '../../l10n/app_zh.dart';
import '../../models/journey.dart';
import '../../theme/error_text.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import '../../widgets/companion_tool_fields.dart';
import '../../widgets/battle_tool_panels.dart';
import '../../widgets/secondary_page_scaffold.dart';
import '../../widgets/sticker_card.dart';
import '../../widgets/tito_loading_panel.dart';

class TypeMatchupPage extends StatefulWidget {
  const TypeMatchupPage({
    super.key,
    required this.journey,
    this.embedded = false,
    this.session,
  });

  final CurrentJourney journey;
  final bool embedded;
  final BattleSession? session;

  @override
  State<TypeMatchupPage> createState() => _TypeMatchupPageState();
}

class _TypeMatchupPageState extends State<TypeMatchupPage> {
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

  Map<String, TypeDamageRelations>? _relations;
  String? _error;
  bool _loading = true;
  List<PokemonSummary> _defenderSuggestions = const [];
  List<PokemonSummary> _attackerSuggestions = const [];

  @override
  void initState() {
    super.initState();
    _relations = battleToolsService.cachedTypeRelations;
    _loading = _relations == null;
    if (_loading) _loadRelations();
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

  BattleEffectivenessInput _defenderInput(
    Map<String, TypeDamageRelations> relations,
    int generation,
  ) {
    return BattleEffectivenessInput(
      defenderTypes: _session.defender.types,
      relationsByType: relations,
      defenderAbilitySlug: _session.defender.abilitySlug,
      attackerAbilitySlug: _session.attacker.abilitySlug,
      generation: generation,
      defenderTerastallized: _session.defender.terastallized,
      defenderTeraType: _session.defender.teraType,
      attackerTerastallized: _session.attacker.terastallized,
      attackerTeraType: _session.attacker.teraType,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([gameEditionRepository, _session]),
      builder: (context, _) {
        final edition = gameEditionRepository.edition;
        final scope = battleScopeForEdition(edition);
        final relations = _relations;
        final generation = scope.generation;

        return CompanionToolScaffold(
          transitionKey: _session.teamMode,
          embedded: widget.embedded,
          title: AppZh.companionToolTypeMatchup,
          subtitle: edition.label,
          resultSummary: Text(
            _session.teamMode
                ? AppZh.battleTeamSummary(
                    _session.teamCount(widget.journey.party),
                  )
                : relations == null
                ? AppZh.battleMatchupSummary
                : battleMatchupCompactLabel(
                    computeBattleTypeMultipliers(
                      _defenderInput(relations, generation),
                    ),
                  ),
          ),
          result: _session.teamMode && relations != null
              ? BattleTeamPanel(
                  session: _session,
                  party: widget.journey.party,
                  relations: relations,
                  generation: generation,
                )
              : relations != null && !_loading && _error == null
              ? BattleMatchupSummary(
                  multipliers: computeBattleTypeMultipliers(
                    _defenderInput(relations, generation),
                  ),
                  note: [
                    if (generation < 6)
                      AppZh.generationCorrection(
                        normalizeTypesForGeneration(
                          _session.defender.types,
                          generation,
                        ).map(typeNameZh).join('/'),
                      ),
                    if (_session.attacker.types.isNotEmpty)
                      profileLine(
                        AppZh.companionOffensiveBlindSpots,
                        computeOffensiveBlindSpots(
                          _session.attacker.types,
                          relations,
                          generation: generation,
                          attackerAbilitySlug: _session.attacker.abilitySlug,
                          attackerTerastallized:
                              _session.attacker.terastallized,
                          attackerTeraType: _session.attacker.teraType,
                        ),
                      ),
                  ].where((line) => line.isNotEmpty).join('\n'),
                )
              : null,
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
            if (_session.teamMode) ...[
              Text(
                AppZh.battleTeamScope,
                style: SecondaryTypography.onPage(context).small12,
              ),
              const SizedBox(height: 8),
              BattleTeamEditor(session: _session, party: widget.journey.party),
            ],
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
            else if (relations != null) ...[
              if (!_session.teamMode)
                BattleCombatants(
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
                        maxSelected: 2,
                        onManualChanged: (types) {
                          _edit(() => _session.attacker.types = types);
                          _clearLinkedAttacker();
                        },
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
                      if (generation >= 9) ...[
                        const SizedBox(height: 8),
                        TerastalPicker(
                          label: AppZh.battleTerastal,
                          enabled: true,
                          terastallized: _session.attacker.terastallized,
                          teraType: _session.attacker.teraType,
                          fallbackTypes: _session.attacker.types,
                          generation: generation,
                          onTerastallizedChanged: (value) => _edit(
                            () => _session.attacker.terastallized = value,
                          ),
                          onTeraTypeChanged: (type) =>
                              _edit(() => _session.attacker.teraType = type),
                        ),
                      ],
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
                                generation,
                              );
                            });
                            _clearLinkedDefender();
                          }
                        },
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
                          _session.defender.abilities,
                        ),
                        linkedPokemonId: _session.defender.pokemonId,
                        selectedSlug: _session.defender.abilitySlug,
                        onChanged: (slug) =>
                            _edit(() => _session.defender.abilitySlug = slug),
                      ),
                      if (generation >= 9) ...[
                        const SizedBox(height: 8),
                        TerastalPicker(
                          label: AppZh.battleTerastal,
                          enabled: true,
                          terastallized: _session.defender.terastallized,
                          teraType: _session.defender.teraType,
                          fallbackTypes: _session.defender.types,
                          generation: generation,
                          onTerastallizedChanged: (value) => _edit(
                            () => _session.defender.terastallized = value,
                          ),
                          onTeraTypeChanged: (type) =>
                              _edit(() => _session.defender.teraType = type),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                '${scope.typeChartNote}\n${AppZh.companionGenerationTypeNote}',
                style: SecondaryTypography.onPage(context).small12,
              ),
            ],
          ],
        );
      },
    );
  }
}
