import 'package:flutter/material.dart';

import '../features/companion/battle_team_analysis.dart';
import '../features/companion/battle_session.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import 'sticker_card.dart';
import 'type_badge.dart';

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
  Widget _group(String title, Map<String, int> counts) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SecondaryTypography.onGradient.small12),
        const SizedBox(height: 5),
        if (counts.isEmpty)
          Text(AppZh.dexNone, style: SecondaryTypography.onGradient.small12)
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
                    Text(
                      ' ×${entry.value}',
                      style: SecondaryTypography.onGradient.small12,
                    ),
                  ],
                ),
            ],
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => StickerCard(
    variant: StickerVariant.deep,
    padding: const EdgeInsets.all(12),
    child: FutureBuilder<List<BattlePartyEntry>>(
      future: widget.session.partyEntries(widget.party),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
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
              style: SecondaryTypography.onGradient.h15,
            ),
            if (members.length != entries.length) ...[
              Text(
                AppZh.battleTeamIncomplete,
                style: SecondaryTypography.onGradient.small12,
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: SecondaryTypography.onGradient.h15.color,
                ),
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
                style: SecondaryTypography.onGradient.small12,
              ),
            if (members.isEmpty)
              Text(
                AppZh.battlePartyEmpty,
                style: SecondaryTypography.onGradient.body14,
              )
            else ...[
              _group(AppZh.battleTeamWeaknesses, analysis.sharedWeaknesses),
              _group(AppZh.battleTeamResistances, analysis.resistances),
              _group(AppZh.battleTeamImmunities, analysis.immunities),
              const SizedBox(height: 10),
              Text(
                AppZh.companionOffensiveBlindSpots,
                style: SecondaryTypography.onGradient.small12,
              ),
              const SizedBox(height: 5),
              if (analysis.offensiveBlindSpots.isEmpty)
                Text(
                  AppZh.dexNone,
                  style: SecondaryTypography.onGradient.small12,
                )
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
