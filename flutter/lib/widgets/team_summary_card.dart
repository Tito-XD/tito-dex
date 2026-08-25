import 'package:flutter/material.dart';

import '../features/companion/battle_game_scope.dart';
import '../features/companion/battle_tools_service.dart';
import '../features/dex/battle_effectiveness.dart';
import '../features/dex/dex_models.dart';
import '../features/game/game_edition_repository.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'sticker_card.dart';

class TeamSummaryCard extends StatefulWidget {
  const TeamSummaryCard({
    super.key,
    required this.party,
    required this.detailsFuture,
  });

  final List<PartyMember> party;
  final Future<Map<int, PokemonDetail>> detailsFuture;

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
    _load();
  }

  @override
  void didUpdateWidget(TeamSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_partyListsEqual(oldWidget.party, widget.party) ||
        oldWidget.detailsFuture != widget.detailsFuture) {
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
      final data = await _computeSummary(widget.party, details);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body14 = SecondaryTypography.onCard.body14;

    return ListenableBuilder(
      listenable: gameEditionRepository,
      builder: (context, _) {
        return StickerCard(
          variant: StickerVariant.cream,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppZh.teamSummaryTitle,
                style: SecondaryTypography.onCard.h15,
              ),
              const SizedBox(height: 8),
              if (widget.party.isEmpty)
                Text(
                  AppZh.teamEmptySlot,
                  style: body14.copyWith(color: TitoColors.mutedInk),
                )
              else if (_loading && _data == null)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_data != null) ...[
                Text(AppZh.teamSummaryAvgLevel(_data!.avgLevel), style: body14),
                const SizedBox(height: 4),
                Text(AppZh.teamSummaryBstSum(_data!.bstSum), style: body14),
                const SizedBox(height: 4),
                Text(
                  AppZh.teamSummaryTypeCoverage(_data!.typeCoverage),
                  style: body14,
                ),
                if (_data!.weaknessLine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _data!.weaknessLine,
                    style: body14.copyWith(color: TitoColors.mutedInk),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (_data!.sharedWeaknessLine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _data!.sharedWeaknessLine,
                    style: body14.copyWith(color: TitoColors.mutedInk),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TeamSummaryData {
  const _TeamSummaryData({
    required this.avgLevel,
    required this.bstSum,
    required this.typeCoverage,
    required this.weaknessLine,
    required this.sharedWeaknessLine,
  });

  final double avgLevel;
  final int bstSum;
  final int typeCoverage;
  final String weaknessLine;
  final String sharedWeaknessLine;
}

Future<_TeamSummaryData> _computeSummary(
  List<PartyMember> party,
  Map<int, PokemonDetail> details,
) async {
  final levels = <int>[];
  var bstSum = 0;
  final types = <String>{};
  final weaknessCounts = <String, int>{};
  final memberTypes = <List<String>>[];
  final relations = await battleToolsService.loadTypeRelations();
  final generation = battleScopeForEdition(
    gameEditionRepository.edition,
  ).generation;

  for (final member in party) {
    final id = member.speciesId;
    if (id == null) {
      continue;
    }
    if (member.level != null) {
      levels.add(member.level!);
    }

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

  String weaknessLine = '';
  if (weaknessCounts.isNotEmpty) {
    final sorted = weaknessCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(3).map((entry) => entry.key).join('、');
    weaknessLine = AppZh.teamSummaryWeaknesses(top);
  }

  final shared = computeTeamSharedWeaknesses(
    memberTypes,
    relations,
    generation: generation,
  );
  final sharedWeaknessLine = shared.isEmpty
      ? ''
      : AppZh.teamSummarySharedWeaknesses(shared.join('、'));

  return _TeamSummaryData(
    avgLevel: avgLevel,
    bstSum: bstSum,
    typeCoverage: types.length,
    weaknessLine: weaknessLine,
    sharedWeaknessLine: sharedWeaknessLine,
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
