import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../features/companion/companion_art.dart';
import '../features/companion/companion_media.dart';
import '../features/companion/companion_repository.dart';
import '../features/dex/sprite_generation_catalog.dart';
import '../features/journey/ask_titodex_service.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/app_visual_style.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'assistant_surface.dart';
import 'fallback_sprite_image.dart';

/// Trainer's Journal paper tone shared with the Ask TitoDex answer cards.
const _assistantPaper = Color(0xFFFFFBF2);

/// Keeps the selected home companion beside the conversation at all times.
/// The orbit, bob, rotating copy and shimmer start only while a request runs.
class AskTitoDexLoadingCard extends StatefulWidget {
  const AskTitoDexLoadingCard({
    super.key,
    required this.journey,
    required this.loading,
    required this.progress,
    required this.requestSeed,
  });

  final CurrentJourney journey;
  final bool loading;
  final AskTitoDexProgress progress;
  final int requestSeed;

  @override
  State<AskTitoDexLoadingCard> createState() => _AskTitoDexLoadingCardState();
}

class _AskTitoDexLoadingCardState extends State<AskTitoDexLoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  late List<int> _localOrder;
  late List<int> _workerOrder;
  Timer? _messageTimer;
  var _messageIndex = 0;
  var _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _shuffleMessages();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant AskTitoDexLoadingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestSeed != widget.requestSeed) {
      _messageIndex = 0;
      _shuffleMessages();
    }
    if (oldWidget.loading != widget.loading ||
        oldWidget.requestSeed != widget.requestSeed) {
      _syncMotion();
    }
  }

  void _shuffleMessages() {
    _localOrder = List<int>.generate(5, (index) => index)
      ..shuffle(math.Random(widget.requestSeed));
    _workerOrder = List<int>.generate(4, (index) => index)
      ..shuffle(math.Random(widget.requestSeed + 1));
  }

  void _syncMotion() {
    _messageTimer?.cancel();
    _messageTimer = null;
    if (!widget.loading || _reduceMotion) {
      _motion.stop();
      _motion.value = widget.loading ? 0.12 : 0;
      return;
    }
    _motion.repeat();
    _messageTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (mounted && widget.loading) {
        setState(() => _messageIndex += 1);
      }
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  List<String> _messagesForProgress(AskTitoDexProgress progress, String name) {
    final local = AppZh.askTitoDexLocalMessageTemplates(name);
    final worker = AppZh.askTitoDexWorkerMessageTemplates(name);
    return switch (progress) {
      AskTitoDexProgress.checkingLocal => [
        for (final index in _localOrder) local[index % local.length],
      ],
      AskTitoDexProgress.contactingWorker ||
      AskTitoDexProgress.retrievingSources => [
        for (final index in _workerOrder) worker[index % worker.length],
      ],
      AskTitoDexProgress.resolvingQuestion =>
        AppZh.askTitoDexResolvingMessageTemplates(name),
      AskTitoDexProgress.verifyingAnswer =>
        AppZh.askTitoDexVerifyingMessageTemplates(name),
      AskTitoDexProgress.revealingAnswer =>
        AppZh.askTitoDexRevealingMessageTemplates(name),
    };
  }

  String _titleForProgress(AskTitoDexProgress progress) => switch (progress) {
    AskTitoDexProgress.checkingLocal => AppZh.askTitoDexStageCheckingLocal,
    AskTitoDexProgress.contactingWorker => AppZh.askTitoDexStageContactingWorker,
    AskTitoDexProgress.retrievingSources =>
      AppZh.askTitoDexStageRetrievingSources,
    AskTitoDexProgress.resolvingQuestion =>
      AppZh.askTitoDexStageResolvingQuestion,
    AskTitoDexProgress.verifyingAnswer => AppZh.askTitoDexStageVerifyingAnswer,
    AskTitoDexProgress.revealingAnswer => AppZh.askTitoDexStageRevealingAnswer,
  };

  Widget _stageTransition(Widget child, Animation<double> animation) {
    final eased = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(eased),
        child: child,
      ),
    );
  }

  Widget _textFadeTransition(Widget child, Animation<double> animation) {
    // AnimatedSwitcher drives the outgoing child from 1 → 0 and the incoming
    // child from 0 → 1. Restrict both to the upper half of their animation so
    // the old line disappears before the new line becomes visible; this keeps
    // rotating copy readable without the previous sliding text overlap.
    final opacity = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.5, 1, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.5, 1, curve: Curves.easeInCubic),
    );
    return FadeTransition(opacity: opacity, child: child);
  }

  Widget _topLeftSwitcherLayout(
    Widget? currentChild,
    List<Widget> previousChildren,
  ) => Stack(
    alignment: Alignment.topLeft,
    children: [...previousChildren, if (currentChild != null) currentChild],
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: companionRepository,
      builder: (context, _) {
        final choice = companionRepository.choice;
        final speciesId =
            choice?.pokemonId ??
            speciesIdForName(widget.journey.companion) ??
            companionSpeciesIds[hgssDefaultCompanion]!;
        final nameZh =
            choice?.nameZh ?? localizeSpecies(widget.journey.companion);
        final messages = _messagesForProgress(widget.progress, nameZh);
        final message = messages[_messageIndex % messages.length];
        final stageTitle = _titleForProgress(widget.progress);
        final bundled = bundledCompanionGifAsset(speciesId);
        // The sky-tinted paper card is part of the Trainer's Journal look;
        // other themes let AssistantSurface pick its own surface and outline.
        final paperLook = appVisualStyle.usesTrainerJournal;
        final scheme = Theme.of(context).colorScheme;
        final sources = <String>[
          if (choice?.animationSourceUrl case final source?) source,
          if (bundled != null) bundled,
          ...companionGifDownloadCandidates(speciesId),
          cdnStaticSpriteUrlFor(speciesId),
          defaultSpriteUrlFor(speciesId),
        ];

        return Semantics(
          liveRegion: widget.loading,
          label: widget.loading
              ? AppZh.askTitoDexCompanionSearching(nameZh)
              : AppZh.askTitoDexCompanionReady(nameZh),
          child: AssistantSurface(
            key: const Key('ask-titodex-companion-card'),
            color: paperLook
                ? Color.alphaBlend(
                    TitoColors.skyBlue.withValues(alpha: 0.62),
                    _assistantPaper,
                  )
                : null,
            padding: const EdgeInsets.fromLTRB(10, 7, 13, 7),
            radius: TitoRadii.lg,
            borderColor: paperLook
                ? TitoColors.deepBlue.withValues(alpha: 0.4)
                : null,
            child: Row(
              children: [
                SizedBox(
                  width: 66,
                  height: 58,
                  child: AnimatedBuilder(
                    animation: _motion,
                    builder: (context, child) {
                      final phase = _motion.value * math.pi * 2;
                      final bob = widget.loading && !_reduceMotion
                          ? math.sin(phase) * 2.4
                          : 0.0;
                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          if (widget.loading)
                            Positioned.fill(
                              key: const Key('ask-titodex-loading-card'),
                              child: _CompanionSparkleCluster(
                                progress: _reduceMotion ? 0.18 : _motion.value,
                              ),
                            ),
                          Transform.translate(
                            offset: Offset(0, bob),
                            child: child,
                          ),
                        ],
                      );
                    },
                    child: FallbackSpriteImage(
                      sources: sources,
                      width: 52,
                      height: 52,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: _reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    transitionBuilder: _stageTransition,
                    // Keep the text block pinned to the companion's right
                    // edge: the default switcher layout center-aligns its
                    // children, so narrower idle/loading columns drifted
                    // sideways whenever the copy length changed.
                    layoutBuilder: _topLeftSwitcherLayout,
                    child: widget.loading
                        ? Column(
                            key: const ValueKey('loading'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                key: const Key('ask-titodex-loading-stage'),
                                duration: _reduceMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 260),
                                transitionBuilder: _textFadeTransition,
                                layoutBuilder: _topLeftSwitcherLayout,
                                child: Shimmer.fromColors(
                                  key: ValueKey(widget.progress),
                                  enabled: !_reduceMotion,
                                  baseColor: paperLook
                                      ? TitoColors.deepBlue
                                      : scheme.onSurface,
                                  highlightColor: paperLook
                                      ? _assistantPaper
                                      : scheme.surface,
                                  child: Text(
                                    stageTitle,
                                    style: SecondaryTypography.onCard.h15,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              AnimatedSwitcher(
                                key: const Key('ask-titodex-loading-message'),
                                duration: _reduceMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 260),
                                transitionBuilder: _textFadeTransition,
                                layoutBuilder: _topLeftSwitcherLayout,
                                child: Text(
                                  message,
                                  key: ValueKey(message),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: SecondaryTypography.onCard.small12
                                      .copyWith(
                                        color: TitoColors.deepBlue,
                                        height: 1.25,
                                      ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            key: const ValueKey('idle'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppZh.askTitoDexCompanionIdle(nameZh),
                                key: const Key('ask-titodex-companion-idle'),
                                style: SecondaryTypography.onCard.h15,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                AppZh.askTitoDexCompanionIdleHint,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: SecondaryTypography.onCard.small12
                                    .copyWith(color: TitoColors.mutedInk),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CompanionSparkleCluster extends StatelessWidget {
  const _CompanionSparkleCluster({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final pulse = (0.72 + math.sin(progress * math.pi * 2) * 0.2).clamp(
      0.5,
      1.0,
    );
    final counterPulse = (0.72 + math.cos(progress * math.pi * 2) * 0.2).clamp(
      0.5,
      1.0,
    );
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 2,
            top: 5,
            child: Opacity(
              opacity: pulse,
              child: Transform.scale(
                scale: pulse,
                child: const AssistantSparkle(size: 13),
              ),
            ),
          ),
          Positioned(
            right: 1,
            bottom: 7,
            child: Opacity(
              opacity: counterPulse,
              child: Transform.scale(
                scale: counterPulse,
                child: const AssistantSparkle(size: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
