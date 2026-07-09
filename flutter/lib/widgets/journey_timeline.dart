import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'sticker_card.dart';

class JourneyTimeline extends StatelessWidget {
  const JourneyTimeline({super.key, required this.entries, this.nextReminder});

  final List<JourneyTimelineEntry> entries;
  final String? nextReminder;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppZh.recentTimeline, style: context.tito.cardTitle),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text(AppZh.journeyTimelineEmpty, style: context.tito.cardMuted)
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
                color: TitoColors.softYellow,
                borderRadius: BorderRadius.circular(TitoRadii.sm),
                border: Border.all(color: TitoColors.ink, width: 2),
              ),
              child: Text(
                '${AppZh.nextPrefix}${localizeReminder(nextReminder)}',
                style: context.tito.cardBodyStrong,
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
                    color: TitoColors.coral,
                    shape: BoxShape.circle,
                    border: Border.all(color: TitoColors.ink, width: 2),
                  ),
                ),
                if (!isLast)
                  Container(width: 2, height: 34, color: TitoColors.slateBlue),
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
                      child: Text(entry.at!, style: context.tito.captionStrong),
                    ),
                  Text(
                    localizeTimelineEntry(entry.text),
                    style: context.tito.cardBodyStrong,
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
