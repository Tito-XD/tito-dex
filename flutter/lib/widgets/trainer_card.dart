import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/tito_colors.dart';
import 'sticker_card.dart';

class TrainerCard extends StatelessWidget {
  const TrainerCard({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: TitoColors.softYellow,
              shape: BoxShape.circle,
              border: Border.all(color: TitoColors.ink, width: 3),
            ),
            alignment: Alignment.center,
            child: const Text('🐾', style: TextStyle(fontSize: 32)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppZh.trainerCard.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: TitoColors.mutedInk,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  journey.trainerName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                ),
                Text(
                  AppZh.journeySince2026,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: TitoColors.mutedInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  localizeGame(journey.game),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: TitoColors.mutedInk,
                  ),
                ),
                Text(
                  '${AppZh.companion} · ${localizeCompanion(journey.companion)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: TitoColors.mutedInk,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var index = 0; index < journey.maxBadges; index++)
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < journey.badges
                              ? TitoColors.softYellow
                              : TitoColors.skyBlue,
                          border: Border.all(color: TitoColors.ink, width: 2),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
