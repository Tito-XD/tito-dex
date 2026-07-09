import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_buttons.dart';
import '../widgets/app_header.dart';
import '../widgets/trainer_card.dart';
import '../widgets/continue_journey_card.dart';
import '../widgets/party_strip.dart';

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
    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    final padding = DeviceLayout.pagePadding(context);

    if (DeviceLayout.useSquareDashboard(context)) {
      return Padding(
        padding: padding,
        child: Column(
          children: [
            const AppHeader(),
            Expanded(
              child: _SquareHomeLayout(
                journey: journey,
                onContinue: onContinue,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: _PortraitHomeLayout(
              journey: journey,
              onContinue: onContinue,
            ),
          ),
        ],
      ),
    );
  }
}

/// Portrait H4 layout:
/// trainer card -> continue card -> horizontal party strip -> 2x2 quick grid.
class _PortraitHomeLayout extends StatelessWidget {
  const _PortraitHomeLayout({required this.journey, required this.onContinue});

  final CurrentJourney journey;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final gap = DeviceLayout.sectionSpacing(context);
    final compact = DeviceLayout.isCompact(context);
    final continueHeight = compact ? 228.0 : 292.0;
    final partyHeight = compact ? 126.0 : 154.0;
    final companionPad = compact ? 72.0 : 84.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final column = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrainerCard(journey: journey, compact: true, dense: true),
            SizedBox(height: gap),
            SizedBox(
              height: continueHeight,
              child: ContinueJourneyCard(
                journey: journey,
                onContinue: onContinue,
                compact: compact,
                mergeContinue: true,
              ),
            ),
            SizedBox(height: gap),
            SizedBox(
              height: partyHeight,
              child: PartyStrip(party: journey.party, compact: compact),
            ),
            SizedBox(height: gap),
            _QuickActionsGrid(dense: compact, polaroid: false),
            SizedBox(height: companionPad),
          ],
        );

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: column,
        );
      },
    );
  }
}

/// Square / 4:3 / 3:4 handheld layout (H5):
/// [ Trainer + Continue | Party ] + square quick actions.
class _SquareHomeLayout extends StatelessWidget {
  const _SquareHomeLayout({required this.journey, required this.onContinue});

  final CurrentJourney journey;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final gap = DeviceLayout.sectionSpacing(context);
    final quickSize = DeviceLayout.squareQuickTileHeight(context);

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TrainerCard(
                      journey: journey,
                      compact: true,
                      dense: true,
                      micro: true,
                    ),
                    SizedBox(height: gap),
                    Expanded(
                      child: ContinueJourneyCard(
                        journey: journey,
                        onContinue: onContinue,
                        compact: true,
                        dense: true,
                        mergeContinue: true,
                        showIllustration: false,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                flex: 9,
                child: PartyStrip(
                  party: journey.party,
                  compact: true,
                  square: true,
                  listMode: true,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: gap),
        SizedBox(
          height: quickSize,
          child: const _QuickActionsBar(),
        ),
      ],
    );
  }
}

/// Bottom quick bar — square tiles in one row on handheld dashboard.
class _QuickActionsBar extends StatelessWidget {
  const _QuickActionsBar();

  @override
  Widget build(BuildContext context) {
    final actions = _quickActions();
    final gap = DeviceLayout.sectionSpacing(context);

    return Row(
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) SizedBox(width: gap),
          Expanded(
            child: TitoQuickTile(
              label: actions[index].label,
              icon: actions[index].icon,
              onTap: () => _openRoute(context, actions[index].route),
              compact: true,
              dense: true,
              square: true,
            ),
          ),
        ],
      ],
    );
  }
}

void _openRoute(BuildContext context, String route) {
  context.push(route);
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.dense, required this.polaroid});

  final bool dense;
  final bool polaroid;

  @override
  Widget build(BuildContext context) {
    final actions = _quickActions();
    final rotations = const [-2.5, 2.0, 1.5, -1.75];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: dense ? 6 : 10,
        mainAxisSpacing: dense ? 6 : 10,
        childAspectRatio: polaroid ? 1.2 : 1.85,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        if (polaroid) {
          return TitoPolaroidQuickTile(
            label: action.label,
            icon: action.icon,
            onTap: () => _openRoute(context, action.route),
            tone: action.tone,
            compact: dense,
            tiltDegrees: rotations[index],
          );
        }

        return TitoQuickTile(
          label: action.label,
          icon: action.icon,
          onTap: () => _openRoute(context, action.route),
          compact: true,
          dense: dense,
        );
      },
    );
  }
}

List<_QuickAction> _quickActions() {
  return [
    _QuickAction(
      label: AppZh.navTeam,
      icon: Icons.groups_rounded,
      route: '/team',
      tone: TitoPolaroidTone.blue,
    ),
    _QuickAction(
      label: AppZh.navJourney,
      icon: Icons.map_rounded,
      route: '/journey',
      tone: TitoPolaroidTone.yellow,
    ),
    _QuickAction(
      label: AppZh.navDex,
      icon: Icons.grid_view_rounded,
      route: '/dex',
      tone: TitoPolaroidTone.coral,
    ),
    _QuickAction(
      label: AppZh.navSearch,
      icon: Icons.search_rounded,
      route: '/search',
      tone: TitoPolaroidTone.mint,
    ),
  ];
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.route,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final String route;
  final TitoPolaroidTone tone;
}
