import 'package:flutter/material.dart';

import '../models/journey.dart';
import '../widgets/continue_journey_card.dart';
import '../widgets/party_summary.dart';
import '../widgets/sticker_card.dart';
import '../widgets/trainer_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.journey,
    required this.onContinue,
  });

  final CurrentJourney journey;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TrainerCard(journey: journey),
        const SizedBox(height: 16),
        ContinueJourneyCard(journey: journey, onContinue: onContinue),
        const SizedBox(height: 16),
        PartySummary(party: journey.party),
        const SizedBox(height: 16),
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent timeline',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              for (final entry in journey.timeline)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.text,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (entry.at != null)
                        Text(
                          entry.at!,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ),
              if (journey.nextReminder != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Next: ${journey.nextReminder}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
