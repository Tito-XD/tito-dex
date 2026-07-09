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

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(bottom: compact ? 84 : 96),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
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
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Square H5 layout:
/// continue + party grid on top, colorful polaroid quick tiles below.
class _SquareHomeLayout extends StatelessWidget {
  const _SquareHomeLayout({required this.journey, required this.onContinue});

  final CurrentJourney journey;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final gap = DeviceLayout.sectionSpacing(context);
    final compact = DeviceLayout.isCompact(context);

    return Column(
      children: [
        Expanded(
          flex: 14,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 13,
                child: ContinueJourneyCard(
                  journey: journey,
                  onContinue: onContinue,
                  compact: compact,
                  dense: true,
                  mergeContinue: true,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                flex: 10,
                child: PartyStrip(
                  party: journey.party,
                  compact: compact,
                  square: true,
                  gridMode: true,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: gap),
        Expanded(
          flex: 10,
          child: _QuickActionsGrid(dense: true, polaroid: true),
        ),
      ],
    );
  }
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
            onTap: () => context.push(action.route),
            tone: action.tone,
            compact: dense,
            tiltDegrees: rotations[index],
          );
        }

        return TitoQuickTile(
          label: action.label,
          icon: action.icon,
          onTap: () => context.push(action.route),
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
