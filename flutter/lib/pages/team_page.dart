import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_font_scale.dart';
import '../widgets/party_team_list.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';

class TeamPage extends StatelessWidget {
  const TeamPage({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  Widget build(BuildContext context) {
    return TitoFontScale(
      multiplier: 1.0,
      child: SecondaryPageScaffold(
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
                style: SecondaryTypography.onGradient.h15,
              ),
              const SizedBox(height: 4),
              Text(
                AppZh.teamSubtitle(journey.party.length),
                style: SecondaryTypography.onGradient.meta14.copyWith(
                  color: TitoColors.skyBlue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PartyTeamList(party: journey.party, showEmptySlots: true),
        const SizedBox(height: 14),
        StickerCard(
          variant: StickerVariant.cream,
          child: Text(
            AppZh.teamNote,
            style: SecondaryTypography.onCard.body14.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
      ),
    );
  }
}
