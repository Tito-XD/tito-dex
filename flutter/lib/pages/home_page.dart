import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/game/game_edition_repository.dart';
import '../features/game/journey_capability.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_buttons.dart';
import '../theme/tito_font_scale.dart';
import '../widgets/app_header.dart';
import '../widgets/home_dashboard_body.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.journey,
    required this.onJourneyOpen,
    this.gameBadge = 'HGSS',
    this.onGameBadgeTap,
    this.bootstrapping = false,
  });

  final CurrentJourney journey;
  final VoidCallback onJourneyOpen;
  final String gameBadge;
  final void Function(BuildContext context)? onGameBadgeTap;
  final bool bootstrapping;

  @override
  Widget build(BuildContext context) {
    final padding = DeviceLayout.pagePadding(context);
    final saveLinked = gameEditionRepository.edition.isSaveLinked;
    final header = AppHeader(
      gameBadge: gameBadge,
      trainerName: journey.trainerName,
      onGameBadgeTap: onGameBadgeTap == null
          ? null
          : () => onGameBadgeTap!(context),
    );

    final quickActions = DeviceLayout.useSquareDashboard(context)
        ? const _QuickActionsBar()
        : _QuickActionsGrid(dense: DeviceLayout.isCompact(context));

    return Padding(
      padding: padding,
      child: Column(
        children: [
          header,
          Expanded(
            child: HomeDashboardBody(
              journey: journey,
              saveLinked: saveLinked,
              onJourneyOpen: onJourneyOpen,
              quickActions: quickActions,
              bootstrapping: bootstrapping,
            ),
          ),
        ],
      ),
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
    final quickSize = DeviceLayout.squareQuickTileHeight(context);

    return SizedBox(
      height: quickSize,
      child: TitoFontScale(
        multiplier: 2.0,
        child: Row(
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
        ),
      ),
    );
  }
}

void _openRoute(BuildContext context, String route) {
  context.push(route);
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.dense});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final actions = _quickActions();
    final gap = dense ? 6.0 : 10.0;

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
              dense: dense,
            ),
          ),
        ],
      ],
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
