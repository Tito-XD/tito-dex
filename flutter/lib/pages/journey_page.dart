import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/tito_typography.dart';
import '../widgets/app_header.dart';
import '../widgets/journey_timeline.dart';
import '../widgets/sticker_card.dart';

class JourneyPage extends StatelessWidget {
  const JourneyPage({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      children: [
        const AppHeader(showSettings: true),
        StickerCard(
          variant: StickerVariant.deep,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppZh.navJourney,
                style: context.tito.onDeepTitle,
              ),
              const SizedBox(height: 4),
              Text(
                localizeLocation(journey.location),
                style: context.tito.onDeepHeading,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        JourneyTimeline(
          entries: journey.timeline,
          nextReminder: journey.nextReminder,
        ),
        const SizedBox(height: 14),
        StickerCard(
          child: Column(
            children: [
              _StatRow(
                label: AppZh.settingsLocation,
                value: localizeLocation(journey.location),
              ),
              _StatRow(
                label: AppZh.settingsPlayTime,
                value: journey.playTime,
              ),
              _StatRow(
                label: AppZh.settingsBadges,
                value: '${journey.badges}/${journey.maxBadges}',
              ),
              _StatRow(
                label: AppZh.settingsCurrentGame,
                value: localizeGame(journey.game),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.tito.cardLabel),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.tito.cardValue,
            ),
          ),
        ],
      ),
    );
  }
}
