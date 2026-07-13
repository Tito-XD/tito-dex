import 'package:flutter/material.dart';

import '../features/companion/battle_tools_service.dart';
import '../features/dex/dex_repository.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'sticker_card.dart';

class TeamSummaryCard extends StatefulWidget {
  const TeamSummaryCard({super.key, required this.party});

  final List<PartyMember> party;

  @override
  State<TeamSummaryCard> createState() => _TeamSummaryCardState();
}

class _TeamSummaryCardState extends State<TeamSummaryCard> {
  _TeamSummaryData? _data;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TeamSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_partyListsEqual(oldWidget.party, widget.party)) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.party.isEmpty) {
      setState(() => _data = null);
      return;
    }

    setState(() => _loading = true);
    try {
      final data = await _computeSummary(widget.party);
      if (!mounted) {
        return;
      }
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body14 = SecondaryTypography.onCard.body14;

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
          ],
        ],
      ),
    );
  }
}

class _TeamSummaryData {
  const _TeamSummaryData({
    required this.avgLevel,
    required this.bstSum,
    required this.typeCoverage,
    required this.weaknessLine,
  });

  final double avgLevel;
  final int bstSum;
  final int typeCoverage;
  final String weaknessLine;
}

Future<_TeamSummaryData> _computeSummary(List<PartyMember> party) async {
  final levels = <int>[];
  var bstSum = 0;
  final types = <String>{};
  final weaknessCounts = <String, int>{};
  final relations = await battleToolsService.loadTypeRelations();

  for (final member in party) {
    final id = member.speciesId;
    if (id == null) {
      continue;
    }
    if (member.level != null) {
      levels.add(member.level!);
    }

    final summary = await dexRepository.getSummary(id);
    types.addAll(summary.types);

    final detail = await dexRepository.getDetail(id);
    bstSum += detail.baseStats?.total ?? 0;

    final profile = computeDefensiveProfile(summary.types, relations);
    for (final weakness in profile.weaknesses) {
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

  return _TeamSummaryData(
    avgLevel: avgLevel,
    bstSum: bstSum,
    typeCoverage: types.length,
    weaknessLine: weaknessLine,
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
