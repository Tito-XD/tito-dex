import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/game/game_edition_repository.dart';
import '../features/game/journey_capability.dart';
import '../l10n/app_zh.dart';
import '../navigation/tito_page_transition.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_buttons.dart';
import '../theme/tito_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/companion_standby.dart';
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

    const quickActions = _QuickActionsRow();

    return Padding(
      padding: padding,
      child: Stack(
        children: [
          Column(
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
          if (!bootstrapping) CompanionStandbyOverlay(journey: journey),
        ],
      ),
    );
  }
}

/// Bottom quick bar — the same square tiles on both the portrait phone
/// layout and the handheld square dashboard, sized by one shared formula.
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    final actions = _quickActions();
    final gap = DeviceLayout.sectionSpacing(context);
    final quickSize = DeviceLayout.squareQuickTileHeight(context);

    return SizedBox(
      height: quickSize,
      child: Row(
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            if (index > 0) SizedBox(width: gap),
            Expanded(
              child: _withDexHero(
                actions[index],
                TitoQuickTile(
                  label: actions[index].label,
                  icon: actions[index].icon,
                  onTap: () => _openRoute(context, actions[index]),
                  compact: true,
                  dense: true,
                  square: true,
                  iconPlateColor: actions[index].plateColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void _openRoute(BuildContext context, _QuickAction action) {
  context.push(action.route, extra: action.heroTag);
}

Widget _withDexHero(_QuickAction action, Widget child) {
  final heroTag = action.heroTag;
  if (heroTag == null) {
    return child;
  }
  return Hero(tag: heroTag, transitionOnUserGestures: false, child: child);
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
      heroTag: TitoHomeActionHero.dex,
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
    this.heroTag,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final String route;
  final String? heroTag;
  final TitoPolaroidTone tone;

  /// Accent plate behind the quick-tile icon (v0.6.7 sticker language).
  Color get plateColor => switch (tone) {
    TitoPolaroidTone.coral => TitoColors.coral,
    TitoPolaroidTone.mint => TitoColors.mint,
    _ => TitoColors.skyBlue,
  };
}
