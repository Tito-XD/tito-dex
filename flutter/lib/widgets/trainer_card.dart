import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'sticker_card.dart';

class TrainerCard extends StatelessWidget {
  const TrainerCard({
    super.key,
    required this.journey,
    this.compact = false,
    this.dense = false,
  });

  final CurrentJourney journey;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final compactMode = compact || dense;
    final avatarSize = dense ? 44.0 : (compact ? 52.0 : 72.0);
    final padding = compactMode ? DeviceLayout.cardPadding(context) : null;

    return StickerCard(
      padding: padding ?? const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [TitoColors.softYellow, TitoColors.coral],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: TitoColors.ink, width: 3),
            ),
            alignment: Alignment.center,
            child: Text(
              journey.trainerName.isNotEmpty
                  ? journey.trainerName[0].toUpperCase()
                  : 'T',
              style: TitoTypography.style(
                fontSize: dense ? 18 : (compact ? 22 : 28),
                fontWeight: FontWeight.w900,
                color: TitoColors.deepBlue,
              ),
            ),
          ),
          SizedBox(width: dense ? 8 : (compact ? 10 : 14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!dense) ...[
                  Text(
                    AppZh.trainerCard.toUpperCase(),
                    style: context.tito.overline,
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  journey.trainerName,
                  style: context.tito.cardValueLarge.copyWith(height: 1.1),
                ),
                if (!compactMode) ...[
                  const SizedBox(height: 4),
                  Text(AppZh.journeySince2026, style: context.tito.caption),
                ],
                SizedBox(height: dense ? 0 : 2),
                Text(
                  localizeGame(journey.game),
                  style: context.tito.captionStrong,
                ),
                if (!compactMode)
                  Text(
                    '${AppZh.companion} · ${localizeCompanion(journey.companion)}',
                    style: context.tito.caption,
                  ),
                SizedBox(height: dense ? 4 : (compact ? 6 : 10)),
                Row(
                  children: [
                    for (var index = 0; index < journey.maxBadges; index++)
                      Container(
                        width: dense ? 10 : (compact ? 12 : 14),
                        height: dense ? 10 : (compact ? 12 : 14),
                        margin: EdgeInsets.only(
                          right: dense ? 3 : (compact ? 4 : 6),
                        ),
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
