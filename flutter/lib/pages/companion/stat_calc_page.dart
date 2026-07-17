import 'package:flutter/material.dart';

import '../../features/companion/battle_game_scope.dart';
import '../../features/companion/battle_math.dart';
import '../../features/dex/battle_effectiveness.dart';
import '../../features/dex/dex_models.dart';
import '../../features/dex/dex_repository.dart';
import '../../features/game/game_edition_repository.dart';
import '../../l10n/app_zh.dart';
import '../../models/journey.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import '../../theme/tito_font_scale.dart';
import '../../widgets/companion_tool_fields.dart';
import '../../widgets/secondary_page_scaffold.dart';
import '../../widgets/sticker_card.dart';

class StatCalcPage extends StatefulWidget {
  const StatCalcPage({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  State<StatCalcPage> createState() => _StatCalcPageState();
}

class _StatCalcPageState extends State<StatCalcPage> {
  final _queryController = TextEditingController();
  final _baseController = TextEditingController(text: '100');
  final _levelController = TextEditingController(text: '50');
  final _ivController = TextEditingController(text: '31');
  final _evController = TextEditingController(text: '0');

  BattleStat _stat = BattleStat.attack;
  NatureModifier _nature = battleNatures.firstWhere((n) => n.key == 'serious');
  String? _attackerAbilitySlug;
  int? _linkedPokemonId;
  List<DefensiveAbilityOption> _abilityOptions = const [];
  BattleHeldItem _heldItem = BattleHeldItem.none;
  BattleStatusCondition _status = BattleStatusCondition.none;
  List<PokemonSummary> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    final scope = battleScopeForEdition(gameEditionRepository.edition);
    _levelController.text = scope.defaultLevel.toString();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _baseController.dispose();
    _levelController.dispose();
    _ivController.dispose();
    _evController.dispose();
    super.dispose();
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

  Future<void> _applyPokemon(PokemonSummary summary) async {
    final detail = await dexRepository.getDetail(summary.id);
    final stats = detail.baseStats;
    if (stats == null) {
      return;
    }
    final base = switch (_stat) {
      BattleStat.hp => stats.hp,
      BattleStat.attack => stats.attack,
      BattleStat.defense => stats.defense,
      BattleStat.specialAttack => stats.specialAttack,
      BattleStat.specialDefense => stats.specialDefense,
      BattleStat.speed => stats.speed,
    };
    if (!mounted) {
      return;
    }
    setState(() {
      _baseController.text = base.toString();
      _suggestions = const [];
      _queryController.text = summary.nameZh;
      _linkedPokemonId = summary.id;
      _abilityOptions = const [];
      _attackerAbilitySlug = null;
    });
    _loadAbilities(summary.id);
  }

  void _clearLinkedPokemon() {
    setState(() {
      _linkedPokemonId = null;
      _abilityOptions = const [];
      _attackerAbilitySlug = null;
    });
  }

  Future<void> _loadAbilities(int pokemonId) async {
    try {
      final abilities = await dexRepository.abilitiesForPokemon(pokemonId);
      if (!mounted || _linkedPokemonId != pokemonId) {
        return;
      }
      final options = statAbilityOptionsFromPokemon(abilities);
      setState(() {
        _abilityOptions = options;
        _attackerAbilitySlug = defaultAbilitySlugForOptions(options);
      });
    } catch (_) {}
  }

  Future<void> _refreshBaseFromLinked() async {
    final id = _linkedPokemonId;
    if (id == null) {
      return;
    }
    final detail = await dexRepository.getDetail(id);
    final stats = detail.baseStats;
    if (stats == null || !mounted) {
      return;
    }
    final base = switch (_stat) {
      BattleStat.hp => stats.hp,
      BattleStat.attack => stats.attack,
      BattleStat.defense => stats.defense,
      BattleStat.specialAttack => stats.specialAttack,
      BattleStat.specialDefense => stats.specialDefense,
      BattleStat.speed => stats.speed,
    };
    setState(() => _baseController.text = base.toString());
  }

  int _readBase() => int.tryParse(_baseController.text.trim()) ?? 0;

  int _readLevel() {
    final scope = battleScopeForEdition(gameEditionRepository.edition);
    return int.tryParse(_levelController.text.trim()) ?? scope.defaultLevel;
  }

  int _readIv() => int.tryParse(_ivController.text.trim()) ?? 31;

  int _readEv() => int.tryParse(_evController.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gameEditionRepository,
      builder: (context, _) {
        final edition = gameEditionRepository.edition;
        final scope = battleScopeForEdition(edition);
        final result = computeBattleStat(
          stat: _stat,
          base: _readBase(),
          level: _readLevel(),
          iv: _readIv(),
          ev: _readEv(),
          nature: _nature,
          attackerAbilitySlug: _attackerAbilitySlug,
          isPhysicalStat: _stat == BattleStat.attack,
          heldItem: _heldItem,
          status: _status,
        );

        return TitoFontScale(
          multiplier: 1.0,
          child: Material(
            type: MaterialType.transparency,
            child: SecondaryPageScaffold(
              title: AppZh.companionToolStatCalc,
              subtitle: edition.labelZh,
              children: [
          CompanionSectionCard(
            title: AppZh.companionStatInputsTitle,
            subtitle: AppZh.companionStatFacilityNote(scope.facilityLabel),
            children: [
              PokemonSearchField(
                controller: _queryController,
                hintText: AppZh.companionPokemonSearchHint,
                suggestions: _suggestions,
                onQueryChanged: _searchPokemon,
                onPokemonSelected: _applyPokemon,
              ),
              const SizedBox(height: 12),
              StatPicker(
                selected: _stat,
                onChanged: (value) {
                  setState(() => _stat = value);
                  _refreshBaseFromLinked();
                },
              ),
              const SizedBox(height: 12),
              NaturePicker(
                selected: _nature,
                onChanged: (value) => setState(() => _nature = value),
              ),
              const SizedBox(height: 12),
              CompanionNumberField(
                label: AppZh.companionStatBase,
                controller: _baseController,
                max: 255,
                onChanged: (_) {
                  setState(() {});
                  _clearLinkedPokemon();
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
              Row(
                children: [
                  Expanded(
                    child: CompanionNumberField(
                      label: AppZh.companionStatIv,
                      controller: _ivController,
                      max: 31,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CompanionNumberField(
                      label: AppZh.companionStatEv,
                      controller: _evController,
                      max: 252,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              if (_abilityOptions.isNotEmpty || _linkedPokemonId == null) ...[
                const SizedBox(height: 12),
                CompanionAbilitySection(
                  pokemonLabel: AppZh.companionAttackerAbilityPick,
                  manualLabel: AppZh.companionAttackerAbilityPick,
                  manualOptions: kManualAttackerAbilityOptions,
                  pokemonOptions: _abilityOptions,
                  linkedPokemonId: _linkedPokemonId,
                  selectedSlug: _attackerAbilitySlug,
                  onChanged: (slug) =>
                      setState(() => _attackerAbilitySlug = slug),
                ),
              ],
              const SizedBox(height: 12),
              HeldItemPicker(
                selected: _heldItem,
                onChanged: (value) => setState(() => _heldItem = value),
              ),
              const SizedBox(height: 12),
              StatusConditionPicker(
                selected: _status,
                onChanged: (value) => setState(() => _status = value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StickerCard(
            variant: StickerVariant.mint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppZh.companionStatResultTitle,
                  style: SecondaryTypography.onCard.h15,
                ),
                const SizedBox(height: 8),
                Text(
                  '${_stat.labelZh}：$result',
                  style: SecondaryTypography.onCard.h15.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppZh.companionStatResultHint,
                  style: SecondaryTypography.onCard.small12.copyWith(
                    color: TitoColors.mutedInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
            ),
          ),
        );
      },
    );
  }
}
