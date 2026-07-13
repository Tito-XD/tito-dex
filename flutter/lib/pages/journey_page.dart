import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_buttons.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_font_scale.dart';
import '../widgets/journey_timeline.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';

class JourneyPage extends StatelessWidget {
  const JourneyPage({
    super.key,
    required this.journey,
    this.onLaunchEmulator,
  });

  final CurrentJourney journey;
  final VoidCallback? onLaunchEmulator;

  @override
  Widget build(BuildContext context) {
    return TitoFontScale(
      multiplier: 1.0,
      child: SecondaryPageScaffold(
        title: '${AppZh.navJourney} · ${localizeGame(journey.game)}',
        children: [
        if (onLaunchEmulator != null) ...[
          StickerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppZh.emulatorContinueHint,
                  style: SecondaryTypography.onCard.h15,
                ),
                const SizedBox(height: 12),
                TitoPrimaryButton(
                  label: AppZh.continueButton,
                  onPressed: onLaunchEmulator,
                  expanded: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        StickerCard(
          variant: StickerVariant.deep,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppZh.settingsLocation,
                style: SecondaryTypography.onGradient.small12.copyWith(
                  color: TitoColors.skyBlue,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                localizeLocation(journey.location),
                style: SecondaryTypography.onGradient.h15,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SummaryMeta(
                      label: AppZh.settingsCurrentGame,
                      value: localizeGame(journey.game),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryMeta(
                      label: AppZh.settingsBadges,
                      value: '${journey.badges}/${journey.maxBadges}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        JourneyTimeline(
          entries: journey.timeline,
          nextReminder: journey.nextReminder,
        ),
        const SizedBox(height: 14),
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppZh.trainerCard, style: SecondaryTypography.onCard.h15),
              const SizedBox(height: 10),
              _StatRow(
                label: AppZh.settingsDisplayName,
                value: journey.trainerName,
              ),
              _StatRow(label: AppZh.settingsPlayTime, value: journey.playTime),
              _StatRow(
                label: AppZh.settingsBadges,
                value: '${journey.badges}/${journey.maxBadges}',
              ),
              _StatRow(
                label: AppZh.settingsCurrentGame,
                value: localizeGame(journey.game),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: SecondaryTypography.onCard.team12.copyWith(
              color: TitoColors.mutedInk,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: SecondaryTypography.onCard.meta14,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMeta extends StatelessWidget {
  const _SummaryMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TitoColors.deepBlue.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(TitoRadii.sm),
        border: Border.all(color: TitoColors.skyBlue, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: SecondaryTypography.onGradient.small12.copyWith(
                color: TitoColors.skyBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SecondaryTypography.onGradient.meta14,
            ),
          ],
        ),
      ),
    );
  }
}
