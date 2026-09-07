import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/app_visual_style.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
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
          Text(AppZh.recentTimeline, style: SecondaryTypography.onCard.h15),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text(
              AppZh.journeyTimelineEmpty,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
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
            _ReminderBox(
              text: '${AppZh.nextPrefix}${localizeReminder(nextReminder)}',
            ),
          ],
        ],
      ),
    );
  }
}

/// Soft-yellow "next step" callout inside the timeline card.
class _ReminderBox extends StatelessWidget {
  const _ReminderBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    final BoxBorder? border;
    if (appVisualStyle.usesFlatUi) {
      final scheme = Theme.of(context).colorScheme;
      background = scheme.tertiaryContainer;
      foreground = scheme.onTertiaryContainer;
      border = null;
    } else if (appVisualStyle.usesSolidPlastic) {
      background = TitoColors.softYellow.withValues(alpha: 0.88);
      foreground = TitoColors.ink;
      border = Border.all(
        color: Colors.white.withValues(alpha: 0.78),
        width: TitoBorders.glass,
      );
    } else {
      background = TitoColors.softYellow;
      foreground = TitoColors.ink;
      border = Border.all(color: TitoColors.ink, width: TitoBorders.element);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(TitoRadii.sm),
        border: border,
      ),
      child: Text(
        text,
        style: SecondaryTypography.onCard.body14.copyWith(
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
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
                    border: appVisualStyle.usesTrainerJournal
                        ? Border.all(
                            color: TitoColors.ink,
                            width: TitoBorders.element,
                          )
                        : null,
                  ),
                ),
                // Connector rule between timeline dots (a line, not an
                // outline), so it keeps its own 2px weight.
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
                      child: Text(
                        entry.at!,
                        style: SecondaryTypography.onCard.small12.copyWith(
                          fontWeight: FontWeight.w800,
                          color: TitoColors.mutedInk,
                        ),
                      ),
                    ),
                  Text(
                    localizeTimelineEntry(entry.text),
                    style: SecondaryTypography.onCard.body14.copyWith(
                      fontWeight: FontWeight.w700,
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
