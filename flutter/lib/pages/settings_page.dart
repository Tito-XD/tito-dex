import 'package:flutter/material.dart';

import '../models/journey.dart';
import '../theme/tito_colors.dart';
import '../widgets/sticker_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.journey,
    required this.onImportFixture,
    required this.onResetMock,
  });

  final CurrentJourney journey;
  final VoidCallback onImportFixture;
  final VoidCallback onResetMock;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StickerCard(
          child: Column(
            children: [
              _Row(label: 'Trainer', value: journey.trainerName),
              _Row(label: 'Current game', value: journey.game),
              _Row(label: 'Location', value: journey.location),
              _Row(label: 'Play time', value: journey.playTime),
              _Row(
                label: 'Badges',
                value: '${journey.badges}/${journey.maxBadges}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StickerCard(
          variant: StickerVariant.sky,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Journey data',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onImportFixture,
                style: FilledButton.styleFrom(
                  backgroundColor: TitoColors.deepBlue,
                  foregroundColor: TitoColors.card,
                ),
                child: const Text('Import bundled PKMSS.sav'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onResetMock,
                child: const Text('Reset to mock journey'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: StickerCard(
        child: Text(
          '$title screen coming soon',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}
