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
  });

  final CurrentJourney journey;
  final VoidCallback? onContinue;
  final bool compact;
  final bool dense;
  /// Map thumbnail acts as the continue button (no separate CTA).
  final bool mergeContinue;

  @override
  Widget build(BuildContext context) {
    final padding = (compact || dense)
        ? DeviceLayout.cardPadding(context)
        : null;

    final card = StickerCard(
      variant: StickerVariant.deep,
      padding: padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dense)
            Text(
              '${journey.trainerName} · ${localizeGame(journey.game)}',
              style: context.tito.onDeepOverline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else
            Text(
              AppZh.continueJourney.toUpperCase(),
              style: context.tito.onDeepOverline,
            ),
          SizedBox(height: dense ? 2 : (compact ? 4 : 6)),
          Text(
            localizeLocation(journey.location),
            style: context.tito.onDeepHeading,
            maxLines: dense ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: dense ? 4 : (compact ? 6 : 8)),
          Expanded(
            child: mergeContinue
                ? HandheldFocusDecorator(
                    onActivate: onContinue,
                    borderRadius: BorderRadius.circular(TitoRadii.md),
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
          SizedBox(height: dense ? 4 : (compact ? 6 : 8)),
          Row(
            children: [
              _Meta(
                label: AppZh.labelBadges,
                value: '${journey.badges}/${journey.maxBadges}',
                compact: compact || dense,
                dense: dense,
              ),
              _Meta(
                label: AppZh.labelPlayTime,
                value: journey.playTime,
                compact: compact || dense,
                dense: dense,
              ),
              if (!dense)
                _Meta(
                  label: AppZh.labelGame,
                  value: localizeGame(journey.game),
                  compact: compact || dense,
                  dense: dense,
                ),
            ],
          ),
          if (!mergeContinue && !compact && !dense) ...[
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

    return card;
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.onContinue,
    required this.compact,
    required this.dense,
  });

  final VoidCallback? onContinue;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return HandheldFocusDecorator(
      onActivate: onContinue,
      child: Material(
        color: TitoColors.deepBlue,
        borderRadius: BorderRadius.circular(TitoRadii.md),
        child: InkWell(
          onTap: onContinue,
          borderRadius: BorderRadius.circular(TitoRadii.md),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: dense ? 8 : (compact ? 10 : 14),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TitoRadii.md),
              border: Border.all(color: TitoColors.ink, width: 3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppZh.continueButton,
                  style: TitoTypography.style(
                    color: TitoColors.card,
                    fontWeight: FontWeight.w800,
                    fontSize: dense ? 12 : (compact ? 14 : 16),
                  ),
                ),
                SizedBox(width: dense ? 4 : 6),
                Icon(
                  Icons.play_arrow_rounded,
                  color: TitoColors.card,
                  size: dense ? 16 : (compact ? 18 : 22),
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
    this.compact = false,
    this.dense = false,
  });

  final String label;
  final String value;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: dense
                ? context.tito.onDeepMetaLabel.copyWith(fontSize: 9)
                : context.tito.onDeepMetaLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value,
            style: dense
                ? context.tito.onDeepMetaValue.copyWith(fontSize: 10)
                : context.tito.onDeepMetaValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
