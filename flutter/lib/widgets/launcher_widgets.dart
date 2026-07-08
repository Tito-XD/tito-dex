import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/tito_colors.dart';
import 'sticker_card.dart';

class LauncherWidgets extends StatelessWidget {
  const LauncherWidgets({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _WidgetTile(
            label: AppZh.widgetContinue,
            value: localizeLocation(journey.location),
            meta: journey.playTime,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _WidgetTile(
            label: AppZh.labelBadges,
            value: '${journey.badges}/${journey.maxBadges}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _WidgetTile(
            label: AppZh.companion,
            value: localizeCompanion(journey.companion),
          ),
        ),
      ],
    );
  }
}

class _WidgetTile extends StatelessWidget {
  const _WidgetTile({
    required this.label,
    required this.value,
    this.meta,
  });

  final String label;
  final String value;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: TitoColors.mutedInk,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          if (meta != null) ...[
            const SizedBox(height: 2),
            Text(
              meta!,
              style: const TextStyle(
                fontSize: 11,
                color: TitoColors.mutedInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
