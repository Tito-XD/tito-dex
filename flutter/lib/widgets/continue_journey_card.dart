import 'package:flutter/material.dart';

import '../models/journey.dart';
import '../theme/tito_colors.dart';
import 'sticker_card.dart';

class ContinueJourneyCard extends StatelessWidget {
  const ContinueJourneyCard({
    super.key,
    required this.journey,
    this.onContinue,
  });

  final CurrentJourney journey;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      variant: StickerVariant.deep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Continue Journey',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: TitoColors.skyBlue,
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            journey.location,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: TitoColors.card,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 96,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF243A57),
              borderRadius: BorderRadius.circular(TitoRadii.md),
              border: Border.all(color: TitoColors.card, width: 2),
            ),
            child: const Center(
              child: Text(
                '★  City view  ★',
                style: TextStyle(
                  color: TitoColors.softYellow,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Meta(label: 'Game', value: journey.game),
              _Meta(label: 'Play Time', value: journey.playTime),
              _Meta(
                label: 'Badges',
                value: '${journey.badges}/${journey.maxBadges}',
              ),
            ],
          ),
          if (journey.party.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final member in journey.party)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: TitoColors.card.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: TitoColors.card, width: 1.5),
                    ),
                    child: Text(
                      member.nickname ?? member.species,
                      style: const TextStyle(
                        color: TitoColors.card,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: TitoColors.coral,
                foregroundColor: TitoColors.ink,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TitoRadii.md),
                  side: const BorderSide(color: TitoColors.ink, width: 2),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: TitoColors.skyBlue,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: TitoColors.card,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
