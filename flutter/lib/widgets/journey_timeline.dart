import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
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
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        localizeTimelineEntry(entry.text),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (entry.at != null)
                      Text(
                        entry.at!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
          if (nextReminder != null) ...[
            const SizedBox(height: 8),
            Text(
              '${AppZh.nextPrefix}${localizeReminder(nextReminder)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}
