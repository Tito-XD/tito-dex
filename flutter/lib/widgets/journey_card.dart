import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'handheld_input.dart';
import 'sticker_card.dart';
import 'sticker_pressable.dart';

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
    // Always share the layout's cardPadding so this card's edges line up
    // with the trainer card above it in every density (v0.6.7 fix for the
    // mismatched gutters / squeezed look on square dashboards).
    final padding = DeviceLayout.cardPadding(context);
    final location = localizeLocation(journey.location);
    // Dense shrinks the glyph size only — keep Nunito's natural line height
    // or the stacked meta rows read as squeezed against the card's center.
    TextStyle denseStyle(TextStyle style) =>
        style.copyWith(fontSize: (style.fontSize ?? 14) * 0.85);

    return HandheldFocusDecorator(
      onActivate: onOpenDetail,
      borderRadius: BorderRadius.circular(DeviceLayout.rLg(context)),
      child: StickerPressable(
        borderRadius: BorderRadius.circular(DeviceLayout.rLg(context)),
        ownShadow: false,
        child: StickerCard(
          variant: StickerVariant.deep,
          padding: padding,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenDetail,
              borderRadius: BorderRadius.circular(DeviceLayout.rLg(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                // The square layout stretches this card to fill the column —
                // keep the text block vertically centered instead of top-stuck.
                mainAxisAlignment: MainAxisAlignment.center,
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
                              style: dense
                                  ? denseStyle(context.tito.onDeepOverline)
                                  : context.tito.onDeepOverline,
                            ),
                            SizedBox(height: dense ? 4 : (compact ? 6 : 8)),
                            Text(
                              location,
                              style: dense
                                  ? denseStyle(context.tito.onDeepHeading)
                                  : context.tito.onDeepHeading,
                              maxLines: 2,
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
                  SizedBox(height: dense ? 4 : (compact ? 8 : 10)),
                  // Square dashboards only get ~78px for this card — the two
                  // meta columns merge into one row in dense mode so the
                  // badge count and play time survive instead of overflowing.
                  if (dense)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${AppZh.labelBadges} ${journey.badges}/${journey.maxBadges}'
                            ' · ${AppZh.labelPlayTime} ${journey.playTime}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: denseStyle(context.tito.onDeepMetaLabel)
                                .copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    )
                  else
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
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value, required this.dense});

  final String label;
  final String value;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    TextStyle denseStyle(TextStyle style) =>
        style.copyWith(fontSize: (style.fontSize ?? 14) * 0.85);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: dense
                ? denseStyle(context.tito.onDeepMetaLabel)
                : context.tito.onDeepMetaLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value,
            style: dense
                ? denseStyle(context.tito.onDeepMetaValue)
                : context.tito.onDeepMetaValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
