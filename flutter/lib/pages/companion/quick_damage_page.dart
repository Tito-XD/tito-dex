import 'package:flutter/material.dart';

import '../../features/companion/battle_game_scope.dart';
import '../../features/companion/battle_math.dart';
import '../../features/companion/battle_tools_service.dart';
import '../../features/dex/dex_models.dart';
import '../../features/dex/dex_repository.dart';
import '../../features/dex/type_chart.dart';
import '../../l10n/app_zh.dart';
import '../../l10n/game_zh.dart';
import '../../models/journey.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import '../../theme/tito_typography.dart';
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
  Map<String, TypeDamageRelations>? _relations;
  String? _error;
  bool _loading = true;
  List<PokemonSummary> _attackerSuggestions = const [];
  List<PokemonSummary> _defenderSuggestions = const [];

  @override
  void initState() {
    super.initState();
    final scope = battleScopeForGame(widget.journey.game);
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
        _error = error.toString();
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
    setState(() {
      _attackerTypes = List<String>.from(summary.types);
      _attackController.text = attackStat.toString();
      _attackerSuggestions = const [];
      _attackerQueryController.text = summary.nameZh;
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
    });
  }

  int _readInt(TextEditingController controller, int fallback) =>
      int.tryParse(controller.text.trim()) ?? fallback;

  @override
  Widget build(BuildContext context) {
    final scope = battleScopeForGame(widget.journey.game);
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
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: SecondaryPageScaffold(
        title: AppZh.companionToolQuickDamage,
        subtitle: localizeGame(widget.journey.game),
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            StickerCard(child: Text(_error!, style: context.tito.errorDetail))
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
                TypeChipPicker(
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
                TypeChipPicker(
                  label: AppZh.companionTypeAttackerPick,
                  selected: _attackerTypes,
                  onChanged: (types) => setState(() => _attackerTypes = types),
                ),
                const SizedBox(height: 12),
                TypeChipPicker(
                  label: AppZh.companionTypeManualPick,
                  selected: _defenderTypes,
                  onChanged: (types) {
                    if (types.isNotEmpty) {
                      setState(() => _defenderTypes = types);
                    }
                  },
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
                      style: context.tito.cardTitle,
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
                        estimate.stabMultiplier == 1.5 ? '1.5' : '1',
                      ),
                      style: SecondaryTypography.onCard.small12.copyWith(
                        color: TitoColors.mutedInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
