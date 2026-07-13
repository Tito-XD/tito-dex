import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../navigation/tito_page_transition.dart';
import '../theme/device_layout.dart';
import 'app_header.dart';
import 'journey_card.dart';
import 'party_strip.dart';
import 'tito_loading_panel.dart';
import 'tito_skeleton.dart';
import 'trainer_card.dart';

/// Home dashboard body with optional bootstrap reveal animation.
class HomeDashboardBody extends StatelessWidget {
  const HomeDashboardBody({
    super.key,
    required this.journey,
    required this.saveLinked,
    required this.onJourneyOpen,
    required this.quickActions,
    this.bootstrapping = false,
  });

  final CurrentJourney journey;
  final bool saveLinked;
  final VoidCallback onJourneyOpen;
  final Widget quickActions;
  final bool bootstrapping;

  @override
  Widget build(BuildContext context) {
    if (DeviceLayout.useSquareDashboard(context)) {
      return _SquareHomeLayout(
        journey: journey,
        saveLinked: saveLinked,
        onJourneyOpen: onJourneyOpen,
        quickActions: quickActions,
        bootstrapping: bootstrapping,
      );
    }

    return _PortraitHomeLayout(
      journey: journey,
      saveLinked: saveLinked,
      onJourneyOpen: onJourneyOpen,
      quickActions: quickActions,
      bootstrapping: bootstrapping,
    );
  }
}

class _PortraitHomeLayout extends StatelessWidget {
  const _PortraitHomeLayout({
    required this.journey,
    required this.saveLinked,
    required this.onJourneyOpen,
    required this.quickActions,
    required this.bootstrapping,
  });

  final CurrentJourney journey;
  final bool saveLinked;
  final VoidCallback onJourneyOpen;
  final Widget quickActions;
  final bool bootstrapping;

  @override
  Widget build(BuildContext context) {
    final gap = DeviceLayout.sectionSpacing(context);
    final compact = DeviceLayout.isCompact(context);
    final journeyHeight = compact ? 108.0 : 132.0;
    final partyHeight = compact ? 126.0 : 154.0;
    final companionPad = compact ? 72.0 : 84.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trainerSlot = _TrainerCardSlot(
          journey: journey,
          bootstrapping: bootstrapping,
          dense: true,
        );

        final belowTrainer = AnimatedOpacity(
          duration: TitoMotion.routeForwardDuration,
          curve: TitoMotion.standardCurve,
          opacity: bootstrapping ? 0.0 : 1.0,
          child: IgnorePointer(
            ignoring: bootstrapping,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                quickActions,
                SizedBox(height: companionPad),
              ],
            ),
          ),
        );

        final column = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            trainerSlot,
            if (bootstrapping) ...[
              SizedBox(height: gap),
              const TitoBootstrapProgress(),
            ],
            belowTrainer,
          ],
        );

        return Center(
          child: SingleChildScrollView(
            physics: bootstrapping
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
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

class _SquareHomeLayout extends StatelessWidget {
  const _SquareHomeLayout({
    required this.journey,
    required this.saveLinked,
    required this.onJourneyOpen,
    required this.quickActions,
    required this.bootstrapping,
  });

  final CurrentJourney journey;
  final bool saveLinked;
  final VoidCallback onJourneyOpen;
  final Widget quickActions;
  final bool bootstrapping;

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
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TrainerCardSlot(
                      journey: journey,
                      bootstrapping: bootstrapping,
                      micro: true,
                    ),
                    if (bootstrapping) ...[
                      SizedBox(height: gap),
                      const TitoBootstrapProgress(),
                    ],
                    if (saveLinked) ...[
                      SizedBox(height: gap),
                      Expanded(
                        child: AnimatedOpacity(
                          duration: TitoMotion.routeForwardDuration,
                          opacity: bootstrapping ? 0.0 : 1.0,
                          child: IgnorePointer(
                            ignoring: bootstrapping,
                            child: JourneyCard(
                              journey: journey,
                              onOpenDetail: onJourneyOpen,
                              compact: true,
                              dense: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                flex: 1,
                child: AnimatedOpacity(
                  duration: TitoMotion.routeForwardDuration,
                  opacity: bootstrapping ? 0.0 : 1.0,
                  child: IgnorePointer(
                    ignoring: bootstrapping,
                    child: PartyStrip(
                      party: journey.party,
                      compact: true,
                      square: true,
                      listMode: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: gap),
        AnimatedOpacity(
          duration: TitoMotion.routeForwardDuration,
          opacity: bootstrapping ? 0.0 : 1.0,
          child: IgnorePointer(
            ignoring: bootstrapping,
            child: quickActions,
          ),
        ),
      ],
    );
  }
}

class _TrainerCardSlot extends StatelessWidget {
  const _TrainerCardSlot({
    required this.journey,
    required this.bootstrapping,
    this.dense = false,
    this.micro = false,
  });

  final CurrentJourney journey;
  final bool bootstrapping;
  final bool dense;
  final bool micro;

  @override
  Widget build(BuildContext context) {
    return TrainerCard(
      journey: journey,
      compact: true,
      dense: dense,
      micro: micro,
      useHero: true,
      avatarPlaceholder: bootstrapping,
    );
  }
}

/// Skeleton placeholders for home sections while bootstrap finishes.
class HomeBootstrapSkeleton extends StatelessWidget {
  const HomeBootstrapSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final gap = DeviceLayout.sectionSpacing(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TitoCardSkeleton(height: 120),
        SizedBox(height: gap),
        const TitoCardSkeleton(height: 100),
      ],
    );
  }
}
