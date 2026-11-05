import 'package:flutter/material.dart';

import '../features/companion/battle_team_analysis.dart';
import '../features/companion/battle_session.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_surface_tokens.dart';
import '../theme/tito_typography.dart';
import 'battle_tool_panels.dart';
import 'type_badge.dart';
import 'tito_loading_panel.dart';

class BattleTeamPanel extends StatefulWidget {
  const BattleTeamPanel({
    super.key,
    required this.party,
    required this.session,
    required this.relations,
    required this.generation,
  });
  final List<PartyMember> party;
  final BattleSession session;
  final Map<String, TypeDamageRelations> relations;
  final int generation;

  @override
  State<BattleTeamPanel> createState() => _BattleTeamPanelState();
}

class _BattleTeamPanelState extends State<BattleTeamPanel> {
  /// Shared weaknesses on this many members are flagged in the danger colour.
  static const _bigWeakness = 3;

  Widget _group(
    String title,
    Map<String, int> counts, {
    bool flagWeak = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title${AppZh.battleTypeCountSuffix(counts.length)}',
          style: SecondaryTypography.onCard.small12,
        ),
        const SizedBox(height: 5),
        if (counts.isEmpty)
          Text(AppZh.dexNone, style: SecondaryTypography.onCard.small12)
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in counts.entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TitoTypeBadge(typeEn: entry.key, size: TypeBadgeSize.small),
                    const SizedBox(width: 4),
                    _CountBadge(
                      key: ValueKey('team-count-${entry.key}'),
                      count: entry.value,
                      danger: flagWeak && entry.value >= _bigWeakness,
                    ),
                  ],
                ),
            ],
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => BattleResultCard(
    child: FutureBuilder<List<BattlePartyEntry>>(
      future: widget.session.partyEntries(widget.party),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const TitoInlineLoading(height: 64);
        }
        final entries = snapshot.data!;
        final members = [
          for (final entry in entries)
            if (!entry.combatant.selectionFailed &&
                entry.combatant.types.isNotEmpty)
              BattleTeamMember(
                name: entry.name,
                types: entry.combatant.types,
                abilitySlug: entry.combatant.abilitySlug,
              ),
        ];
        final analysis = BattleTeamAnalysis(
          members,
          widget.relations,
          generation: widget.generation,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppZh.battleTeamAnalysis} · ${members.length}/${entries.length}',
              style: BattleResultText.title,
            ),
            if (members.length != entries.length) ...[
              Text(
                AppZh.battleTeamIncomplete,
                style: SecondaryTypography.onCard.small12,
              ),
              TextButton(
                onPressed: () async {
                  for (final entry in entries.where(
                    (e) => e.combatant.selectionFailed,
                  )) {
                    await entry.combatant.selectParty(entry.member);
                  }
                },
                child: Text(AppZh.dexRetry),
              ),
            ],
            if (members.any((m) => m.abilitySlug == null))
              Text(
                AppZh.battleTeamUnknownAbility,
                style: SecondaryTypography.onCard.small12,
              ),
            if (members.isEmpty)
              Text(
                AppZh.battlePartyEmpty,
                style: SecondaryTypography.onCard.body14,
              )
            else ...[
              _group(
                AppZh.battleTeamWeaknesses,
                analysis.sharedWeaknesses,
                flagWeak: true,
              ),
              _group(AppZh.battleTeamResistances, analysis.resistances),
              _group(AppZh.battleTeamImmunities, analysis.immunities),
              const SizedBox(height: 10),
              Text(
                AppZh.companionOffensiveBlindSpots,
                style: SecondaryTypography.onCard.small12,
              ),
              const SizedBox(height: 5),
              if (analysis.offensiveBlindSpots.isEmpty)
                Text(AppZh.dexNone, style: SecondaryTypography.onCard.small12)
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final type in analysis.offensiveBlindSpots)
                      TitoTypeBadge(typeEn: type, size: TypeBadgeSize.small),
                  ],
                ),
            ],
          ],
        );
      },
    ),
  );
}

/// Member count after a type badge. [danger] marks a weakness shared by
/// enough members to need attention.
class _CountBadge extends StatelessWidget {
  const _CountBadge({super.key, required this.count, this.danger = false});

  final int count;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final outline = TitoSurfaceTokens.of(context).elementOutline;
    final color = danger ? typeMultiplierColor(2) : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.fromBorderSide(
          color == null ? outline : outline.copyWith(color: color),
        ),
      ),
      child: Text(
        '×$count',
        style: SecondaryTypography.onCard.small12.copyWith(
          fontWeight: TitoTypography.weight(FontWeight.w800),
          color: color,
        ),
      ),
    );
  }
}
