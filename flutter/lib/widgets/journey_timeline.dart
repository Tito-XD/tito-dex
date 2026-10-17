import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_skin.dart';
import 'sticker_card.dart';

class JourneyTimeline extends StatelessWidget {
  const JourneyTimeline({super.key, required this.entries, this.nextReminder});

  final List<JourneyTimelineEntry> entries;
  final String? nextReminder;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    final outline = skin.outline;
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppZh.recentTimeline, style: SecondaryTypography.onCard.h15),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text(
              AppZh.journeyTimelineEmpty,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: skin.mutedInk,
              ),
            )
          else
            for (var i = 0; i < entries.length; i++)
              _TimelineEntryTile(
                entry: entries[i],
                isLast: i == entries.length - 1,
              ),
          if (nextReminder != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: skin.isFlat ? skin.chipFill : TitoColors.softYellow,
                borderRadius: BorderRadius.circular(skin.radiusSm),
                border: outline == null
                    ? null
                    : Border.all(
                        color: skin.isPlastic
                            ? skin.ink.withValues(alpha: 0.28)
                            : outline,
                        width: skin.outlineWidth,
                      ),
              ),
              child: Text(
                '${AppZh.nextPrefix}${localizeReminder(nextReminder)}',
                style: SecondaryTypography.onCard.body14.copyWith(
                  fontWeight: FontWeight.w700,
                  color: skin.ink,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineEntryTile extends StatelessWidget {
  const _TimelineEntryTile({required this.entry, required this.isLast});

  final JourneyTimelineEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    final outline = skin.outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: skin.isFlat ? skin.primaryFill : TitoColors.coral,
                    shape: BoxShape.circle,
                    border: outline == null
                        ? null
                        : Border.all(color: outline, width: skin.outlineWidth),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 34,
                    color: outline ?? skin.mutedInk,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.at != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        entry.at!,
                        style: SecondaryTypography.onCard.small12.copyWith(
                          fontWeight: FontWeight.w800,
                          color: skin.mutedInk,
                        ),
                      ),
                    ),
                  Text(
                    localizeTimelineEntry(entry.text),
                    style: SecondaryTypography.onCard.body14.copyWith(
                      fontWeight: FontWeight.w700,
                      color: skin.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
