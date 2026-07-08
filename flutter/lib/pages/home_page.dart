import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/tito_buttons.dart';
import '../theme/device_layout.dart';
import '../widgets/app_header.dart';
import '../widgets/continue_journey_card.dart';
import '../widgets/party_strip.dart';
import '../widgets/companion_sticker.dart';
import '../widgets/journey_timeline.dart';
import '../widgets/launcher_widgets.dart';
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildBody(context),
        FloatingCompanion(
          name: journey.companion,
          message: AppZh.companionMessage(journey.location),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (DeviceLayout.useSquareDashboard(context)) {
      return Padding(
        padding: DeviceLayout.pagePadding(context),
        child: Column(
          children: [
            const AppHeader(),
            Expanded(
              child: _SquareDashboardLayout(
                journey: journey,
                onContinue: onContinue,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520 &&
            constraints.maxHeight >= 500 &&
            !DeviceLayout.isCompact(context);

        return ListView(
          padding: DeviceLayout.pagePadding(context),
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

/// RG Rotate square dashboard — fits one screen, no scroll.
class _SquareDashboardLayout extends StatelessWidget {
  const _SquareDashboardLayout({
    required this.journey,
    required this.onContinue,
  });

  final CurrentJourney journey;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final gap = DeviceLayout.sectionSpacing(context);

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 13,
                child: ContinueJourneyCard(
                  journey: journey,
                  onContinue: onContinue,
                  compact: true,
                  dense: true,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                flex: 10,
                child: PartyStrip(
                  party: journey.party,
                  compact: true,
                  square: true,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: gap),
        const _QuickActionsRow(dense: true),
      ],
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
    final gap = DeviceLayout.sectionSpacing(context);
    final compact = DeviceLayout.isCompact(context);

    return Column(
      children: [
        TrainerCard(journey: journey, compact: compact),
        SizedBox(height: gap),
        ContinueJourneyCard(
          journey: journey,
          onContinue: onContinue,
          compact: compact,
        ),
        SizedBox(height: gap),
        PartyStrip(party: journey.party, compact: compact),
        if (!DeviceLayout.isShortScreen(context)) ...[
          SizedBox(height: gap),
          _QuickActions(compact: compact),
          SizedBox(height: gap),
          JourneyTimeline(
            entries: journey.timeline,
            nextReminder: journey.nextReminder,
          ),
          SizedBox(height: gap),
          LauncherWidgets(journey: journey),
        ] else ...[
          SizedBox(height: gap),
          const _QuickActionsRow(),
        ],
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
    final gap = DeviceLayout.sectionSpacing(context);

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  TrainerCard(journey: journey),
                  SizedBox(height: gap),
                  ContinueJourneyCard(
                    journey: journey,
                    onContinue: onContinue,
                  ),
                ],
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                children: [
                  PartyStrip(party: journey.party),
                  SizedBox(height: gap),
                  JourneyTimeline(
                    entries: journey.timeline,
                    nextReminder: journey.nextReminder,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        _QuickActions(compact: false),
        SizedBox(height: gap),
        LauncherWidgets(journey: journey),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: compact ? 8 : 10,
      crossAxisSpacing: compact ? 8 : 10,
      childAspectRatio: compact ? 1.5 : 1.35,
      children: _quickTiles(context, compact: compact),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tiles = _quickTiles(context, compact: true, dense: dense);
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) SizedBox(width: dense ? 6 : 8),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

List<Widget> _quickTiles(
  BuildContext context, {
  bool compact = false,
  bool dense = false,
}) {
  return [
    TitoQuickTile(
      label: AppZh.navTeam,
      icon: Icons.groups_rounded,
      onTap: () => context.go('/team'),
      compact: compact,
      dense: dense,
    ),
    TitoQuickTile(
      label: AppZh.navJourney,
      icon: Icons.map_rounded,
      onTap: () => context.go('/journey'),
      compact: compact,
      dense: dense,
    ),
    TitoQuickTile(
      label: AppZh.navDex,
      icon: Icons.grid_view_rounded,
      onTap: () => context.go('/dex'),
      compact: compact,
      dense: dense,
    ),
    TitoQuickTile(
      label: AppZh.navSearch,
      icon: Icons.search_rounded,
      onTap: () => context.go('/search'),
      compact: compact,
      dense: dense,
    ),
  ];
}
