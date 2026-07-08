import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_buttons.dart';
import '../theme/tito_colors.dart';
import 'city_illustration.dart';
import 'sticker_card.dart';

class ContinueJourneyCard extends StatelessWidget {
  const ContinueJourneyCard({
    super.key,
    required this.journey,
    this.onContinue,
    this.compact = false,
  });

  final CurrentJourney journey;
  final VoidCallback? onContinue;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final padding = compact ? DeviceLayout.cardPadding(context) : null;

    return StickerCard(
      variant: StickerVariant.deep,
      padding: padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.continueJourney.toUpperCase(),
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              color: TitoColors.skyBlue,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            localizeLocation(journey.location),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: TitoColors.card,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  fontSize: compact ? 20 : null,
                ),
          ),
          SizedBox(height: compact ? 8 : 12),
          CityIllustration(compact: compact),
          SizedBox(height: compact ? 8 : 12),
          Row(
            children: [
              _Meta(
                label: AppZh.labelGame,
                value: localizeGame(journey.game),
                compact: compact,
              ),
              _Meta(
                label: AppZh.labelPlayTime,
                value: journey.playTime,
                compact: compact,
              ),
              _Meta(
                label: AppZh.labelBadges,
                value: '${journey.badges}/${journey.maxBadges}',
                compact: compact,
              ),
            ],
          ),
          if (!compact && journey.party.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final member in journey.party)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: TitoColors.card.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: TitoColors.skyBlue, width: 2),
                    ),
                    child: Text(
                      member.nickname != null
                          ? member.nickname!
                          : localizeSpecies(member.species),
                      style: const TextStyle(
                        color: TitoColors.card,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          SizedBox(height: compact ? 10 : 16),
          TitoPrimaryButton(
            label: AppZh.continueButton,
            onPressed: onContinue,
            expanded: true,
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: TitoColors.skyBlue,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: TitoColors.card,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 12 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
