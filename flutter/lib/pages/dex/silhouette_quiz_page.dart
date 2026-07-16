import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/dex/dex_models.dart';
import '../../features/dex/dex_repository.dart';
import '../../features/dex/silhouette_quiz.dart';
import '../../l10n/app_zh.dart';
import '../../theme/device_layout.dart';
import '../../theme/error_text.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import '../../theme/tito_font_scale.dart';
import '../../widgets/dex_sprite_image.dart';
import '../../widgets/secondary_page_scaffold.dart';
import '../../widgets/sticker_card.dart';
import '../../widgets/tito_loading_panel.dart';

/// "Who's that Pokémon" — silhouette quiz over the current dex scope,
/// using the same sprites the dex already caches (offline friendly).
class SilhouetteQuizPage extends StatefulWidget {
  const SilhouetteQuizPage({super.key});

  @override
  State<SilhouetteQuizPage> createState() => _SilhouetteQuizPageState();
}

class _SilhouetteQuizPageState extends State<SilhouetteQuizPage> {
  static const _recentAnswerMemory = 12;

  final _random = Random();
  final _recentAnswers = <int>{};

  List<PokemonSummary>? _pool;
  String? _error;
  SilhouetteQuestion? _question;
  int? _selectedId;
  var _correct = 0;
  var _total = 0;
  var _streak = 0;

  bool get _answered => _selectedId != null;

  @override
  void initState() {
    super.initState();
    _loadPool();
  }

  Future<void> _loadPool() async {
    try {
      final scope = await dexRepository.getDefaultScope();
      var pool = await dexRepository.getScopeSummaries(scope);
      if (pool.length < 4) {
        pool = await dexRepository.getAllSummaries();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _pool = pool;
        _error = null;
      });
      _nextQuestion();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = formatUserFacingError(error));
    }
  }

  void _nextQuestion() {
    final pool = _pool;
    if (pool == null) {
      return;
    }
    final question = buildSilhouetteQuestion(
      pool,
      _random,
      excludeIds: _recentAnswers,
    );
    setState(() {
      _question = question;
      _selectedId = null;
    });
  }

  void _onChoice(PokemonSummary choice) {
    final question = _question;
    if (question == null || _answered) {
      return;
    }
    final isCorrect = choice.id == question.answer.id;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedId = choice.id;
      _total += 1;
      if (isCorrect) {
        _correct += 1;
        _streak += 1;
      } else {
        _streak = 0;
      }
    });
    _recentAnswers.add(question.answer.id);
    if (_recentAnswers.length > _recentAnswerMemory) {
      _recentAnswers.remove(_recentAnswers.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TitoFontScale(
      multiplier: 1.0,
      child: Material(
        type: MaterialType.transparency,
        child: SecondaryPageScaffold(
          title: AppZh.quizTitle,
          children: [_body(context)],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final error = _error;
    if (error != null) {
      return StickerCard(
        child: Text(error, style: SecondaryTypography.onCard.body14),
      );
    }
    final question = _question;
    if (_pool == null || question == null) {
      return const TitoLoadingPanel(
        message: AppZh.dexLoadingDetail,
        compact: true,
        showSkeleton: false,
      );
    }
    return _QuizBody(
      question: question,
      answered: _answered,
      selectedId: _selectedId,
      correct: _correct,
      total: _total,
      streak: _streak,
      onChoice: _onChoice,
      onNext: _nextQuestion,
    );
  }
}

class _QuizBody extends StatelessWidget {
  const _QuizBody({
    required this.question,
    required this.answered,
    required this.selectedId,
    required this.correct,
    required this.total,
    required this.streak,
    required this.onChoice,
    required this.onNext,
  });

  final SilhouetteQuestion question;
  final bool answered;
  final int? selectedId;
  final int correct;
  final int total;
  final int streak;
  final ValueChanged<PokemonSummary> onChoice;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final compact = DeviceLayout.isCompact(context);
    final spriteSize = compact ? 132.0 : 180.0;
    final answerIsCorrect = selectedId == question.answer.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _ScoreChip(label: AppZh.quizScore(correct, total)),
            const SizedBox(width: 8),
            if (streak > 1) _ScoreChip(label: AppZh.quizStreak(streak)),
          ],
        ),
        const SizedBox(height: 12),
        StickerCard(
          variant: StickerVariant.sky,
          child: Column(
            children: [
              Text(
                answered
                    ? (answerIsCorrect
                          ? AppZh.quizCorrect
                          : AppZh.quizWrong(question.answer.nameZh))
                    : AppZh.quizPrompt,
                style: SecondaryTypography.onCard.h15,
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOut,
                child: _QuizSprite(
                  key: ValueKey('${question.answer.id}-$answered'),
                  summary: question.answer,
                  silhouette: !answered,
                  size: spriteSize,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: compact ? 3.0 : 3.4,
          children: [
            for (final choice in question.choices)
              _ChoiceButton(
                label: choice.nameZh,
                state: _choiceState(choice),
                onTap: answered ? null : () => onChoice(choice),
              ),
          ],
        ),
        if (answered) ...[
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              backgroundColor: TitoColors.softYellow,
              foregroundColor: TitoColors.ink,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TitoRadii.md),
                side: const BorderSide(
                  color: TitoColors.ink,
                  width: TitoBorders.card,
                ),
              ),
            ),
            child: const Text(AppZh.quizNext),
          ),
        ],
      ],
    );
  }

  _ChoiceState _choiceState(PokemonSummary choice) {
    if (!answered) {
      return _ChoiceState.idle;
    }
    if (choice.id == question.answer.id) {
      return _ChoiceState.correct;
    }
    if (choice.id == selectedId) {
      return _ChoiceState.wrong;
    }
    return _ChoiceState.muted;
  }
}

enum _ChoiceState { idle, correct, wrong, muted }

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _ChoiceState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = switch (state) {
      _ChoiceState.correct => TitoColors.mint,
      _ChoiceState.wrong => TitoColors.coral,
      _ChoiceState.muted => TitoColors.card.withValues(alpha: 0.55),
      _ChoiceState.idle => TitoColors.card,
    };

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(TitoRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TitoRadii.md),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TitoRadii.md),
            border: Border.all(color: TitoColors.ink, width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SecondaryTypography.onCard.body14.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizSprite extends StatelessWidget {
  const _QuizSprite({
    super.key,
    required this.summary,
    required this.silhouette,
    required this.size,
  });

  final PokemonSummary summary;
  final bool silhouette;
  final double size;

  /// Zeroes RGB while keeping alpha — a clean black cut-out of the sprite.
  static const _silhouetteMatrix = <double>[
    0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  @override
  Widget build(BuildContext context) {
    final sprite = DexSpriteImage(
      source: summary.displaySpritePath,
      width: size,
      height: size,
    );
    if (!silhouette) {
      return sprite;
    }
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(_silhouetteMatrix),
      child: sprite,
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: TitoColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TitoColors.ink, width: 2),
      ),
      child: Text(
        label,
        style: SecondaryTypography.onCard.small12.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
