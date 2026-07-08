import 'package:flutter/material.dart';

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
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: TitoColors.softYellow,
              borderRadius: BorderRadius.circular(TitoRadii.md),
              border: Border.all(color: TitoColors.ink, width: 2),
            ),
            alignment: Alignment.center,
            child: const Text('🐾', style: TextStyle(fontSize: 32)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trainer Card',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: TitoColors.mutedInk,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  journey.trainerName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  journey.game,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text('Companion: ${journey.companion}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var index = 0; index < journey.maxBadges; index++)
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < journey.badges
                              ? TitoColors.coral
                              : TitoColors.skyBlue,
                          border: Border.all(color: TitoColors.ink, width: 1.5),
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
