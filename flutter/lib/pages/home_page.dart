import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/game/game_edition_repository.dart';
import '../features/game/journey_capability.dart';
import '../l10n/app_zh.dart';
import '../navigation/tito_page_transition.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_skin.dart';
import '../widgets/app_header.dart';
import '../widgets/companion_standby.dart';
import '../widgets/handheld_input.dart';
import '../widgets/home_dashboard_body.dart';
import '../widgets/sticker_card.dart';
import '../widgets/sticker_pressable.dart';

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
                _HomeQuickTile(
                  label: actions[index].label,
                  icon: actions[index].icon,
                  iconAsset: actions[index].iconAsset,
                  onTap: () => _openRoute(context, actions[index]),
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
  return Hero(
    tag: heroTag,
    transitionOnUserGestures: true,
    createRectTween: titoDexRectTween,
    curve: titoDexForwardCurve,
    reverseCurve: titoDexReverseCurve,
    child: child,
  );
}

List<_QuickAction> _quickActions() {
  return [
    _QuickAction(
      label: AppZh.navTeam,
      icon: Icons.groups_rounded,
      route: '/team',
      iconAsset: 'assets/icons/Team.png',
    ),
    _QuickAction(
      label: AppZh.navDex,
      icon: Icons.grid_view_rounded,
      route: '/dex',
      heroTag: TitoHomeActionHero.dex,
      iconAsset: 'assets/icons/Dex.png',
    ),
    _QuickAction(
      label: AppZh.navSearch,
      icon: Icons.search_rounded,
      route: '/search',
      iconAsset: 'assets/icons/Search.png',
    ),
  ];
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.route,
    this.heroTag,
    required this.iconAsset,
  });

  final String label;
  final IconData icon;
  final String route;
  final String? heroTag;

  /// Hand-drawn transparent icon, shown directly on the tile (no frame).
  final String iconAsset;
}

/// Team / Dex / Search as action heroes: journal stickers, plastic shells,
/// flat colour blocks. Not trainer heroes — no tape or tilt.
class _HomeQuickTile extends StatelessWidget {
  const _HomeQuickTile({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.iconAsset,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    final tint = skin.heroTint(TitoHeroRole.action);
    final radius = BorderRadius.circular(skin.radiusHero);
    final content = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: skin.ink.withValues(alpha: 0.08),
        highlightColor: skin.ink.withValues(alpha: 0.04),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = constraints.maxHeight.isFinite
                ? (constraints.maxWidth.isFinite
                      ? math.min(constraints.maxWidth, constraints.maxHeight)
                      : constraints.maxHeight)
                : 88.0;
            final iconSide = side * (skin.isFlat ? 0.42 : 0.48);
            final fontSize = (side * 0.16).clamp(11.0, 18.0);
            Widget glyph = Image.asset(
              iconAsset,
              width: iconSide,
              height: iconSide,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Icon(icon, color: tint.ink, size: iconSide * 0.72),
            );
            if (skin.isFlat) {
              glyph = Container(
                width: iconSide + 8,
                height: iconSide + 8,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0x73FFFFFF),
                  shape: BoxShape.circle,
                ),
                child: glyph,
              );
            }
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                glyph,
                SizedBox(height: side * 0.04),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: skin.heading(fontSize, color: tint.ink),
                ),
              ],
            );
          },
        ),
      ),
    );

    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: radius,
      child: StickerPressable(
        borderRadius: radius,
        ownShadow: false,
        child: StickerCard.hero(
          role: TitoHeroRole.action,
          padding: EdgeInsets.zero,
          child: content,
        ),
      ),
    );
  }
}
