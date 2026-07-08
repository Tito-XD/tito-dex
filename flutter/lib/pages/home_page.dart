import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/tito_buttons.dart';
import '../widgets/app_header.dart';
import '../widgets/companion_sticker.dart';
import '../widgets/continue_journey_card.dart';
import '../widgets/journey_timeline.dart';
import '../widgets/launcher_widgets.dart';
import '../widgets/party_strip.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          children: [
            const AppHeader(),
            if (wide)
              _WideHomeLayout(
                journey: journey,
                onContinue: onContinue,
              )
            else
              _NarrowHomeLayout(
                journey: journey,
                onContinue: onContinue,
              ),
          ],
        );
      },
    );
  }
}

class _NarrowHomeLayout extends StatelessWidget {
  const _NarrowHomeLayout({
    required this.journey,
    required this.onContinue,
  });

  final CurrentJourney journey;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TrainerCard(journey: journey),
        const SizedBox(height: 14),
        ContinueJourneyCard(journey: journey, onContinue: onContinue),
        const SizedBox(height: 14),
        PartyStrip(party: journey.party),
        const SizedBox(height: 14),
        _QuickActions(),
        const SizedBox(height: 14),
        JourneyTimeline(
          entries: journey.timeline,
          nextReminder: journey.nextReminder,
        ),
        const SizedBox(height: 14),
        CompanionSticker(
          name: journey.companion,
          message: AppZh.companionMessage(journey.location),
        ),
        const SizedBox(height: 14),
        LauncherWidgets(journey: journey),
      ],
    );
  }
}

class _WideHomeLayout extends StatelessWidget {
  const _WideHomeLayout({
    required this.journey,
    required this.onContinue,
  });

  final CurrentJourney journey;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  TrainerCard(journey: journey),
                  const SizedBox(height: 14),
                  ContinueJourneyCard(
                    journey: journey,
                    onContinue: onContinue,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: [
                  PartyStrip(party: journey.party),
                  const SizedBox(height: 14),
                  JourneyTimeline(
                    entries: journey.timeline,
                    nextReminder: journey.nextReminder,
                  ),
                  const SizedBox(height: 14),
                  CompanionSticker(
                    name: journey.companion,
                    message: AppZh.companionMessage(journey.location),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _QuickActions(),
        const SizedBox(height: 14),
        LauncherWidgets(journey: journey),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.35,
      children: [
        TitoQuickTile(
          label: AppZh.navTeam,
          icon: Icons.groups_rounded,
          onTap: () => context.go('/team'),
        ),
        TitoQuickTile(
          label: AppZh.navJourney,
          icon: Icons.map_rounded,
          onTap: () => context.go('/journey'),
        ),
        TitoQuickTile(
          label: AppZh.navDex,
          icon: Icons.grid_view_rounded,
          onTap: () => context.go('/dex'),
        ),
        TitoQuickTile(
          label: AppZh.navSearch,
          icon: Icons.search_rounded,
          onTap: () => context.go('/search'),
        ),
      ],
    );
  }
}
