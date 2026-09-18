import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/journey/ask_motion_images.dart';
import '../../features/journey/ask_motion_theme.dart';
import '../../l10n/app_zh.dart';
import '../../theme/app_visual_style.dart';
import '../../theme/retro_style.dart';
import '../../theme/tito_surface_tokens.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import '../../theme/trainer_journal.dart';
import '../ask_answer_motion_title.dart';
import '../assistant_surface.dart';
import '../retro_forms.dart';
import 'ask_answer_text.dart';
import 'ask_game_label.dart';

class AskConversationEmptyState extends StatefulWidget {
  const AskConversationEmptyState({
    super.key,
    this.prepareImages,
    required this.revealFrame,
    required this.cursorHold,
  });
  final Duration revealFrame;
  final Duration cursorHold;
  final AskMotionImagePreparer? prepareImages;

  @override
  State<AskConversationEmptyState> createState() =>
      _AskConversationEmptyStateState();
}

class _AskConversationEmptyStateState extends State<AskConversationEmptyState>
    with WidgetsBindingObserver {
  final _themes = askMotionIdleThemes;
  Timer? _wordTimer;
  Timer? _introTimer;
  int _index = 0;
  int _introLength = 0;
  bool _introFinished = false;
  bool _settledByReduceMotion = false;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  bool get _canAnimate =>
      _visible &&
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.isCurrentOf(context) ?? true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimers();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    _syncTimers();
    if (mounted) setState(() {});
  }

  void _syncTimers() {
    if (!_canAnimate) {
      _wordTimer?.cancel();
      _wordTimer = null;
      _introTimer?.cancel();
      _introTimer = null;
      // Reduce-motion is a persistent preference, so settle the prompt
      // instead of pausing it. Transient covers (route push, backgrounding)
      // only pause the typing so the intro resumes once the surface can
      // animate again instead of never playing at all.
      if (MediaQuery.disableAnimationsOf(context)) {
        _settledByReduceMotion = true;
      }
      return;
    }
    _settledByReduceMotion = false;
    _wordTimer ??= Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted && _canAnimate) {
        setState(() => _index = (_index + 1) % _themes.length);
      }
    });
    if (_introFinished || _introTimer != null) return;
    final length = AppZh.askTitoDexIdlePrompt.characters.length;
    if (_introLength >= length) {
      // Typing already completed; resume the interrupted cursor hold.
      _introTimer = Timer(widget.cursorHold, () {
        if (mounted) setState(() => _introFinished = true);
      });
      return;
    }
    final step = (length / 28).ceil().clamp(1, length);
    _introTimer = Timer.periodic(widget.revealFrame, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_canAnimate) {
        timer.cancel();
        _introTimer = null;
        return;
      }
      setState(() => _introLength = (_introLength + step).clamp(0, length));
      if (_introLength == length) {
        timer.cancel();
        _introTimer = Timer(widget.cursorHold, () {
          if (mounted) setState(() => _introFinished = true);
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wordTimer?.cancel();
    _introTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = SecondaryTypography.onCard.small12.copyWith(
      color: TitoColors.deepBlue.withValues(alpha: 0.72),
    );
    final labels = AppZh.askTitoDexIdleTopics;
    final scaler = MediaQuery.textScalerOf(context);
    // Reserve just the changing phrase so the surrounding sentence stays put.
    var wordWidth = 64.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: style.copyWith(fontWeight: FontWeight.w900),
        ),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      if (painter.width + 12 > wordWidth) wordWidth = painter.width + 12;
      painter.dispose();
    }
    final prompt = AppZh.askTitoDexIdlePrompt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(AppZh.askTitoDexIdlePrefix, style: style),
              SizedBox(
                width: wordWidth,
                child: AskAnswerMotionTitle(
                  key: const Key('ask-titodex-idle-topic'),
                  text: labels[_index],
                  theme: _themes[_index],
                  prepareImages: widget.prepareImages,
                  height: 22,
                  style: style.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Text(AppZh.askTitoDexIdleSuffix, style: style),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: prompt,
            child: ExcludeSemantics(
              child: _introFinished || _settledByReduceMotion
                  ? Text(prompt, style: style, textAlign: TextAlign.center)
                  : AskBlinkingInlineText(
                      text: prompt.characters.take(_introLength).join(),
                      style: style,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class AskQuestionBubble extends StatelessWidget {
  const AskQuestionBubble({
    super.key,
    required this.question,
    this.game,
    this.showGame = false,
  });

  final String question;
  final String? game;
  final bool showGame;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: TitoColors.softYellow,
            // Speech-bubble tail: three token corners plus one tight corner.
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(TitoRadii.lg),
              topRight: Radius.circular(TitoRadii.lg),
              bottomLeft: Radius.circular(TitoRadii.lg),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(
              color: appVisualStyle.usesTrainerJournal
                  ? TrainerJournal.smallEdge
                  : TitoColors.ink.withValues(alpha: 0.3),
              width: appVisualStyle.usesTrainerJournal
                  ? TitoBorders.journalElement
                  : TitoBorders.element,
            ),
            boxShadow: !retroStyle.enabled
                ? null
                : TitoSurfaceTokens.of(context).elementShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (showGame && game != null) ...[
                  Text(
                    askGameLabel(game!),
                    style: SecondaryTypography.onCard.small12.copyWith(
                      color: TitoColors.deepBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  question,
                  key: const Key('ask-titodex-question-bubble'),
                  style: SecondaryTypography.onCard.body14.copyWith(
                    color: TitoColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AskQuestionComposer extends StatelessWidget {
  const AskQuestionComposer({
    super.key,
    required this.questionLimit,
    required this.controller,
    required this.loading,
    required this.enabled,
    required this.onSubmit,
  });

  final int questionLimit;
  final TextEditingController controller;
  final bool loading;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AssistantSurface(
      key: const Key('ask-titodex-composer'),
      padding: const EdgeInsets.fromLTRB(8, 7, 7, 7),
      radius: TitoRadii.lg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const Key('ask-titodex-question'),
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 3,
              maxLength: questionLimit,
              textInputAction: TextInputAction.send,
              decoration:
                  retroInsetDecoration(
                    context: context,
                    hintText: AppZh.askTitoDexQuestionHint,
                  ).copyWith(
                    isDense: true,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 11,
                    ),
                  ),
              onSubmitted: (_) {
                if (!loading) onSubmit();
              },
            ),
          ),
          const SizedBox(width: 7),
          SizedBox.square(
            dimension: 44,
            child: FilledButton(
              key: const Key('ask-titodex-submit'),
              onPressed: loading || !enabled ? null : onSubmit,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
              ),
              child: const Icon(Icons.arrow_upward_rounded, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
