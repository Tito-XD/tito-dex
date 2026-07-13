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
import '../../widgets/secondary_page_scaffold.dart';
import '../../widgets/sticker_card.dart';
import '../../widgets/tito_loading_panel.dart';

class BlindSpotPage extends StatefulWidget {
  const BlindSpotPage({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  State<BlindSpotPage> createState() => _BlindSpotPageState();
}

class _BlindSpotPageState extends State<BlindSpotPage> {
  final _defenderQueryController = TextEditingController();
  final _attackerQueryController = TextEditingController();
  List<String> _defenderTypes = const ['water', 'fairy'];
  List<String> _attackerTypes = const ['grass'];
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

  BattleEffectivenessInput _input(
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
              title: AppZh.companionToolBlindSpot,
              subtitle: edition.labelZh,
              children: [
                if (_loading)
                  const TitoLoadingPanel(
                    message: AppZh.companionLoading,
                    compact: true,
                  )
                else if (_error != null)
                  StickerCard(
                    child: Text(
                      _error!,
                      style: SecondaryTypography.onCard.small12.copyWith(
                        color: TitoColors.mutedInk,
                      ),
                    ),
                  )
                else if (relations != null) ...[
                  CompanionSectionCard(
                    title: AppZh.companionTypeDefenderTitle,
                    subtitle: AppZh.companionGenerationTypeNote,
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
                    ],
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final input = _input(relations, generation);
                      final offensive = computeOffensiveBlindSpots(
                        _attackerTypes,
                        relations,
                        generation: generation,
                        attackerAbilitySlug: _attackerAbilitySlug,
                        attackerTerastallized: _attackerTerastallized,
                        attackerTeraType: _attackerTeraType,
                      );
                      final defensive = computeDefensiveBlindSpots(input);
                      final normalized = normalizeTypesForGeneration(
                        _defenderTypes,
                        generation,
                      );

                      return Column(
                        children: [
                          StickerCard(
                            variant: StickerVariant.mint,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppZh.companionOffensiveBlindSpots,
                                  style: SecondaryTypography.onCard.h15,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  profileLine('', offensive),
                                  style: SecondaryTypography.onCard.body14,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  AppZh.companionDefensiveBlindSpots,
                                  style: SecondaryTypography.onCard.h15,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  profileLine('', defensive),
                                  style: SecondaryTypography.onCard.body14,
                                ),
                                if (generation < 6) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '世代修正属性：${normalized.map(typeNameZh).join('/')}',
                                    style: SecondaryTypography.onCard.small12
                                        .copyWith(color: TitoColors.mutedInk),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
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
