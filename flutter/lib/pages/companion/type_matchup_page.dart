import 'package:flutter/material.dart';

import '../../features/companion/battle_game_scope.dart';
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
import '../../theme/tito_font_scale.dart';
import '../../widgets/companion_tool_fields.dart';
import '../../widgets/pokemon_detail_sections.dart';
import '../../widgets/secondary_page_scaffold.dart';
import '../../widgets/sticker_card.dart';

class TypeMatchupPage extends StatefulWidget {
  const TypeMatchupPage({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  State<TypeMatchupPage> createState() => _TypeMatchupPageState();
}

class _TypeMatchupPageState extends State<TypeMatchupPage> {
  final _defenderQueryController = TextEditingController();
  final _attackerQueryController = TextEditingController();
  List<String> _defenderTypes = const ['fire'];
  List<String> _attackerTypes = const [];
  String? _defenderAbilitySlug;
  String? _attackerAbilitySlug;
  int? _linkedDefenderId;
  int? _linkedAttackerId;
  bool _defenderTerastallized = false;
  String? _defenderTeraType;
  bool _attackerTerastallized = false;
  String? _attackerTeraType;
  List<DefensiveAbilityOption> _defenderAbilityOptions = const [];
  List<DefensiveAbilityOption> _attackerAbilityOptions = const [];
  Map<String, TypeDamageRelations>? _relations;
  String? _error;
  bool _loading = true;
  List<PokemonSummary> _defenderSuggestions = const [];
  List<PokemonSummary> _attackerSuggestions = const [];

  @override
  void initState() {
    super.initState();
    _loadRelations();
  }

  @override
  void dispose() {
    _defenderQueryController.dispose();
    _attackerQueryController.dispose();
    super.dispose();
  }

  Future<void> _loadRelations() async {
    try {
      final relations = await battleToolsService.loadTypeRelations();
      if (!mounted) {
        return;
      }
      setState(() {
        _relations = relations;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = formatUserFacingError(error);
        _loading = false;
      });
    }
  }

  Future<void> _searchDefender(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _defenderSuggestions = const []);
      return;
    }
    final results = await dexRepository.search(trimmed);
    if (!mounted || _defenderQueryController.text.trim() != trimmed) {
      return;
    }
    setState(() => _defenderSuggestions = results.take(6).toList());
  }

  Future<void> _searchAttacker(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _attackerSuggestions = const []);
      return;
    }
    final results = await dexRepository.search(trimmed);
    if (!mounted || _attackerQueryController.text.trim() != trimmed) {
      return;
    }
    setState(() => _attackerSuggestions = results.take(6).toList());
  }

  void _applyDefender(PokemonSummary summary) {
    setState(() {
      _defenderTypes = List<String>.from(summary.types);
      _defenderSuggestions = const [];
      _defenderQueryController.text = summary.nameZh;
      _linkedDefenderId = summary.id;
      _defenderAbilityOptions = const [];
      _defenderAbilitySlug = null;
      _defenderTerastallized = false;
      _defenderTeraType = defaultTeraTypeFor(summary.types, 9);
    });
    _loadDefenderAbilities(summary.id);
  }

  void _applyAttacker(PokemonSummary summary) {
    setState(() {
      _attackerTypes = List<String>.from(summary.types);
      _attackerSuggestions = const [];
      _attackerQueryController.text = summary.nameZh;
      _linkedAttackerId = summary.id;
      _attackerAbilityOptions = const [];
      _attackerAbilitySlug = null;
      _attackerTerastallized = false;
      _attackerTeraType = defaultTeraTypeFor(summary.types, 9);
    });
    _loadAttackerAbilities(summary.id);
  }

  void _clearLinkedDefender() {
    setState(() {
      _linkedDefenderId = null;
      _defenderAbilityOptions = const [];
      _defenderAbilitySlug = null;
    });
  }

  void _clearLinkedAttacker() {
    setState(() {
      _linkedAttackerId = null;
      _attackerAbilityOptions = const [];
      _attackerAbilitySlug = null;
    });
  }

  Future<void> _loadDefenderAbilities(int pokemonId) async {
    try {
      final abilities = await dexRepository.abilitiesForPokemon(pokemonId);
      if (!mounted || _linkedDefenderId != pokemonId) {
        return;
      }
      final options = defensiveAbilityOptionsFrom(abilities);
      setState(() {
        _defenderAbilityOptions = options;
        _defenderAbilitySlug = defaultAbilitySlugForOptions(options);
      });
    } catch (_) {}
  }

  Future<void> _loadAttackerAbilities(int pokemonId) async {
    try {
      final abilities = await dexRepository.abilitiesForPokemon(pokemonId);
      if (!mounted || _linkedAttackerId != pokemonId) {
        return;
      }
      final options = attackerAbilityOptionsFromPokemon(abilities);
      setState(() {
        _attackerAbilityOptions = options;
        _attackerAbilitySlug = defaultAbilitySlugForOptions(options);
      });
    } catch (_) {}
  }

  BattleEffectivenessInput _defenderInput(
    Map<String, TypeDamageRelations> relations,
    int generation,
  ) {
    return BattleEffectivenessInput(
      defenderTypes: _defenderTypes,
      relationsByType: relations,
      defenderAbilitySlug: _defenderAbilitySlug,
      attackerAbilitySlug: _attackerAbilitySlug,
      generation: generation,
      defenderTerastallized: _defenderTerastallized,
      defenderTeraType: _defenderTeraType,
      attackerTerastallized: _attackerTerastallized,
      attackerTeraType: _attackerTeraType,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gameEditionRepository,
      builder: (context, _) {
        final edition = gameEditionRepository.edition;
        final scope = battleScopeForEdition(edition);
        final relations = _relations;
        final generation = scope.generation;

        return TitoFontScale(
          multiplier: 1.0,
          child: Material(
            type: MaterialType.transparency,
            child: SecondaryPageScaffold(
              title: AppZh.companionToolTypeMatchup,
              subtitle: edition.labelZh,
              children: [
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  StickerCard(
                    child: Text(
                      _error!,
                      style: SecondaryTypography.onCard.small12.copyWith(
                        color: TitoColors.mutedInk,
                        height: 1.45,
                      ),
                    ),
                  )
                else if (relations != null) ...[
                  CompanionSectionCard(
                    title: AppZh.companionTypeDefenderTitle,
                    subtitle:
                        '${scope.typeChartNote}\n${AppZh.companionGenerationTypeNote}',
                    children: [
                      PokemonSearchField(
                        controller: _defenderQueryController,
                        hintText: AppZh.companionDefenderSearchHint,
                        suggestions: _defenderSuggestions,
                        onQueryChanged: _searchDefender,
                        onPokemonSelected: _applyDefender,
                        prefixIcon: Icons.shield_rounded,
                      ),
                      const SizedBox(height: 12),
                      LinkedOrManualTypePicker(
                        linkedPokemonId: _linkedDefenderId,
                        label: AppZh.companionTypeManualPick,
                        selected: _defenderTypes,
                        onManualChanged: (types) {
                          if (types.isNotEmpty) {
                            setState(() {
                              _defenderTypes = types;
                              _defenderTeraType =
                                  defaultTeraTypeFor(types, generation);
                            });
                            _clearLinkedDefender();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      CompanionAbilitySection(
                        pokemonLabel: AppZh.companionDefenderAbilityPick,
                        manualLabel: AppZh.companionManualAbilityPick,
                        manualOptions: kManualDefensiveAbilityOptions,
                        pokemonOptions: _defenderAbilityOptions,
                        linkedPokemonId: _linkedDefenderId,
                        selectedSlug: _defenderAbilitySlug,
                        onChanged: (slug) =>
                            setState(() => _defenderAbilitySlug = slug),
                      ),
                      if (generation >= 9) ...[
                        const SizedBox(height: 12),
                        TerastalPicker(
                          label: AppZh.companionDefenderTerastal,
                          enabled: true,
                          terastallized: _defenderTerastallized,
                          teraType: _defenderTeraType,
                          fallbackTypes: _defenderTypes,
                          generation: generation,
                          onTerastallizedChanged: (value) => setState(
                            () => _defenderTerastallized = value,
                          ),
                          onTeraTypeChanged: (type) =>
                              setState(() => _defenderTeraType = type),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final input = _defenderInput(relations, generation);
                      final profile = computeBattleDefensiveProfile(input);
                      final multipliers = computeBattleTypeMultipliers(input);
                      final normalized = normalizeTypesForGeneration(
                        _defenderTypes,
                        generation,
                      );

                      return Column(
                        children: [
                          if (generation < 6)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '世代修正：${normalized.map(typeNameZh).join('/')}',
                                style: SecondaryTypography.onCard.small12
                                    .copyWith(color: TitoColors.mutedInk),
                              ),
                            ),
                          StickerCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppZh.companionTypeSummaryTitle,
                                  style: SecondaryTypography.onCard.h15,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  profileLine(
                                    AppZh.dexWeaknesses,
                                    profile.weaknesses,
                                  ),
                                  style: SecondaryTypography.onCard.body14,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profileLine(
                                    AppZh.dexResistances,
                                    profile.resistances,
                                  ),
                                  style: SecondaryTypography.onCard.body14,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profileLine(
                                    AppZh.dexImmunities,
                                    profile.immunities,
                                  ),
                                  style: SecondaryTypography.onCard.body14,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          TypeEffectivenessGrid(multipliers: multipliers),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  CompanionSectionCard(
                    title: AppZh.companionTypeAttackerTitle,
                    children: [
                      PokemonSearchField(
                        controller: _attackerQueryController,
                        hintText: AppZh.companionAttackerSearchHint,
                        suggestions: _attackerSuggestions,
                        onQueryChanged: _searchAttacker,
                        onPokemonSelected: _applyAttacker,
                        prefixIcon: Icons.sports_martial_arts_rounded,
                      ),
                      const SizedBox(height: 12),
                      LinkedOrManualTypePicker(
                        linkedPokemonId: _linkedAttackerId,
                        label: AppZh.companionTypeAttackerPick,
                        selected: _attackerTypes,
                        maxSelected: 2,
                        onManualChanged: (types) {
                          setState(() => _attackerTypes = types);
                          _clearLinkedAttacker();
                        },
                      ),
                      const SizedBox(height: 12),
                      CompanionAbilitySection(
                        pokemonLabel: AppZh.companionAttackerAbilityPick,
                        manualLabel: AppZh.companionAttackerAbilityPick,
                        manualOptions: kManualAttackerAbilityOptions,
                        pokemonOptions: _attackerAbilityOptions,
                        linkedPokemonId: _linkedAttackerId,
                        selectedSlug: _attackerAbilitySlug,
                        onChanged: (slug) =>
                            setState(() => _attackerAbilitySlug = slug),
                      ),
                      if (generation >= 9) ...[
                        const SizedBox(height: 12),
                        TerastalPicker(
                          label: AppZh.companionAttackerTerastal,
                          enabled: true,
                          terastallized: _attackerTerastallized,
                          teraType: _attackerTeraType,
                          fallbackTypes: _attackerTypes,
                          generation: generation,
                          onTerastallizedChanged: (value) => setState(
                            () => _attackerTerastallized = value,
                          ),
                          onTeraTypeChanged: (type) =>
                              setState(() => _attackerTeraType = type),
                        ),
                      ],
                      if (_attackerTypes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          profileLine(
                            AppZh.companionOffensiveBlindSpots,
                            computeOffensiveBlindSpots(
                              _attackerTypes,
                              relations,
                              generation: generation,
                              attackerAbilitySlug: _attackerAbilitySlug,
                              attackerTerastallized: _attackerTerastallized,
                              attackerTeraType: _attackerTeraType,
                            ),
                          ),
                          style: SecondaryTypography.onCard.body14.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
