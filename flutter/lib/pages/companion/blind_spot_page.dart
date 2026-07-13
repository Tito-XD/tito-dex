import 'package:flutter/material.dart';

import '../../features/companion/battle_game_scope.dart';
import '../../features/companion/battle_tools_service.dart';
import '../../features/dex/ability_type_modifiers.dart';
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
  final _queryController = TextEditingController();
  List<String> _defenderTypes = const ['water', 'fairy'];
  List<String> _attackerTypes = const ['grass'];
  String? _defenderAbilitySlug;
  String? _attackerAbilitySlug;
  bool _defenderTerastallized = false;
  String? _defenderTeraType;
  bool _attackerTerastallized = false;
  String? _attackerTeraType;
  List<DefensiveAbilityOption> _defenderAbilityOptions = const [];
  Map<String, TypeDamageRelations>? _relations;
  String? _error;
  bool _loading = true;
  List<PokemonSummary> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _loadRelations();
  }

  @override
  void dispose() {
    _queryController.dispose();
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

  Future<void> _searchPokemon(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }
    final results = await dexRepository.search(trimmed);
    if (!mounted || _queryController.text.trim() != trimmed) {
      return;
    }
    setState(() => _suggestions = results.take(6).toList());
  }

  void _applyPokemon(PokemonSummary summary) {
    setState(() {
      _defenderTypes = List<String>.from(summary.types);
      _attackerTypes = List<String>.from(summary.types);
      _suggestions = const [];
      _queryController.text = summary.nameZh;
      _defenderAbilityOptions = const [];
      _defenderAbilitySlug = null;
      _attackerAbilitySlug = null;
      _defenderTerastallized = false;
      _defenderTeraType = defaultTeraTypeFor(summary.types, 9);
      _attackerTerastallized = false;
      _attackerTeraType = defaultTeraTypeFor(summary.types, 9);
    });
    _loadAbilities(summary.id);
  }

  Future<void> _loadAbilities(int pokemonId) async {
    try {
      final detail = await dexRepository.getDetail(pokemonId);
      if (!mounted) {
        return;
      }
      final options = detail.abilities
          .map(
            (ability) => DefensiveAbilityOption(
              slug: abilitySlugFromNameEn(ability.nameEn),
              labelZh: ability.nameZh,
              isHidden: ability.isHidden,
            ),
          )
          .toList(growable: false);
      setState(() {
        _defenderAbilityOptions = options;
        _defenderAbilitySlug =
            options.length == 1 ? options.first.slug : null;
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
                      TextField(
                        controller: _queryController,
                        onChanged: _searchPokemon,
                        decoration: InputDecoration(
                          hintText: AppZh.companionPokemonSearchHint,
                          filled: true,
                          fillColor: TitoColors.card,
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: TitoColors.ink,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      if (_suggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _suggestions
                              .map(
                                (entry) => ActionChip(
                                  label: Text(entry.nameZh),
                                  onPressed: () => _applyPokemon(entry),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      CollapsibleTypePicker(
                        label: AppZh.companionTypeManualPick,
                        selected: _defenderTypes,
                        onChanged: (types) {
                          if (types.isNotEmpty) {
                            setState(() {
                              _defenderTypes = types;
                              _defenderAbilityOptions = const [];
                              _defenderAbilitySlug = null;
                              _defenderTeraType =
                                  defaultTeraTypeFor(types, generation);
                            });
                          }
                        },
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
                      if (_defenderAbilityOptions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DefensiveAbilityPicker(
                          selectedSlug: _defenderAbilitySlug,
                          options: _defenderAbilityOptions,
                          onChanged: (slug) =>
                              setState(() => _defenderAbilitySlug = slug),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        ManualAbilityPicker(
                          label: AppZh.companionManualAbilityPick,
                          options: kManualDefensiveAbilityOptions,
                          selectedSlug: _defenderAbilitySlug,
                          onChanged: (slug) =>
                              setState(() => _defenderAbilitySlug = slug),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  CompanionSectionCard(
                    title: AppZh.companionTypeAttackerTitle,
                    children: [
                      CollapsibleTypePicker(
                        label: AppZh.companionTypeAttackerPick,
                        selected: _attackerTypes,
                        maxSelected: 2,
                        onChanged: (types) =>
                            setState(() => _attackerTypes = types),
                      ),
                      const SizedBox(height: 12),
                      ManualAbilityPicker(
                        label: AppZh.companionAttackerAbilityPick,
                        options: kManualAttackerAbilityOptions,
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
                      final defensive =
                          computeDefensiveBlindSpots(input);
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
