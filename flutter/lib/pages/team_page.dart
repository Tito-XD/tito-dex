import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/tito_colors.dart';
import '../widgets/party_summary.dart';
import '../widgets/sticker_card.dart';

class TeamPage extends StatelessWidget {
  const TeamPage({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StickerCard(
          variant: StickerVariant.deep,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppZh.navTeam} · ${localizeGame(journey.game)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: TitoColors.card,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                AppZh.teamSubtitle(journey.party.length),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: TitoColors.skyBlue,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PartySummary(party: journey.party, showSlots: true),
        const SizedBox(height: 16),
        StickerCard(
          variant: StickerVariant.cream,
          child: Text(
            AppZh.teamNote,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}
