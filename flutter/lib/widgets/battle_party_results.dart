import '../features/companion/battle_move_rules.dart';
import '../l10n/app_locale.dart';
import '../features/dex/dex_models.dart';
import '../features/companion/battle_learnset.dart';
import '../features/game/game_edition_repository.dart';
import 'package:flutter/material.dart';

import '../features/companion/battle_math.dart';
import '../features/companion/battle_party_damage.dart';
import '../features/companion/battle_session.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../l10n/localized_names.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import 'sticker_card.dart';

class BattlePartyResults extends StatelessWidget {
  const BattlePartyResults({
    super.key,
    required this.session,
    required this.party,
    this.relations,
    this.generation = 9,
    this.weatherSlug,
    this.terrainSlug,
    this.critical = false,
    this.screened = false,
    this.spread = false,
    this.compact = false,
  });

  final BattleSession session;
  final List<PartyMember> party;

  /// Null selects the six-stat comparison.
  final Map<String, TypeDamageRelations>? relations;
  final int generation;
  final String? weatherSlug;
  final String? terrainSlug;
  final bool critical;
  final bool screened;
  final bool spread;
  final bool compact;

  List<CachedMove> _legalMoves(BattlePartyEntry entry) {
    final legal = {
      for (final m in battleLearnset(
        entry.combatant.detail,
        gameEditionRepository.edition.dataVersionGroupKey,
      ))
        m.id: m,
    };
    return [
      for (final id in entry.moves.keys)
        if (legal.containsKey(id)) legal[id]!,
    ];
  }

  Widget _compactResult() => FutureBuilder<List<BattlePartyEntry>>(
    future: session.partyEntries(party),
    builder: (context, snapshot) {
      DamageEstimate? best;
      String? bestName;
      for (final entry in snapshot.data ?? <BattlePartyEntry>[]) {
        for (final move in _legalMoves(entry)) {
          final value = estimatePartyMove(
            attacker: entry.combatant,
            defender: session.defender,
            move: move,
            relations: relations!,
            generation: generation,
            weatherSlug: weatherSlug,
            terrainSlug: terrainSlug,
            critical: critical,
            screened: screened,
            spread: spread,
          );
          if (value != null &&
              (best == null || value.maxDamage > best.maxDamage)) {
            best = value;
            bestName = '${entry.name} · ${move.displayName}';
          }
        }
      }
      return Text(
        best == null
            ? AppZh.battleTeamSummary(session.teamCount(party))
            : '$bestName · ${best.minPercent.toStringAsFixed(1)}–${best.maxPercent.toStringAsFixed(1)}%',
      );
    },
  );

  @override
  Widget build(BuildContext context) => compact
      ? _compactResult()
      : StickerCard(
          padding: const EdgeInsets.all(12),
          child: DefaultTextStyle(
            style: SecondaryTypography.onCard.small12,
            child: FutureBuilder<List<BattlePartyEntry>>(
              future: session.partyEntries(party),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final entries = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      relations == null
                          ? AppZh.battleTeamStats
                          : AppZh.battleTeamDamage,
                      style: SecondaryTypography.onCard.h15,
                    ),
                    const SizedBox(height: 6),
                    if (entries.isEmpty)
                      Text(AppZh.battlePartyEmpty)
                    else if (relations == null)
                      _stats(entries)
                    else ...[
                      for (final entry in entries) _damage(entry),
                    ],
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      minTileHeight: 44,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: Text(
                        entries.any((e) => e.combatant.partyDefaults)
                            ? AppLocale.pick(
                                zh: '计算说明 · 含默认配置',
                                en: 'Notes · includes defaults',
                              )
                            : AppLocale.pick(
                                zh: '计算说明',
                                en: 'Calculation notes',
                              ),
                        style: SecondaryTypography.onCard.small12,
                      ),
                      children: [
                        Text(
                          relations == null
                              ? AppZh.battleTeamStatsHint
                              : AppZh.battleTeamDamageHint,
                        ),
                        if (entries.any((e) => e.combatant.selectionFailed))
                          Text(AppZh.battleTeamMemberFailed),
                        if (entries.any((e) => e.combatant.partyDefaults))
                          Text(AppZh.battlePartyDefaults),
                        if (entries.any((e) => e.combatant.unsupportedItem))
                          Text(AppZh.battleTeamItemsExcluded),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );

  Widget _stats(List<BattlePartyEntry> entries) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Table(
      defaultColumnWidth: const FixedColumnWidth(44),
      columnWidths: const {0: FixedColumnWidth(84)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _cell(''),
            for (final stat in BattleStat.values) _cell(stat.label),
          ],
        ),
        for (final entry in entries)
          TableRow(
            children: [
              _cell(entry.name),
              for (final stat in BattleStat.values)
                _cell(
                  entry.combatant.selectionFailed
                      ? '—'
                      : '${entry.combatant.effectiveStat(stat, generation: generation)}',
                ),
            ],
          ),
      ],
    ),
  );

  Widget _cell(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
    child: Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );

  Widget _damage(BattlePartyEntry entry) {
    final name = entry.name;
    if (entry.combatant.selectionFailed || _legalMoves(entry).isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '$name · ${entry.combatant.selectionFailed ? AppZh.battleTeamMemberFailed : AppZh.battleTeamNoMoves}',
        ),
      );
    }
    final results =
        [
          for (final move in _legalMoves(entry).map((m) => MapEntry(m.id, m)))
            (
              move: move.value,
              id: move.key,
              estimate: estimatePartyMove(
                attacker: entry.combatant,
                defender: session.defender,
                move: move.value,
                relations: relations!,
                generation: generation,
                weatherSlug: weatherSlug,
                terrainSlug: terrainSlug,
                critical: critical,
                screened: screened,
                spread: spread,
              ),
            ),
        ]..sort(
          (a, b) => (b.estimate?.maxDamage ?? -1).compareTo(
            a.estimate?.maxDamage ?? -1,
          ),
        );
    final best = results.first;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      shape: const Border(),
      collapsedShape: const Border(),
      textColor: SecondaryTypography.onCard.h15.color,
      collapsedTextColor: SecondaryTypography.onCard.h15.color,
      iconColor: SecondaryTypography.onCard.h15.color,
      collapsedIconColor: SecondaryTypography.onCard.h15.color,
      title: Text(name, style: SecondaryTypography.onCard.body14),
      subtitle: Text(
        best.estimate == null
            ? battleMoveIssue(
                    entry.combatant,
                    session.defender,
                    best.move,
                    generation,
                  ) ??
                  AppZh.battleTeamMoveUnsupported
            : '${best.move.displayName} · ${_range(best.estimate!)}',
        style: SecondaryTypography.onCard.small12,
      ),
      children: [
        for (final row in results)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${row.move.displayName} · ${row.estimate == null ? battleMoveIssue(entry.combatant, session.defender, row.move, generation) ?? AppZh.battleTeamMoveUnsupported : _range(row.estimate!)}',
              ),
            ),
          ),
      ],
    );
  }

  String _range(DamageEstimate value) =>
      '${value.minDamage}–${value.maxDamage} / ${value.minPercent.toStringAsFixed(1)}–${value.maxPercent.toStringAsFixed(1)}%';
}
