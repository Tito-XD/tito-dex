import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/tito_colors.dart';
import 'sticker_card.dart';

class JourneyTimeline extends StatelessWidget {
  const JourneyTimeline({
    super.key,
    required this.entries,
    this.nextReminder,
  });

  final List<JourneyTimelineEntry> entries;
  final String? nextReminder;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.recentTimeline,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text(
              AppZh.journeyTimelineEmpty,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: TitoColors.mutedInk,
                  ),
            )
          else
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizeTimelineEntry(entry.text),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (entry.at != null)
                            Text(
                              entry.at!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: TitoColors.mutedInk,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
