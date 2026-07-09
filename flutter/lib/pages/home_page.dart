import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/companion/companion_art.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_buttons.dart';
import '../widgets/app_header.dart';
import '../widgets/continue_journey_card.dart';
import '../widgets/party_strip.dart';
import '../widgets/companion_sticker.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.journey,
    required this.onContinue,
    this.onCompanionChanged,
  });

  final CurrentJourney journey;
  final VoidCallback onContinue;
  final ValueChanged<String>? onCompanionChanged;

  void _cycleCompanion() {
    final next = cycleCompanion(journey.companion);
    onCompanionChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildBody(context),
        FloatingCompanion(
          name: journey.companion,
          onTap: onCompanionChanged != null ? _cycleCompanion : null,
        ),
      ],
    );
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
              child: _DashboardLayout(
                journey: journey,
                onContinue: onContinue,
                square: true,
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
            child: _DashboardLayout(
              journey: journey,
              onContinue: onContinue,
              square: false,
            ),
          ),
        ],
      ),
    );
  }
}

/// One-screen home — continue + party + quick actions (no scroll).
class _DashboardLayout extends StatelessWidget {
  const _DashboardLayout({
    required this.journey,
    required this.onContinue,
    required this.square,
  });

  final CurrentJourney journey;
  final VoidCallback onContinue;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final gap = DeviceLayout.sectionSpacing(context);
    final compact = DeviceLayout.isCompact(context);

    return Column(
      children: [
        Expanded(
          flex: square ? 13 : 12,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: square ? 13 : 11,
                child: ContinueJourneyCard(
                  journey: journey,
                  onContinue: onContinue,
                  compact: compact,
                  dense: square,
                  mergeContinue: true,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                flex: square ? 10 : 9,
                child: PartyStrip(
                  party: journey.party,
                  compact: compact,
                  square: square,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: gap),
        _QuickActionsRow(dense: square || compact),
      ],
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tiles = _quickTiles(context, dense: dense);
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
  bool dense = false,
}) {
  return [
    TitoQuickTile(
      label: AppZh.navTeam,
      icon: Icons.groups_rounded,
      onTap: () => context.go('/team'),
      compact: true,
      dense: dense,
    ),
    TitoQuickTile(
      label: AppZh.navJourney,
      icon: Icons.map_rounded,
      onTap: () => context.go('/journey'),
      compact: true,
      dense: dense,
    ),
    TitoQuickTile(
      label: AppZh.navDex,
      icon: Icons.grid_view_rounded,
      onTap: () => context.go('/dex'),
      compact: true,
      dense: dense,
    ),
    TitoQuickTile(
      label: AppZh.navSearch,
      icon: Icons.search_rounded,
      onTap: () => context.go('/search'),
      compact: true,
      dense: dense,
    ),
  ];
}
