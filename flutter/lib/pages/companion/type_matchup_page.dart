import 'package:flutter/material.dart';

import '../../features/companion/battle_game_scope.dart';
import '../../features/companion/battle_tools_service.dart';
import '../../features/dex/dex_models.dart';
import '../../features/dex/dex_repository.dart';
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
  final _queryController = TextEditingController();
  List<String> _defenderTypes = const ['fire'];
  List<String> _attackerTypes = const [];
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
      _suggestions = const [];
      _queryController.text = summary.nameZh;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gameEditionRepository,
      builder: (context, _) {
        final edition = gameEditionRepository.edition;
        final scope = battleScopeForEdition(edition);
        final relations = _relations;

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
              subtitle: scope.typeChartNote,
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
                      borderSide:
                          const BorderSide(color: TitoColors.ink, width: 2),
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
                      setState(() => _defenderTypes = types);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final profile =
                    computeDefensiveProfile(_defenderTypes, relations);
                final multipliers =
                    computeDefensiveMultipliers(_defenderTypes, relations);
                return Column(
                  children: [
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
                            profileLine(AppZh.dexWeaknesses, profile.weaknesses),
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
                            profileLine(AppZh.dexImmunities, profile.immunities),
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
                CollapsibleTypePicker(
                  label: AppZh.companionTypeAttackerPick,
                  selected: _attackerTypes,
                  maxSelected: 2,
                  onChanged: (types) => setState(() => _attackerTypes = types),
                ),
                if (_attackerTypes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    profileLine(
                      AppZh.dexStabEffective,
                      computeStabSuperEffective(_attackerTypes, relations),
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
