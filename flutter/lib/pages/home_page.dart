import 'package:flutter/material.dart';

import '../models/journey.dart';
import '../widgets/continue_journey_card.dart';
import '../widgets/journey_timeline.dart';
import '../widgets/party_summary.dart';
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
        JourneyTimeline(
          entries: journey.timeline,
          nextReminder: journey.nextReminder,
        ),
      ],
    );
  }
}
