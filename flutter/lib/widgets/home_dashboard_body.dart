import 'package:flutter/material.dart';

import '../models/journey.dart';
import '../theme/device_layout.dart';
import 'journey_card.dart';
import 'party_strip.dart';
import 'tito_skeleton.dart';
import 'trainer_card.dart';

/// Home dashboard body with optional static bootstrap placeholder state.
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
    // Square handhelds AND regular landscape screens (tablets, rotated
    // phones) share the horizontal composition: portrait's fixed-height
    // stack would clip the party card and force scrolling there.
    if (DeviceLayout.useSquareDashboard(context) ||
        DeviceLayout.isLandscape(context)) {
      return _HorizontalHomeLayout(
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
    final journeyHeight = compact ? 140.0 : 132.0;
    final partyHeight = compact ? 164.0 : 174.0;
    final companionPad = compact ? 72.0 : 84.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trainerSlot = _TrainerCardSlot(
          journey: journey,
          bootstrapping: bootstrapping,
          dense: true,
        );

        final belowTrainer = IgnorePointer(
          ignoring: bootstrapping,
          child: Opacity(
            opacity: bootstrapping ? 0.0 : 1.0,
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
          children: [trainerSlot, belowTrainer],
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
              child: Align(alignment: Alignment.center, child: column),
            ),
          ),
        );
      },
    );
  }
}

class _HorizontalHomeLayout extends StatelessWidget {
  const _HorizontalHomeLayout({
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
                  // Without a linked save there is no journey card below the
                  // trainer card — center it so the column has no dead gap.
                  mainAxisAlignment: saveLinked
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    _TrainerCardSlot(
                      journey: journey,
                      bootstrapping: bootstrapping,
                      dense: true,
                    ),
                    if (saveLinked) ...[
                      SizedBox(height: gap),
                      Expanded(
                        child: IgnorePointer(
                          ignoring: bootstrapping,
                          child: Opacity(
                            opacity: bootstrapping ? 0.0 : 1.0,
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
                child: IgnorePointer(
                  ignoring: bootstrapping,
                  child: Opacity(
                    opacity: bootstrapping ? 0.0 : 1.0,
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
        IgnorePointer(
          ignoring: bootstrapping,
          child: Opacity(
            opacity: bootstrapping ? 0.0 : 1.0,
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
  });

  final CurrentJourney journey;
  final bool bootstrapping;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return TrainerCard(
      journey: journey,
      compact: true,
      dense: dense,
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
