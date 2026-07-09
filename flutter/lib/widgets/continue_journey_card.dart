import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'city_illustration.dart';
import 'handheld_input.dart';
import 'sticker_card.dart';

class ContinueJourneyCard extends StatelessWidget {
  const ContinueJourneyCard({
    super.key,
    required this.journey,
    this.onContinue,
    this.compact = false,
    this.dense = false,
    this.mergeContinue = false,
    this.showIllustration = true,
  });

  final CurrentJourney journey;
  final VoidCallback? onContinue;
  final bool compact;
  final bool dense;
  final bool mergeContinue;
  final bool showIllustration;

  @override
  Widget build(BuildContext context) {
    final padding = (compact || dense)
        ? DeviceLayout.cardPadding(context)
        : null;
    final useIllustration = showIllustration && !dense;

    return StickerCard(
      variant: StickerVariant.deep,
      padding: padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppZh.continueJourney.toUpperCase(),
            style: context.tito.onDeepOverline,
          ),
          SizedBox(height: dense ? 4 : (compact ? 6 : 8)),
          Text(
            localizeLocation(journey.location),
            style: context.tito.onDeepHeading,
            maxLines: dense ? 3 : 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (useIllustration) ...[
            SizedBox(height: dense ? 4 : (compact ? 6 : 8)),
            Expanded(
              child: mergeContinue
                  ? HandheldFocusDecorator(
                      onActivate: onContinue,
                      borderRadius: BorderRadius.circular(DeviceLayout.rMd(context)),
                      child: CityIllustration(
                        location: journey.location,
                        compact: compact,
                        dense: dense,
                        onTap: onContinue,
                        showContinueHint: onContinue != null,
                      ),
                    )
                  : CityIllustration(
                      location: journey.location,
                      compact: compact,
                      dense: dense,
                    ),
            ),
          ],
          if (mergeContinue && !useIllustration)
            const Spacer()
          else if (!mergeContinue && useIllustration)
            const Spacer(),
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
          if (mergeContinue && !useIllustration) ...[
            SizedBox(height: dense ? 8 : 10),
            _ContinueButton(
              onContinue: onContinue,
              compact: compact,
              dense: dense,
              expanded: true,
            ),
          ] else if (!mergeContinue && !compact && !dense) ...[
            const Spacer(),
            SizedBox(height: compact ? 10 : 16),
            _ContinueButton(
              onContinue: onContinue,
              compact: compact,
              dense: dense,
            ),
          ],
        ],
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.onContinue,
    required this.compact,
    required this.dense,
    this.expanded = false,
  });

  final VoidCallback? onContinue;
  final bool compact;
  final bool dense;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final radius = DeviceLayout.rMd(context);
    final button = HandheldFocusDecorator(
      onActivate: onContinue,
      child: Material(
        color: TitoColors.deepBlue,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onContinue,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            width: expanded ? double.infinity : null,
            padding: EdgeInsets.symmetric(
              vertical: dense ? 14 : (compact ? 12 : 16),
              horizontal: dense ? 14 : 16,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: TitoColors.ink, width: 3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Text(
                  AppZh.continueButton,
                  style: context.tito.cardBodyStrong.copyWith(
                    color: TitoColors.card,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.play_arrow_rounded,
                  color: TitoColors.card,
                  size: dense ? DeviceLayout.dim(context, 28.0) : 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
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
