import 'package:flutter/material.dart';

import '../../features/companion/battle_game_scope.dart';
import '../../features/companion/battle_math.dart';
import '../../features/companion/battle_tools_service.dart';
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
import '../../widgets/tito_loading_panel.dart';

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
  int? _linkedAttackerId;
  bool _defenderTerastallized = false;
  String? _defenderTeraType;
  bool _attackerTerastallized = false;
  String? _attackerTeraType;
  BattleHeldItem _heldItem = BattleHeldItem.none;
  String? _typeBoostItemType;
  BattleStatusCondition _attackerStatus = BattleStatusCondition.none;
  bool _isContactMove = false;
  bool _isCriticalHit = false;
  bool _defenderScreened = false;
  List<DefensiveAbilityOption> _defenderAbilityOptions = const [];
  List<DefensiveAbilityOption> _attackerAbilityOptions = const [];
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
      _linkedAttackerId = summary.id;
      _attackerAbilityOptions = const [];
      _attackerAbilitySlug = null;
      _attackerTerastallized = false;
      _attackerTeraType = defaultTeraTypeFor(summary.types, generation);
    });
    _loadAttackerAbilities(summary.id);
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

  void _clearLinkedAttacker() {
    setState(() {
      _linkedAttackerId = null;
      _attackerAbilityOptions = const [];
      _attackerAbilitySlug = null;
    });
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
            isCriticalHit: _isCriticalHit,
            defenderScreened: _defenderScreened,
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
                PokemonSearchField(
                  controller: _attackerQueryController,
                  hintText: AppZh.companionAttackerSearchHint,
                  suggestions: _attackerSuggestions,
                  onQueryChanged: _searchAttacker,
                  onPokemonSelected: _applyAttacker,
                  prefixIcon: Icons.sports_martial_arts_rounded,
                ),
                const SizedBox(height: 12),
                PokemonSearchField(
                  controller: _defenderQueryController,
                  hintText: AppZh.companionDefenderSearchHint,
                  suggestions: _defenderSuggestions,
                  onQueryChanged: _searchDefender,
                  onPokemonSelected: _applyDefender,
                  prefixIcon: Icons.shield_rounded,
                ),
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
                LinkedOrManualTypePicker(
                  linkedPokemonId: _linkedAttackerId,
                  label: AppZh.companionTypeAttackerPick,
                  selected: _attackerTypes,
                  onManualChanged: (types) {
                    setState(() => _attackerTypes = types);
                    _clearLinkedAttacker();
                  },
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
                if (_defenderAbilityOptions.isNotEmpty ||
                    _linkedDefenderId == null) ...[
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
                ],
                if (_attackerAbilityOptions.isNotEmpty ||
                    _linkedAttackerId == null) ...[
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
                ],
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ContactMoveToggle(
                      value: _isContactMove,
                      onChanged: (value) =>
                          setState(() => _isContactMove = value),
                    ),
                    BattleToggleChip(
                      label: AppZh.companionCriticalHit,
                      value: _isCriticalHit,
                      onChanged: (value) =>
                          setState(() => _isCriticalHit = value),
                    ),
                    BattleToggleChip(
                      label: AppZh.companionDefenderScreen,
                      value: _defenderScreened,
                      onChanged: (value) =>
                          setState(() => _defenderScreened = value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CompanionNumberField(
                  label: AppZh.companionStatLevel,
                  controller: _levelController,
                  max: 100,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _PowerSliderRow(
                  controller: _powerController,
                  onChanged: () => setState(() {}),
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
              _DamageResultCard(estimate: estimate),
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

/// Move-power slider row (battle template): label + live value over a
/// coral-filled rail. The text controller stays the source of truth so the
/// estimate pipeline is unchanged.
class _PowerSliderRow extends StatelessWidget {
  const _PowerSliderRow({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  static const _min = 10.0;
  static const _max = 250.0;

  @override
  Widget build(BuildContext context) {
    final current = (int.tryParse(controller.text.trim()) ?? 80)
        .clamp(_min.toInt(), _max.toInt())
        .toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppZh.companionMovePower,
              style: SecondaryTypography.onCard.small12.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              current.round().toString(),
              style: SecondaryTypography.onCard.meta14.copyWith(
                color: TitoColors.deepBlue,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: TitoColors.coral,
            inactiveTrackColor: TitoColors.cardWarm,
            thumbColor: TitoColors.card,
            overlayColor: TitoColors.coral.withValues(alpha: 0.15),
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 11,
              elevation: 0,
              pressedElevation: 0,
            ),
          ),
          child: Slider(
            value: current,
            min: _min,
            max: _max,
            divisions: (_max - _min).toInt(),
            onChanged: (value) {
              controller.text = value.round().toString();
              onChanged();
            },
          ),
        ),
      ],
    );
  }
}

/// Result card (battle template): the single accent focus of the page —
/// deep-blue card, oversized soft-yellow percentage, and an HP bar split
/// into mint-safe / coral-damage segments.
class _DamageResultCard extends StatelessWidget {
  const _DamageResultCard({required this.estimate});

  final DamageEstimate estimate;

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
              return Container(
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: TitoColors.ink, width: 2),
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
          Text(
            '${AppZh.companionDamageDefense}：${estimate.tankVerdictZh}',
            style: SecondaryTypography.onGradient.body14,
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          Text(
            AppZh.companionDamageAssumptions,
            style: SecondaryTypography.onGradient.small12.copyWith(
              color: TitoColors.skyBlue,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
