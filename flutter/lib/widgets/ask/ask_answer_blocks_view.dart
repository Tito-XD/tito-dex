import 'package:flutter/material.dart';

import '../../features/journey/ask_titodex_answer_blocks.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import 'ask_answer_text.dart';

class AskStreamingClarification extends StatelessWidget {
  const AskStreamingClarification({
    super.key,
    required this.clarification,
    required this.onSelected,
  });

  final AskTitoDexClarification clarification;
  final ValueChanged<AskTitoDexClarificationCandidate> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('ask-titodex-streaming-clarification'),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: TitoColors.softYellow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(TitoRadii.md),
        border: Border.all(
          color: TitoColors.softYellow.withValues(alpha: 0.56),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AskBlinkingMarkdown(data: clarification.prompt),
          if (clarification.candidates.isNotEmpty) ...[
            const SizedBox(height: 8),
            AskClarificationCandidateChips(
              candidates: clarification.candidates,
              onSelected: onSelected,
            ),
          ],
        ],
      ),
    );
  }
}

class AskClarificationCandidateChips extends StatelessWidget {
  const AskClarificationCandidateChips({
    super.key,
    required this.candidates,
    required this.onSelected,
  });

  final List<AskTitoDexClarificationCandidate> candidates;
  final ValueChanged<AskTitoDexClarificationCandidate> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('ask-titodex-clarification-candidates'),
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final candidate in candidates)
          ActionChip(
            key: ValueKey('ask-clarification-${candidate.id}'),
            visualDensity: VisualDensity.compact,
            avatar: const Icon(Icons.touch_app_rounded, size: 15),
            label: Text(candidate.label),
            onPressed: () => onSelected(candidate),
          ),
      ],
    );
  }
}

class AskAnswerBlocksView extends StatelessWidget {
  const AskAnswerBlocksView({
    super.key,
    required this.blocks,
    this.animateBlocks = false,
  });

  final List<AskTitoDexAnswerBlock> blocks;
  final bool animateBlocks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          _SemanticAnswerBlock(
            key: ValueKey('ask-answer-block-${blocks[index].id}'),
            block: blocks[index],
            animate: animateBlocks,
          ),
          if (index != blocks.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SemanticAnswerBlock extends StatelessWidget {
  const _SemanticAnswerBlock({
    super.key,
    required this.block,
    required this.animate,
  });

  final AskTitoDexAnswerBlock block;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final child = switch (block.kind) {
      AskTitoDexAnswerBlockKind.summary => _AnswerTextPanel(
        block: block,
        icon: Icons.auto_awesome_rounded,
        color: TitoColors.skyBlue.withValues(alpha: 0.18),
      ),
      AskTitoDexAnswerBlockKind.paragraph => _AnswerTextPanel(block: block),
      AskTitoDexAnswerBlockKind.bullets => _AnswerBulletsBlock(block: block),
      AskTitoDexAnswerBlockKind.table => _AnswerTableBlock(block: block),
      AskTitoDexAnswerBlockKind.warning => _AnswerTextPanel(
        block: block,
        icon: Icons.info_outline_rounded,
        color: TitoColors.coral.withValues(alpha: 0.1),
        borderColor: TitoColors.coral.withValues(alpha: 0.34),
      ),
      AskTitoDexAnswerBlockKind.clarification => _AnswerTextPanel(
        block: block,
        icon: Icons.help_outline_rounded,
        color: TitoColors.softYellow.withValues(alpha: 0.18),
        borderColor: TitoColors.softYellow.withValues(alpha: 0.56),
      ),
    };
    if (!animate || reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 7 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _AnswerTextPanel extends StatelessWidget {
  const _AnswerTextPanel({
    required this.block,
    this.icon,
    this.color,
    this.borderColor,
  });

  final AskTitoDexAnswerBlock block;
  final IconData? icon;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final text = askTitoDexBlockBody(block.text, block.title);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (block.title case final title?) ...[
          Row(
            children: [
              if (icon case final iconData?) ...[
                Icon(iconData, size: 17, color: TitoColors.deepBlue),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  style: SecondaryTypography.onCard.h15.copyWith(
                    color: TitoColors.deepBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (text.isNotEmpty) const SizedBox(height: 5),
        ] else if (icon case final iconData?) ...[
          Icon(iconData, size: 17, color: TitoColors.deepBlue),
          const SizedBox(height: 5),
        ],
        if (text.isNotEmpty)
          block.isComplete
              ? AskAssistantMarkdown(data: text)
              : AskBlinkingMarkdown(data: text),
      ],
    );
    if (color == null && borderColor == null) return content;
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(TitoRadii.md),
        border: Border.all(
          color: borderColor ?? TitoColors.deepBlue.withValues(alpha: 0.12),
        ),
      ),
      child: content,
    );
  }
}

class _AnswerBulletsBlock extends StatelessWidget {
  const _AnswerBulletsBlock({required this.block});

  final AskTitoDexAnswerBlock block;

  @override
  Widget build(BuildContext context) {
    final items = block.items.isNotEmpty
        ? block.items
        : askTitoDexBulletItemsFromText(
            askTitoDexBlockBody(block.text, block.title),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (block.title case final title?) ...[
          Text(
            title,
            style: SecondaryTypography.onCard.h15.copyWith(
              color: TitoColors.deepBlue,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
        ],
        for (var index = 0; index < items.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 7, right: 8),
                  decoration: const BoxDecoration(
                    color: TitoColors.mint,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: !block.isComplete && index == items.length - 1
                      ? AskBlinkingMarkdown(data: items[index])
                      : AskAssistantMarkdown(data: items[index]),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AnswerTableBlock extends StatelessWidget {
  const _AnswerTableBlock({required this.block});

  final AskTitoDexAnswerBlock block;

  @override
  Widget build(BuildContext context) {
    final rows = block.rows.isNotEmpty
        ? block.rows
        : askTitoDexTableRowsFromText(
            askTitoDexBlockBody(block.text, block.title),
          );
    if (rows.isEmpty) {
      return _AnswerTextPanel(block: block);
    }
    final columnCount = rows.fold<int>(
      1,
      (count, row) => row.length > count ? row.length : count,
    );
    final compact = SecondaryTypography.onCard.small12.copyWith(
      color: TitoColors.ink,
      height: 1.3,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (block.title case final title?) ...[
          Text(
            title,
            style: SecondaryTypography.onCard.h15.copyWith(
              color: TitoColors.deepBlue,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(TitoRadii.sm),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(
                color: TitoColors.deepBlue.withValues(alpha: 0.2),
              ),
              children: [
                for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
                  TableRow(
                    decoration: rowIndex == 0
                        ? BoxDecoration(
                            color: TitoColors.skyBlue.withValues(alpha: 0.2),
                          )
                        : null,
                    children: [
                      for (var column = 0; column < columnCount; column++)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child:
                              !block.isComplete &&
                                  rowIndex == rows.length - 1 &&
                                  column == rows[rowIndex].length - 1
                              ? AskBlinkingInlineText(
                                  text: column < rows[rowIndex].length
                                      ? rows[rowIndex][column]
                                      : '',
                                  style: compact,
                                )
                              : Text(
                                  column < rows[rowIndex].length
                                      ? rows[rowIndex][column]
                                      : '',
                                  style: rowIndex == 0
                                      ? compact.copyWith(
                                          color: TitoColors.deepBlue,
                                          fontWeight: FontWeight.w900,
                                        )
                                      : compact,
                                ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
