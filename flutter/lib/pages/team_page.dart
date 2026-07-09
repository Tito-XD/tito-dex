import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_typography.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/party_summary.dart';
import '../widgets/sticker_card.dart';

class TeamPage extends StatelessWidget {
  const TeamPage({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      title: AppZh.navTeam,
      padding: DeviceLayout.pagePadding(context),
      children: [
        StickerCard(
          variant: StickerVariant.deep,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppZh.navTeam} · ${localizeGame(journey.game)}',
                style: context.tito.onDeepTitle,
              ),
              const SizedBox(height: 4),
              Text(
                AppZh.teamSubtitle(journey.party.length),
                style: context.tito.onDeepSubtitle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PartySummary(party: journey.party, showSlots: true),
        const SizedBox(height: 14),
        StickerCard(
          variant: StickerVariant.cream,
          child: Text(AppZh.teamNote, style: context.tito.cardBodyStrong),
        ),
      ],
    );
  }
}
