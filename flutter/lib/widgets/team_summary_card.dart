import 'package:flutter/material.dart';

import '../features/companion/battle_game_scope.dart';
import '../features/companion/battle_tools_service.dart';
import '../features/dex/battle_effectiveness.dart';
import '../features/dex/dex_models.dart';
import '../features/game/game_edition_repository.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../features/dex/type_chart.dart';
import 'tito_fact_grid.dart';
import 'type_badge.dart';
import 'sticker_card.dart';
import 'tito_skeleton.dart';

class TeamSummaryCard extends StatefulWidget {
  const TeamSummaryCard({
    super.key,
    required this.party,
    required this.detailsFuture,
    this.typeRelationsFuture,
  });

  final List<PartyMember> party;
  final Future<Map<int, PokemonDetail>> detailsFuture;
  final Future<Map<String, TypeDamageRelations>>? typeRelationsFuture;

  @override
  State<TeamSummaryCard> createState() => _TeamSummaryCardState();
}

class _TeamSummaryCardState extends State<TeamSummaryCard> {
  _TeamSummaryData? _data;
  bool _loading = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    gameEditionRepository.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(TeamSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_partyListsEqual(oldWidget.party, widget.party) ||
        oldWidget.detailsFuture != widget.detailsFuture ||
        oldWidget.typeRelationsFuture != widget.typeRelationsFuture) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (widget.party.isEmpty) {
      setState(() => _data = null);
      return;
    }

    setState(() => _loading = true);
    try {
      final details = await widget.detailsFuture;
      final data = await _computeSummary(
        widget.party,
        details,
        widget.typeRelationsFuture,
      );
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    gameEditionRepository.removeListener(_load);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return StickerCard(
      key: const Key('team-summary-header'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${AppZh.navTeam} · ${gameEditionRepository.edition.selectedLabel}',
                  style: SecondaryTypography.onCard.h15,
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.groups_rounded, size: 16),
                  const SizedBox(width: 5),
                  Text(
                    AppZh.teamSubtitle(widget.party.length),
                    style: SecondaryTypography.onCard.small12,
                  ),
                ],
              ),
            ],
          ),
          if (widget.party.isEmpty)
            Text(AppZh.teamEmptySlot, style: SecondaryTypography.onCard.small12)
          else if (_loading && data == null) ...[
            const SizedBox(height: 8),
            const TitoFactGrid(
              columns: 3,
              children: [
                TitoSkeletonBox(height: 60, width: double.infinity),
                TitoSkeletonBox(height: 60, width: double.infinity),
                TitoSkeletonBox(height: 60, width: double.infinity),
              ],
            ),
          ] else if (data != null) ...[
            const SizedBox(height: 10),
            TitoFactGrid(
              key: const Key('team-summary-stats'),
              columns: 3,
              children: [
                TitoFactTile(
                  icon: Icons.trending_up_rounded,
                  title: AppZh.teamAverageLevel,
                  child: Text(data.avgLevel.toStringAsFixed(1)),
                ),
                TitoFactTile(
                  icon: Icons.bar_chart_rounded,
                  title: AppZh.teamBaseStatTotal,
                  child: Text('${data.bstSum}'),
                ),
                TitoFactTile(
                  icon: Icons.category_rounded,
                  title: AppZh.teamTypeCoverage,
                  child: Text('${data.typeCoverage}/18'),
                ),
              ],
            ),
            if (data.weaknesses.isNotEmpty ||
                data.sharedWeaknesses.isNotEmpty) ...[
              const SizedBox(height: 8),
              TitoFactGrid(
                children: [
                  TitoFactTile(
                    title: AppZh.teamCommonWeaknesses,
                    child: _WeaknessTypes(types: data.weaknesses),
                  ),
                  TitoFactTile(
                    title: AppZh.teamSharedWeaknesses,
                    child: _WeaknessTypes(types: data.sharedWeaknesses),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _WeaknessTypes extends StatelessWidget {
  const _WeaknessTypes({required this.types});
  final List<String> types;

  @override
  Widget build(BuildContext context) => types.isEmpty
      ? const Text('—')
      : Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final type in types)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: typeTileColor(
                        typeEnForZh(type) ?? type.toLowerCase(),
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: TypeIconImage(
                      typeEn: typeEnForZh(type) ?? type.toLowerCase(),
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    typeNameZh(typeEnForZh(type) ?? type.toLowerCase()),
                    style: SecondaryTypography.onCard.small12,
                  ),
                ],
              ),
          ],
        );
}

class _TeamSummaryData {
  const _TeamSummaryData({
    required this.avgLevel,
    required this.bstSum,
    required this.typeCoverage,
    required this.weaknesses,
    required this.sharedWeaknesses,
  });

  final double avgLevel;
  final int bstSum;
  final int typeCoverage;
  final List<String> weaknesses;
  final List<String> sharedWeaknesses;
}

Future<_TeamSummaryData> _computeSummary(
  List<PartyMember> party,
  Map<int, PokemonDetail> details,
  Future<Map<String, TypeDamageRelations>>? typeRelationsFuture,
) async {
  final levels = <int>[];
  var bstSum = 0;
  final types = <String>{};
  final weaknessCounts = <String, int>{};
  final memberTypes = <List<String>>[];
  final relations = typeRelationsFuture != null
      ? await typeRelationsFuture
      : details.isEmpty
      ? const <String, TypeDamageRelations>{}
      : await battleToolsService.loadTypeRelations();
  final generation = battleScopeForEdition(
    gameEditionRepository.edition,
  ).generation;

  for (final member in party) {
    final id = member.speciesId;
    if (member.level != null) levels.add(member.level!);
    if (id == null) continue;

    final detail = details[id];
    if (detail == null) continue;
    final summary = detail.summary;
    types.addAll(summary.types);
    memberTypes.add(summary.types);

    bstSum += detail.baseStats?.total ?? 0;

    final input = BattleEffectivenessInput(
      defenderTypes: summary.types,
      relationsByType: relations,
      generation: generation,
    );
    for (final weakness in computeBattleDefensiveProfile(input).weaknesses) {
      weaknessCounts[weakness] = (weaknessCounts[weakness] ?? 0) + 1;
    }
  }

  final avgLevel = levels.isEmpty
      ? 0.0
      : levels.reduce((a, b) => a + b) / levels.length;

  final sorted = weaknessCounts.entries.toList()
    ..sort((a, b) {
      final count = b.value.compareTo(a.value);
      return count == 0 ? a.key.compareTo(b.key) : count;
    });
  final weaknesses = sorted.take(3).map((entry) => entry.key).toList();

  final shared = computeTeamSharedWeaknesses(
    memberTypes,
    relations,
    generation: generation,
  );
  return _TeamSummaryData(
    avgLevel: avgLevel,
    bstSum: bstSum,
    typeCoverage: types.length,
    weaknesses: weaknesses,
    sharedWeaknesses: shared,
  );
}

bool _partyListsEqual(List<PartyMember> a, List<PartyMember> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i].speciesId != b[i].speciesId || a[i].level != b[i].level) {
      return false;
    }
  }
  return true;
}
