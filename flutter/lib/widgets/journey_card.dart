import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'handheld_input.dart';
import 'sticker_card.dart';

class JourneyCard extends StatelessWidget {
  const JourneyCard({
    super.key,
    required this.journey,
    required this.onOpenDetail,
    this.compact = false,
    this.dense = false,
  });

  final CurrentJourney journey;
  final VoidCallback? onOpenDetail;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final padding = (compact || dense)
        ? DeviceLayout.cardPadding(context)
        : null;
    final location = localizeLocation(journey.location);

    return HandheldFocusDecorator(
      onActivate: onOpenDetail,
      borderRadius: BorderRadius.circular(DeviceLayout.rLg(context)),
      child: StickerCard(
        variant: StickerVariant.deep,
        padding: padding ?? const EdgeInsets.all(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenDetail,
            borderRadius: BorderRadius.circular(DeviceLayout.rLg(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppZh.journeyCardTitle.toUpperCase(),
                            style: context.tito.onDeepOverline,
                          ),
                          SizedBox(height: dense ? 4 : (compact ? 6 : 8)),
                          Text(
                            location,
                            style: context.tito.onDeepHeading,
                            maxLines: dense ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: TitoColors.card,
                      size: dense
                          ? DeviceLayout.dim(context, 28.0)
                          : (compact ? 28 : 32),
                    ),
                  ],
                ),
                SizedBox(height: dense ? 6 : (compact ? 8 : 10)),
                Row(
                  children: [
                    _Meta(
                      label: AppZh.labelBadges,
                      value: '${journey.badges}/${journey.maxBadges}',
                      dense: dense,
                    ),
                    _Meta(
                      label: AppZh.labelPlayTime,
                      value: journey.playTime,
                      dense: dense,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.label,
    required this.value,
    required this.dense,
  });

  final String label;
  final String value;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.tito.onDeepMetaLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value,
            style: context.tito.onDeepMetaValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
