import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import 'sticker_card.dart';

class TrainerCard extends StatelessWidget {
  const TrainerCard({
    super.key,
    required this.journey,
    this.compact = false,
  });

  final CurrentJourney journey;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final avatarSize = compact ? 52.0 : 72.0;
    final padding = compact ? DeviceLayout.cardPadding(context) : null;

    return StickerCard(
      padding: padding ?? const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              color: TitoColors.softYellow,
              shape: BoxShape.circle,
              border: Border.all(color: TitoColors.ink, width: 3),
            ),
            alignment: Alignment.center,
            child: Text(
              '🐾',
              style: TextStyle(fontSize: compact ? 24 : 32),
            ),
          ),
          SizedBox(width: compact ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppZh.trainerCard.toUpperCase(),
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
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
                        fontSize: compact ? 18 : null,
                      ),
                ),
                if (!compact) ...[
                  Text(
                    AppZh.journeySince2026,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TitoColors.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  localizeGame(journey.game),
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    color: TitoColors.mutedInk,
                  ),
                ),
                if (!compact)
                  Text(
                    '${AppZh.companion} · ${localizeCompanion(journey.companion)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: TitoColors.mutedInk,
                    ),
                  ),
                SizedBox(height: compact ? 6 : 10),
                Row(
                  children: [
                    for (var index = 0; index < journey.maxBadges; index++)
                      Container(
                        width: compact ? 12 : 14,
                        height: compact ? 12 : 14,
                        margin: EdgeInsets.only(right: compact ? 4 : 6),
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
