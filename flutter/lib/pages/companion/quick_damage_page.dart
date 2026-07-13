import 'package:flutter/material.dart';

import '../../features/companion/battle_game_scope.dart';
import '../../features/companion/battle_math.dart';
import '../../features/companion/battle_tools_service.dart';
import '../../features/dex/ability_type_modifiers.dart';
import '../../features/dex/battle_effectiveness.dart';
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
import '../../widgets/secondary_page_scaffold.dart';
import '../../widgets/sticker_card.dart';

class QuickDamagePage extends StatefulWidget {
  const QuickDamagePage({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  State<QuickDamagePage> createState() => _QuickDamagePageState();
}

class _QuickDamagePageState extends State<QuickDamagePage> {
  final _attackerQueryController = TextEditingController();
  final _defenderQueryController = TextEditingController();
  final _levelController = TextEditingController(text: '50');
  final _powerController = TextEditingController(text: '80');
  final _attackController = TextEditingController(text: '100');
  final _defenseController = TextEditingController(text: '100');
  final _hpController = TextEditingController(text: '150');

  MoveCategory _category = MoveCategory.physical;
  String _moveType = 'normal';
  List<String> _attackerTypes = const ['normal'];
  List<String> _defenderTypes = const ['normal'];
  String? _defenderAbilitySlug;
  String? _attackerAbilitySlug;
  int? _linkedDefenderId;
  bool _defenderTerastallized = false;
  String? _defenderTeraType;
  bool _attackerTerastallized = false;
  String? _attackerTeraType;
  BattleHeldItem _heldItem = BattleHeldItem.none;
  String? _typeBoostItemType;
  BattleStatusCondition _attackerStatus = BattleStatusCondition.none;
  bool _isContactMove = false;
  List<DefensiveAbilityOption> _defenderAbilityOptions = const [];
  FieldCondition _weather = FieldCondition.none;
  TerrainCondition _terrain = TerrainCondition.none;
  Map<String, TypeDamageRelations>? _relations;
  String? _error;
  bool _loading = true;
  List<PokemonSummary> _attackerSuggestions = const [];
  List<PokemonSummary> _defenderSuggestions = const [];

  @override
  void initState() {
    super.initState();
    final scope = battleScopeForEdition(gameEditionRepository.edition);
    _levelController.text = scope.defaultLevel.toString();
    _loadRelations();
  }

  @override
  void dispose() {
    _attackerQueryController.dispose();
    _defenderQueryController.dispose();
    _levelController.dispose();
    _powerController.dispose();
    _attackController.dispose();
    _defenseController.dispose();
    _hpController.dispose();
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

  Future<void> _applyAttacker(PokemonSummary summary) async {
    final detail = await dexRepository.getDetail(summary.id);
    final stats = detail.baseStats;
    if (stats == null) {
      return;
    }
    final attackStat = _category == MoveCategory.physical
        ? stats.attack
        : stats.specialAttack;
    if (!mounted) {
      return;
    }
    final generation =
        battleScopeForEdition(gameEditionRepository.edition).generation;
    setState(() {
      _attackerTypes = List<String>.from(summary.types);
      _attackController.text = attackStat.toString();
      _attackerSuggestions = const [];
      _attackerQueryController.text = summary.nameZh;
      _attackerTeraType = defaultTeraTypeFor(summary.types, generation);
    });
  }

  Future<void> _applyDefender(PokemonSummary summary) async {
    final detail = await dexRepository.getDetail(summary.id);
    final stats = detail.baseStats;
    if (stats == null) {
      return;
    }
    final defenseStat = _category == MoveCategory.physical
        ? stats.defense
        : stats.specialDefense;
    if (!mounted) {
      return;
    }
    setState(() {
      _defenderTypes = List<String>.from(summary.types);
      _defenseController.text = defenseStat.toString();
      _hpController.text = stats.hp.toString();
      _defenderSuggestions = const [];
      _defenderQueryController.text = summary.nameZh;
      _linkedDefenderId = summary.id;
      _defenderAbilityOptions = const [];
      _defenderAbilitySlug = null;
      _defenderTeraType = defaultTeraTypeFor(
        summary.types,
        battleScopeForEdition(gameEditionRepository.edition).generation,
      );
    });
    _loadDefenderAbilities(summary.id);
  }

  void _clearLinkedDefender() {
    setState(() {
      _linkedDefenderId = null;
      _defenderAbilityOptions = const [];
      _defenderAbilitySlug = null;
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

  int _readInt(TextEditingController controller, int fallback) =>
      int.tryParse(controller.text.trim()) ?? fallback;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gameEditionRepository,
      builder: (context, _) {
        final edition = gameEditionRepository.edition;
        final scope = battleScopeForEdition(edition);
        final relations = _relations;
        DamageEstimate? estimate;
        if (relations != null) {
          estimate = estimateDamage(
            level: _readInt(_levelController, scope.defaultLevel),
            power: _readInt(_powerController, 80),
            attack: _readInt(_attackController, 100),
            defense: _readInt(_defenseController, 100),
            defenderHp: _readInt(_hpController, 150),
            moveType: _moveType,
            attackerTypes: _attackerTypes,
            defenderTypes: _defenderTypes,
            relationsByType: relations,
            defenderAbilitySlug: _defenderAbilitySlug,
            attackerAbilitySlug: _attackerAbilitySlug,
            generation: scope.generation,
            weatherSlug: _weather.slug.isEmpty ? null : _weather.slug,
            terrainSlug: _terrain.slug.isEmpty ? null : _terrain.slug,
            category: _category,
            defenderTerastallized: _defenderTerastallized,
            defenderTeraType: _defenderTeraType,
            attackerTerastallized: _attackerTerastallized,
            attackerTeraType: _attackerTeraType,
            attackerHeldItem: _heldItem,
            typeBoostItemType: _typeBoostItemType,
            attackerStatus: _attackerStatus,
            isContactMove: _isContactMove,
          );
        }

        return TitoFontScale(
          multiplier: 1.0,
          child: Material(
            type: MaterialType.transparency,
            child: SecondaryPageScaffold(
              title: AppZh.companionToolQuickDamage,
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
          else ...[
            CompanionSectionCard(
              title: AppZh.companionDamageInputsTitle,
              subtitle: scope.damageNote,
              children: [
                Text(
                  AppZh.companionDamageFacility(scope.facilityLabel),
                  style: SecondaryTypography.onCard.small12.copyWith(
                    fontWeight: FontWeight.w800,
                    color: TitoColors.deepBlue,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _attackerQueryController,
                  onChanged: _searchAttacker,
                  decoration: InputDecoration(
                    hintText: AppZh.companionAttackerSearchHint,
                    filled: true,
                    fillColor: TitoColors.card,
                    prefixIcon: const Icon(Icons.sports_martial_arts_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: TitoColors.ink, width: 2),
                    ),
                  ),
                ),
                if (_attackerSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _attackerSuggestions
                        .map(
                          (entry) => ActionChip(
                            label: Text(entry.nameZh),
                            onPressed: () => _applyAttacker(entry),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _defenderQueryController,
                  onChanged: _searchDefender,
                  decoration: InputDecoration(
                    hintText: AppZh.companionDefenderSearchHint,
                    filled: true,
                    fillColor: TitoColors.card,
                    prefixIcon: const Icon(Icons.shield_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: TitoColors.ink, width: 2),
                    ),
                  ),
                ),
                if (_defenderSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _defenderSuggestions
                        .map(
                          (entry) => ActionChip(
                            label: Text(entry.nameZh),
                            onPressed: () => _applyDefender(entry),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                MoveCategoryPicker(
                  selected: _category,
                  onChanged: (value) => setState(() => _category = value),
                ),
                const SizedBox(height: 12),
                CollapsibleTypePicker(
                  label: AppZh.companionMoveType,
                  selected: [_moveType],
                  maxSelected: 1,
                  onChanged: (types) {
                    if (types.isNotEmpty) {
                      setState(() => _moveType = types.first);
                    }
                  },
                ),
                const SizedBox(height: 12),
                CollapsibleTypePicker(
                  label: AppZh.companionTypeAttackerPick,
                  selected: _attackerTypes,
                  onChanged: (types) => setState(() => _attackerTypes = types),
                ),
                const SizedBox(height: 12),
                CollapsibleTypePicker(
                  label: AppZh.companionTypeManualPick,
                  selected: _defenderTypes,
                  onChanged: (types) {
                    if (types.isNotEmpty) {
                      setState(() {
                        _defenderTypes = types;
                        _defenderTeraType =
                            defaultTeraTypeFor(types, scope.generation);
                      });
                      _clearLinkedDefender();
                    }
                  },
                ),
                if (scope.generation >= 9) ...[
                  const SizedBox(height: 12),
                  TerastalPicker(
                    label: AppZh.companionDefenderTerastal,
                    enabled: true,
                    terastallized: _defenderTerastallized,
                    teraType: _defenderTeraType,
                    fallbackTypes: _defenderTypes,
                    generation: scope.generation,
                    onTerastallizedChanged: (value) =>
                        setState(() => _defenderTerastallized = value),
                    onTeraTypeChanged: (type) =>
                        setState(() => _defenderTeraType = type),
                  ),
                  const SizedBox(height: 12),
                  TerastalPicker(
                    label: AppZh.companionAttackerTerastal,
                    enabled: true,
                    terastallized: _attackerTerastallized,
                    teraType: _attackerTeraType,
                    fallbackTypes: _attackerTypes,
                    generation: scope.generation,
                    onTerastallizedChanged: (value) =>
                        setState(() => _attackerTerastallized = value),
                    onTeraTypeChanged: (type) =>
                        setState(() => _attackerTeraType = type),
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
                ] else if (_linkedDefenderId == null) ...[
                  const SizedBox(height: 12),
                  ManualAbilityPicker(
                    label: AppZh.companionManualAbilityPick,
                    options: kManualDefensiveAbilityOptions,
                    selectedSlug: _defenderAbilitySlug,
                    onChanged: (slug) =>
                        setState(() => _defenderAbilitySlug = slug),
                  ),
                ],
                const SizedBox(height: 12),
                ManualAbilityPicker(
                  label: AppZh.companionAttackerAbilityPick,
                  options: kManualAttackerAbilityOptions,
                  selectedSlug: _attackerAbilitySlug,
                  onChanged: (slug) =>
                      setState(() => _attackerAbilitySlug = slug),
                ),
                const SizedBox(height: 12),
                FieldConditionPicker(
                  label: AppZh.companionWeatherPick,
                  selected: _weather,
                  onChanged: (value) => setState(() => _weather = value),
                ),
                const SizedBox(height: 12),
                TerrainConditionPicker(
                  label: AppZh.companionTerrainPick,
                  selected: _terrain,
                  onChanged: (value) => setState(() => _terrain = value),
                ),
                const SizedBox(height: 12),
                HeldItemPicker(
                  selected: _heldItem,
                  onChanged: (value) => setState(() => _heldItem = value),
                  typeBoostItemType: _typeBoostItemType,
                  onTypeBoostChanged: (type) =>
                      setState(() => _typeBoostItemType = type),
                ),
                const SizedBox(height: 12),
                StatusConditionPicker(
                  selected: _attackerStatus,
                  onChanged: (value) =>
                      setState(() => _attackerStatus = value),
                ),
                const SizedBox(height: 12),
                ContactMoveToggle(
                  value: _isContactMove,
                  onChanged: (value) => setState(() => _isContactMove = value),
                ),
                const SizedBox(height: 12),
                CompanionNumberField(
                  label: AppZh.companionStatLevel,
                  controller: _levelController,
                  max: 100,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                CompanionNumberField(
                  label: AppZh.companionMovePower,
                  controller: _powerController,
                  max: 250,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CompanionNumberField(
                        label: _category == MoveCategory.physical
                            ? AppZh.companionAttackStat
                            : AppZh.companionSpAttackStat,
                        controller: _attackController,
                        max: 999,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CompanionNumberField(
                        label: _category == MoveCategory.physical
                            ? AppZh.companionDefenseStat
                            : AppZh.companionSpDefenseStat,
                        controller: _defenseController,
                        max: 999,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CompanionNumberField(
                  label: AppZh.companionDefenderHp,
                  controller: _hpController,
                  max: 999,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
            if (estimate != null) ...[
              const SizedBox(height: 12),
              StickerCard(
                variant: StickerVariant.mint,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppZh.companionDamageResultTitle,
                      style: SecondaryTypography.onCard.h15,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppZh.companionDamageRange(
                        estimate.minDamage,
                        estimate.maxDamage,
                      ),
                      style: SecondaryTypography.onCard.h15.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppZh.companionDamagePercent(
                        estimate.minPercent,
                        estimate.maxPercent,
                      ),
                      style: SecondaryTypography.onCard.body14.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${AppZh.companionDamageOffense}：${estimate.verdictZh}',
                      style: SecondaryTypography.onCard.body14,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppZh.companionDamageDefense}：${estimate.tankVerdictZh}',
                      style: SecondaryTypography.onCard.body14,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppZh.companionDamageModifiers(
                        formatTypeMultiplier(estimate.typeMultiplier),
                        estimate.stabMultiplier == 1.0
                            ? '1'
                            : estimate.stabMultiplier.toStringAsFixed(1),
                      ),
                      style: SecondaryTypography.onCard.small12.copyWith(
                        color: TitoColors.mutedInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (estimate.extraMultiplier != 1) ...[
                      const SizedBox(height: 4),
                      Text(
                        AppZh.companionDamageExtra(
                          estimate.extraMultiplier.toStringAsFixed(2),
                        ),
                        style: SecondaryTypography.onCard.small12.copyWith(
                          color: TitoColors.mutedInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
              ],
            ),
          ),
        );
      },
    );
  }
}
