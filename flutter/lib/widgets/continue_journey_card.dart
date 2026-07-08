import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_buttons.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'city_illustration.dart';
import 'sticker_card.dart';

class ContinueJourneyCard extends StatelessWidget {
  const ContinueJourneyCard({
    super.key,
    required this.journey,
    this.onContinue,
    this.compact = false,
    this.dense = false,
  });

  final CurrentJourney journey;
  final VoidCallback? onContinue;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final padding = (compact || dense)
        ? DeviceLayout.cardPadding(context)
        : null;

    return StickerCard(
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
          SizedBox(height: dense ? 1 : (compact ? 2 : 4)),
          Text(
            localizeLocation(journey.location),
            style: context.tito.onDeepHeading,
            maxLines: dense ? 2 : null,
            overflow: dense ? TextOverflow.ellipsis : null,
          ),
          if (!dense) ...[
            SizedBox(height: compact ? 8 : 12),
            CityIllustration(compact: compact),
          ],
          SizedBox(height: dense ? 4 : (compact ? 8 : 12)),
          Row(
            children: [
              _Meta(
                label: AppZh.labelGame,
                value: localizeGame(journey.game),
                compact: compact || dense,
                dense: dense,
              ),
              _Meta(
                label: AppZh.labelPlayTime,
                value: journey.playTime,
                compact: compact || dense,
                dense: dense,
              ),
              _Meta(
                label: AppZh.labelBadges,
                value: '${journey.badges}/${journey.maxBadges}',
                compact: compact || dense,
                dense: dense,
              ),
            ],
          ),
          if (!compact && !dense && journey.party.isNotEmpty) ...[
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
                      style: context.tito.onDeepMetaValue.copyWith(
                        color: TitoColors.card,
                        fontSize: DeviceLayout.bodyTextSize(context),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const Spacer(),
          SizedBox(height: dense ? 4 : (compact ? 10 : 16)),
          TitoPrimaryButton(
            label: AppZh.continueButton,
            onPressed: onContinue,
            expanded: true,
            compact: compact || dense,
            dense: dense,
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
