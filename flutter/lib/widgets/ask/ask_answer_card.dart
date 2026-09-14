import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../features/journey/ask_motion_theme.dart';
import '../../features/journey/ask_motion_images.dart';
import '../../features/journey/ask_titodex_answer_blocks.dart';
import '../../features/journey/ask_titodex_entity_links.dart';
import '../../features/journey/ask_titodex_service.dart';
import '../../features/journey/progression_hints.dart';
import '../../l10n/app_zh.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import '../assistant_surface.dart';
import '../ask_answer_motion_title.dart';
import '../tito_skeleton.dart';
import 'ask_answer_blocks_view.dart';
import 'ask_answer_sources.dart';
import 'ask_answer_text.dart';
import 'ask_entity_links.dart';
import 'ask_paper_style.dart';

class AskLiveAnswerCard extends StatefulWidget {
  const AskLiveAnswerCard({
    super.key,
    required this.question,
    this.prepareImages,
    required this.progress,
    required this.streamedBlocks,
    required this.clarification,
    required this.result,
    required this.entityResolver,
    required this.sourceOpener,
    required this.onRetry,
    required this.onClarificationSelected,
    required this.onContentSettled,
  });

  final String question;
  final AskMotionImagePreparer? prepareImages;
  final AskTitoDexProgress progress;
  final List<AskTitoDexAnswerBlock> streamedBlocks;
  final AskTitoDexClarification? clarification;
  final AskTitoDexResult? result;
  final AskTitoDexEntityResolver entityResolver;
  final AskTitoDexSourceOpener sourceOpener;
  final VoidCallback onRetry;
  final ValueChanged<AskTitoDexClarificationCandidate> onClarificationSelected;
  final VoidCallback onContentSettled;

  @override
  State<AskLiveAnswerCard> createState() => _LiveAnswerCardState();
}

class _LiveAnswerCardState extends State<AskLiveAnswerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle;
  late AskMotionTheme _motionTheme;

  @override
  void initState() {
    super.initState();
    _motionTheme = classifyAskMotionTheme(widget.question);
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant AskLiveAnswerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question != widget.question) {
      _motionTheme = classifyAskMotionTheme(widget.question);
    }
    if (oldWidget.result == null && widget.result != null) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _settle.value = 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onContentSettled();
        });
      } else {
        _settle.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  String _titleText(String stage) => switch (widget.result?.status) {
    AskTitoDexStatus.answered => AppZh.askTitoDexProgressDone,
    AskTitoDexStatus.noMatch => AppZh.askMotionNoMatch,
    AskTitoDexStatus.needsClarification => AppZh.askMotionClarify,
    AskTitoDexStatus.failed => AppZh.askMotionFailed,
    null => stage,
  };

  Widget _motionTitle(String stage) => AskAnswerMotionTitle(
    leading: true,
    key: const Key('ask-titodex-answer-motion-title'),
    text: _titleText(stage),
    theme: _motionTheme,
    prepareImages: widget.prepareImages,
    stage: widget.progress == AskTitoDexProgress.verifyingAnswer
        ? 'verify'
        : widget.progress == AskTitoDexProgress.revealingAnswer
        ? 'organize'
        : 'lookup',
    outcome: switch (widget.result?.status) {
      AskTitoDexStatus.answered => AskMotionOutcome.caught,
      AskTitoDexStatus.noMatch => AskMotionOutcome.escaped,
      AskTitoDexStatus.needsClarification ||
      AskTitoDexStatus.failed => AskMotionOutcome.neutral,
      null => null,
    },
    style: SecondaryTypography.onCard.small12.copyWith(
      color: TitoColors.deepBlue,
      fontWeight: FontWeight.w900,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final stage = switch (widget.progress) {
      AskTitoDexProgress.checkingLocal => AppZh.askMotionLocal,
      AskTitoDexProgress.contactingWorker ||
      AskTitoDexProgress.retrievingSources => AppZh.askMotionLookup(
        _motionTheme.topic,
      ),
      AskTitoDexProgress.resolvingQuestion => AppZh.askMotionResolve,
      AskTitoDexProgress.verifyingAnswer => AppZh.askMotionVerify,
      AskTitoDexProgress.revealingAnswer => AppZh.askMotionOrganize,
    };
    final hasSemanticAnswer = widget.streamedBlocks.isNotEmpty;
    final streamedSemanticBody = widget.streamedBlocks
        .map((block) {
          final title = block.title?.trim() ?? '';
          final text = block.text.trim();
          final projectedText = text.isNotEmpty
              ? text
              : block.items.isNotEmpty
              ? block.items.join(AppZh.askTitoDexLiveJoinComma)
              : block.rows
                    .map((row) => row.join(AppZh.askTitoDexLiveJoinComma))
                    .join(AppZh.askTitoDexLiveJoinSemicolon);
          return [
            if (title.isNotEmpty) title,
            if (projectedText.isNotEmpty) projectedText,
          ].join(AppZh.askTitoDexLiveJoinComma);
        })
        .where((value) => value.isNotEmpty)
        .join(AppZh.askTitoDexLiveJoinSemicolon);
    final liveAnswerBody = streamedSemanticBody;
    final completed = widget.result;
    return Semantics(
      key: const Key('ask-titodex-live-answer-semantics'),
      liveRegion: completed == null,
      label: completed == null
          ? liveAnswerBody.isNotEmpty
                ? AppZh.askTitoDexLiveStageBody(stage, liveAnswerBody)
                : stage
          : _titleText(stage),
      child: AnimatedBuilder(
        animation: _settle,
        builder: (context, child) {
          final value = Curves.easeOutBack.transform(_settle.value);
          return Transform.translate(
            key: const Key('ask-titodex-answer-settle'),
            offset: Offset(0, 3 * (1 - value)),
            child: Transform.scale(
              scale: 0.988 + (0.012 * value),
              alignment: Alignment.topCenter,
              child: child,
            ),
          );
        },
        child: AssistantSurface(
          key: const Key('ask-titodex-active-answer-surface'),
          color: askPaperColor,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
          radius: TitoRadii.lg,
          borderColor: askPaperOutline(0.24),
          child: _MotionAwareAnimatedSize(
            onEnd: widget.onContentSettled,
            child: completed == null
                ? Column(
                    key: const Key('ask-titodex-live-answer-content'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox.shrink(
                        key: Key('ask-titodex-generating-answer'),
                      ),
                      _motionTitle(stage),
                      const SizedBox(height: 11),
                      AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                              alignment: Alignment.topLeft,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            ),
                        child: hasSemanticAnswer
                            ? AskAnswerBlocksView(
                                key: const Key('ask-titodex-streaming-answer'),
                                blocks: widget.streamedBlocks,
                                animateBlocks: true,
                              )
                            : widget.clarification != null
                            ? AskStreamingClarification(
                                clarification: widget.clarification!,
                                onSelected: widget.onClarificationSelected,
                              )
                            : Shimmer.fromColors(
                                key: const ValueKey('answer-skeleton'),
                                enabled: !reduceMotion,
                                baseColor: usesAskPaperLook
                                    ? askAssistantSkeleton
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                highlightColor: usesAskPaperLook
                                    ? askAssistantPaper
                                    : Theme.of(context).colorScheme.surface,
                                child: const Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _AnswerSkeletonLine(fraction: 1),
                                    SizedBox(height: 7),
                                    _AnswerSkeletonLine(fraction: 0.84),
                                    SizedBox(height: 7),
                                    _AnswerSkeletonLine(fraction: 0.58),
                                    SizedBox(height: 12),
                                    _AnswerSkeletonEvidence(),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  )
                : Column(
                    key: const Key('ask-titodex-live-answer-content'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(
                        key: Key('ask-titodex-answer-card'),
                        child: SizedBox.shrink(
                          key: Key('ask-titodex-completion-check'),
                        ),
                      ),
                      _motionTitle(stage),
                      const SizedBox(height: 11),
                      if (hasSemanticAnswer)
                        AskAnswerBlocksView(
                          key: const Key('ask-titodex-streaming-answer'),
                          blocks: widget.streamedBlocks,
                        )
                      else
                        _AnswerCardContent(
                          question: widget.question,
                          result: completed,
                          entityResolver: widget.entityResolver,
                          sourceOpener: widget.sourceOpener,
                          animateEvidence: true,
                          animateEntityLinks: true,
                          onRetry: widget.onRetry,
                          onClarificationSelected:
                              widget.onClarificationSelected,
                          onContentSettled: widget.onContentSettled,
                        ),
                      if (hasSemanticAnswer) ...[
                        const SizedBox(height: 12),
                        _AnswerCardContent(
                          question: widget.question,
                          result: completed,
                          entityResolver: widget.entityResolver,
                          sourceOpener: widget.sourceOpener,
                          animateEvidence: true,
                          animateEntityLinks: true,
                          answerAlreadyVisible: true,
                          onRetry: widget.onRetry,
                          onClarificationSelected:
                              widget.onClarificationSelected,
                          onContentSettled: widget.onContentSettled,
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _MotionAwareAnimatedSize extends StatelessWidget {
  const _MotionAwareAnimatedSize({required this.child, this.onEnd});

  final Widget child;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      onEnd: onEnd,
      child: child,
    );
  }
}

class _AnswerSkeletonLine extends StatelessWidget {
  const _AnswerSkeletonLine({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction,
        child: const TitoSkeletonBox(height: 8, radius: 999),
      ),
    );
  }
}

class _AnswerSkeletonEvidence extends StatelessWidget {
  const _AnswerSkeletonEvidence();

  @override
  Widget build(BuildContext context) {
    return const TitoSkeletonBox(height: 30, radius: TitoRadii.md);
  }
}

class _EvidenceReveal extends StatefulWidget {
  const _EvidenceReveal({
    super.key,
    required this.animate,
    required this.child,
    this.onComplete,
  });

  final bool animate;
  final Widget child;
  final VoidCallback? onComplete;

  @override
  State<_EvidenceReveal> createState() => _EvidenceRevealState();
}

class _EvidenceRevealState extends State<_EvidenceReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;
  var _prepared = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 280),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onComplete?.call();
        });
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prepared) return;
    _prepared = true;
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      if (widget.animate) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.onComplete?.call(),
        );
      }
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 170), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _curve,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(_curve),
          child: widget.child,
        ),
      ),
    );
  }
}

class AskAnswerCard extends StatelessWidget {
  const AskAnswerCard({
    super.key,
    required this.question,
    required this.result,
    required this.entityResolver,
    required this.sourceOpener,
    required this.animateEvidence,
    required this.onRetry,
    required this.onClarificationSelected,
  });

  final String question;
  final AskTitoDexResult result;
  final AskTitoDexEntityResolver entityResolver;
  final AskTitoDexSourceOpener sourceOpener;
  final bool animateEvidence;
  final VoidCallback onRetry;
  final ValueChanged<AskTitoDexClarificationCandidate> onClarificationSelected;

  @override
  Widget build(BuildContext context) {
    return AssistantSurface(
      key: const Key('ask-titodex-answer-card'),
      color: askPaperColor,
      radius: TitoRadii.lg,
      child: _AnswerCardContent(
        question: question,
        result: result,
        entityResolver: entityResolver,
        sourceOpener: sourceOpener,
        animateEvidence: animateEvidence,
        onRetry: onRetry,
        onClarificationSelected: onClarificationSelected,
      ),
    );
  }
}

class _AnswerCardContent extends StatelessWidget {
  const _AnswerCardContent({
    required this.question,
    required this.result,
    required this.entityResolver,
    required this.sourceOpener,
    required this.animateEvidence,
    required this.onRetry,
    required this.onClarificationSelected,
    this.animateEntityLinks = false,
    this.answerAlreadyVisible = false,
    this.onContentSettled,
  });

  final String question;
  final AskTitoDexResult result;
  final AskTitoDexEntityResolver entityResolver;
  final AskTitoDexSourceOpener sourceOpener;
  final bool animateEvidence;
  final bool animateEntityLinks;
  final bool answerAlreadyVisible;
  final VoidCallback onRetry;
  final ValueChanged<AskTitoDexClarificationCandidate> onClarificationSelected;
  final VoidCallback? onContentSettled;

  @override
  Widget build(BuildContext context) {
    if (result.status == AskTitoDexStatus.failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result.errorCode == 'upstream_timeout'
                ? AppZh.askTitoDexTimeout
                : AppZh.askTitoDexNetworkFailed,
            style: SecondaryTypography.onCard.body14,
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            key: const Key('ask-titodex-retry'),
            onPressed: onRetry,
            child: Text(AppZh.retry),
          ),
        ],
      );
    }
    if (result.status == AskTitoDexStatus.needsClarification ||
        result.status == AskTitoDexStatus.noMatch) {
      final fallbackMessage = result.errorCode == 'online_timeout_fallback'
          ? AppZh.askTitoDexOnlineTimeoutFallback
          : result.errorCode?.contains('_fallback') == true
          ? AppZh.askTitoDexOnlineFallback
          : result.onlineAttempted && result.modelUsed
          ? AppZh.askTitoDexOnlineSearchedNoMatch
          : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.followUp ?? AppZh.askTitoDexNeedsClarification,
            key: const Key('ask-titodex-follow-up'),
            style: SecondaryTypography.onCard.body14,
          ),
          if (fallbackMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              fallbackMessage,
              key: const Key('ask-titodex-fallback-trace'),
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.deepBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (result.clarificationCandidates.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              AppZh.askTitoDexClarificationPrompt,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            AskClarificationCandidateChips(
              candidates: result.clarificationCandidates,
              onSelected: onClarificationSelected,
            ),
          ],
        ],
      );
    }
    final sourceKinds = result.sourceKinds.toSet().toList(growable: false);
    final sources = uniqueAskAnswerSources(result.sources);
    final answerBody = askTitoDexAnswerBody(result.answer ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          key: const Key('ask-titodex-answer-trace'),
          spacing: 9,
          runSpacing: 4,
          children: [
            _AnswerMetaLabel(label: _answerModeLabel(result.answerMode)),
            _AnswerMetaLabel(
              label: result.modelUsed
                  ? AppZh.askTitoDexTraceModel
                  : AppZh.askTitoDexTraceNoModel,
              emphasized: result.modelUsed,
            ),
            if (result.aiSearchUsed)
              _AnswerMetaLabel(
                label: AppZh.askTitoDexTraceAiSearch,
                emphasized: true,
              ),
            if (sourceKinds.isNotEmpty)
              _AnswerMetaLabel(
                label: AppZh.askTitoDexTraceSearchRoutes(sourceKinds.length),
                emphasized: true,
              ),
          ],
        ),
        if (!answerAlreadyVisible) ...[
          const SizedBox(height: 12),
          if (result.answerBlocks.isNotEmpty)
            AskAnswerBlocksView(
              key: const Key('ask-titodex-answer'),
              blocks: result.answerBlocks,
            )
          else
            AskAssistantMarkdown(
              key: const Key('ask-titodex-answer'),
              data: answerBody,
            ),
        ],
        if (result.unknowns.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            AppZh.askTitoDexUnknownWarning,
            style: SecondaryTypography.onCard.small12.copyWith(
              color: TitoColors.deepBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _EvidenceReveal(
          key: const Key('ask-titodex-evidence-reveal'),
          animate: animateEvidence,
          onComplete: onContentSettled,
          child: AskAnswerEvidenceSummary(
            evidence: result.evidence,
            sources: sources,
            sourceKinds: sourceKinds,
            sourceOpener: sourceOpener,
          ),
        ),
        if (answerBody.isNotEmpty) ...[
          const SizedBox(height: 10),
          AskEntityLinkCards(
            question: question,
            answer: answerBody,
            stableIds: result.evidence?.basis == 'structured'
                ? result.evidence!.entityIds
                : null,
            resolver: entityResolver,
            animate: animateEntityLinks,
          ),
        ],
      ],
    );
  }
}

class _AnswerMetaLabel extends StatelessWidget {
  const _AnswerMetaLabel({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: emphasized ? TitoColors.mint : TitoColors.skyBlue,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: SecondaryTypography.onCard.small12.copyWith(
            color: emphasized ? TitoColors.deepBlue : TitoColors.mutedInk,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

String _answerModeLabel(AskTitoDexAnswerMode mode) => switch (mode) {
  AskTitoDexAnswerMode.localAudited => AppZh.askTitoDexRouteLocal,
  AskTitoDexAnswerMode.auditedOnline => AppZh.askTitoDexRouteAuditedOnline,
  AskTitoDexAnswerMode.aiSearchAudited => AppZh.askTitoDexRouteAiSearch,
  AskTitoDexAnswerMode.curatedSourcesDeterministic =>
    AppZh.askTitoDexRouteCuratedDeterministic,
  AskTitoDexAnswerMode.curatedSourcesQwen => AppZh.askTitoDexRouteCuratedQwen,
  AskTitoDexAnswerMode.deepseekNativeSearch =>
    AppZh.askTitoDexRouteDeepseekNative,
  AskTitoDexAnswerMode.multiSourceQwen => AppZh.askTitoDexRouteMultiSource,
  AskTitoDexAnswerMode.noMatch => AppZh.askTitoDexOnlineSearchedNoMatch,
};
