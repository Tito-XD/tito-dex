import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/dex/dex_models.dart';
import '../../features/dex/dex_repository.dart';
import '../../features/dex/silhouette_quiz.dart';
import '../../features/game/game_edition_repository.dart';
import '../../l10n/app_zh.dart';
import '../../theme/device_layout.dart';
import '../../theme/error_text.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import '../../theme/tito_font_scale.dart';
import '../../widgets/companion_picker_sheet.dart';
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
  static const _bestStreakKey = 'quiz.bestStreak';

  final _random = Random();
  final _recentAnswers = <int>{};

  List<PokemonSummary>? _pool;
  String? _error;
  SilhouetteQuestion? _question;
  int? _selectedId;
  var _correct = 0;
  var _total = 0;
  var _streak = 0;
  var _bestStreak = 0;

  bool get _answered => _selectedId != null;

  @override
  void initState() {
    super.initState();
    _loadBestStreak();
    _loadPool();
  }

  Future<void> _loadBestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _bestStreak = prefs.getInt(_bestStreakKey) ?? 0);
    }
  }

  Future<void> _saveBestStreak(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bestStreakKey, value);
  }

  Future<void> _loadPool() async {
    try {
      // Questions stay within the generation of the selected game — no
      // spoiler species from eras the player has not reached.
      final ceiling = maxNationalDexIdForGeneration(
        gameEditionRepository.edition.generation,
      );
      final scope = await dexRepository.getDefaultScope();
      var pool = [
        for (final entry in await dexRepository.getScopeSummaries(scope))
          if (entry.id <= ceiling) entry,
      ];
      if (pool.length < 4) {
        pool = [
          for (final entry in await dexRepository.getAllSummaries())
            if (entry.id <= ceiling) entry,
        ];
      }
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
        if (_streak > _bestStreak) {
          _bestStreak = _streak;
          _saveBestStreak(_streak);
        }
      } else {
        _streak = 0;
      }
    });
    _recentAnswers.add(question.answer.id);
    if (_recentAnswers.length > _recentAnswerMemory) {
      _recentAnswers.remove(_recentAnswers.first);
    }
  }

  Future<void> _adoptAnswer() async {
    final question = _question;
    if (question == null) {
      return;
    }
    final choice = await adoptCompanion(context, question.answer);
    if (choice != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppZh.quizAdopted(choice.nameZh))),
      );
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
          subtitle: gameEditionRepository.edition.labelZh,
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
      bestStreak: _bestStreak,
      onChoice: _onChoice,
      onNext: _nextQuestion,
      onAdopt: _adoptAnswer,
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
    required this.bestStreak,
    required this.onChoice,
    required this.onNext,
    required this.onAdopt,
  });

  final SilhouetteQuestion question;
  final bool answered;
  final int? selectedId;
  final int correct;
  final int total;
  final int streak;
  final int bestStreak;
  final ValueChanged<PokemonSummary> onChoice;
  final VoidCallback onNext;
  final VoidCallback onAdopt;

  @override
  Widget build(BuildContext context) {
    final compact = DeviceLayout.isCompact(context);
    final spriteSize = compact ? 132.0 : 180.0;
    final answerIsCorrect = selectedId == question.answer.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _ScoreChip(label: AppZh.quizScore(correct, total)),
            if (streak > 1) _ScoreChip(label: AppZh.quizStreak(streak)),
            if (bestStreak > 1)
              _ScoreChip(label: AppZh.quizBestStreak(bestStreak)),
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
          if (answerIsCorrect) ...[
            OutlinedButton.icon(
              onPressed: onAdopt,
              icon: const Icon(Icons.pets_rounded, size: 18),
              label: const Text(AppZh.quizAdoptCompanion),
              style: OutlinedButton.styleFrom(
                foregroundColor: TitoColors.ink,
                backgroundColor: TitoColors.card,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TitoRadii.md),
                  side: const BorderSide(
                    color: TitoColors.ink,
                    width: TitoBorders.element,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
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
