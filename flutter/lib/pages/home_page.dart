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
import '../widgets/trainer_card.dart';
import '../widgets/journey_card.dart';
import '../widgets/party_strip.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.journey,
    required this.onJourneyOpen,
    this.gameBadge = 'HGSS',
    this.onGameBadgeTap,
  });

  final CurrentJourney journey;
  final VoidCallback onJourneyOpen;
  final String gameBadge;
  final void Function(BuildContext context)? onGameBadgeTap;

  @override
  Widget build(BuildContext context) {
    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    final padding = DeviceLayout.pagePadding(context);
    final saveLinked = gameEditionRepository.edition.isSaveLinked;
    final header = AppHeader(
      gameBadge: gameBadge,
      trainerName: journey.trainerName,
      onGameBadgeTap: onGameBadgeTap == null
          ? null
          : () => onGameBadgeTap!(context),
    );

    if (DeviceLayout.useSquareDashboard(context)) {
      return Padding(
        padding: padding,
        child: Column(
          children: [
            header,
            Expanded(
              child: _SquareHomeLayout(
                journey: journey,
                saveLinked: saveLinked,
                onJourneyOpen: onJourneyOpen,
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
          header,
          Expanded(
            child: _PortraitHomeLayout(
              journey: journey,
              saveLinked: saveLinked,
              onJourneyOpen: onJourneyOpen,
            ),
          ),
        ],
      ),
    );
  }
}

/// Portrait H4 layout:
/// trainer card -> journey card (save-linked) -> party strip -> quick actions row.
class _PortraitHomeLayout extends StatelessWidget {
  const _PortraitHomeLayout({
    required this.journey,
    required this.saveLinked,
    required this.onJourneyOpen,
  });

  final CurrentJourney journey;
  final bool saveLinked;
  final VoidCallback onJourneyOpen;

  @override
  Widget build(BuildContext context) {
    final gap = DeviceLayout.sectionSpacing(context);
    final compact = DeviceLayout.isCompact(context);
    final journeyHeight = compact ? 108.0 : 132.0;
    final partyHeight = compact ? 126.0 : 154.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final column = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrainerCard(
              journey: journey,
              compact: true,
              dense: true,
            ),
            if (saveLinked) ...[
              SizedBox(height: gap),
              SizedBox(
                height: journeyHeight,
                child: JourneyCard(
                  journey: journey,
                  onOpenDetail: onJourneyOpen,
                  compact: compact,
                ),
              ),
            ],
            SizedBox(height: gap),
            SizedBox(
              height: partyHeight,
              child: PartyStrip(party: journey.party, compact: compact),
            ),
            SizedBox(height: gap),
            _QuickActionsGrid(dense: compact),
          ],
        );

        return Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                minHeight: constraints.maxHeight,
              ),
              child: Align(
                alignment: Alignment.center,
                child: column,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Square / 4:3 / 3:4 handheld layout (H5):
/// [ Trainer (+ Journey) | Party ] + square quick actions.
class _SquareHomeLayout extends StatelessWidget {
  const _SquareHomeLayout({
    required this.journey,
    required this.saveLinked,
    required this.onJourneyOpen,
  });

  final CurrentJourney journey;
  final bool saveLinked;
  final VoidCallback onJourneyOpen;

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
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TrainerCard(
                      journey: journey,
                      compact: true,
                      dense: true,
                      micro: true,
                    ),
                    if (saveLinked) ...[
                      SizedBox(height: gap),
                      Expanded(
                        child: JourneyCard(
                          journey: journey,
                          onOpenDetail: onJourneyOpen,
                          compact: true,
                          dense: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                flex: 1,
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

    return TitoFontScale(
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
