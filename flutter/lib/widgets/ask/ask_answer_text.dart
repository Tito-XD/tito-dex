import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';

class AskBlinkingMarkdown extends StatefulWidget {
  const AskBlinkingMarkdown({super.key, required this.data});

  final String data;

  @override
  State<AskBlinkingMarkdown> createState() => _BlinkingMarkdownState();
}

class _BlinkingMarkdownState extends State<AskBlinkingMarkdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursor;

  @override
  void initState() {
    super.initState();
    _cursor = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 940),
      value: 1,
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _cursor.stop();
      _cursor.value = 1;
    } else if (!_cursor.isAnimating) {
      _cursor.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _cursor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      return AskAssistantMarkdown(data: '${widget.data}▍');
    }
    return AnimatedBuilder(
      animation: _cursor,
      builder: (context, _) => AskAssistantMarkdown(
        data: _cursor.value >= 0.38
            ? '${widget.data}▍'
            : '${widget.data}\u2009',
      ),
    );
  }
}

class AskBlinkingInlineText extends StatefulWidget {
  const AskBlinkingInlineText({
    super.key,
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  State<AskBlinkingInlineText> createState() => _BlinkingInlineTextState();
}

class _BlinkingInlineTextState extends State<AskBlinkingInlineText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursor;

  @override
  void initState() {
    super.initState();
    _cursor = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 940),
      value: 1,
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _cursor.stop();
      _cursor.value = 1;
    } else if (!_cursor.isAnimating) {
      _cursor.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _cursor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _cursor,
      builder: (context, _) => Text(
        _cursor.value >= 0.38 ? '${widget.text}▍' : '${widget.text}\u2009',
        style: widget.style,
      ),
    );
  }
}

class AskAssistantMarkdown extends StatelessWidget {
  const AskAssistantMarkdown({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final body = SecondaryTypography.onCard.body14.copyWith(
      height: 1.45,
      color: TitoColors.ink,
    );
    final compact = SecondaryTypography.onCard.small12.copyWith(
      height: 1.35,
      color: TitoColors.ink,
    );
    final heading = SecondaryTypography.onCard.h15.copyWith(
      color: TitoColors.deepBlue,
      fontWeight: FontWeight.w900,
    );
    final headingPadding = const EdgeInsets.only(top: 7, bottom: 4);
    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      fitContent: true,
      // Answer links are intentionally inert. Only the structured citation
      // sheet may launch externally audited source URLs.
      onTapLink: (_, _, _) {},
      // Never let model-authored Markdown fetch arbitrary remote images.
      imageBuilder: (_, _, _) => const SizedBox.shrink(),
      styleSheet: MarkdownStyleSheet(
        p: body,
        pPadding: EdgeInsets.zero,
        h1: heading.copyWith(fontSize: 17),
        h1Padding: headingPadding,
        h2: heading,
        h2Padding: headingPadding,
        h3: body.copyWith(
          color: TitoColors.deepBlue,
          fontWeight: FontWeight.w900,
        ),
        h3Padding: headingPadding,
        h4: body.copyWith(fontWeight: FontWeight.w900),
        h4Padding: headingPadding,
        h5: body.copyWith(fontWeight: FontWeight.w900),
        h5Padding: headingPadding,
        h6: body.copyWith(fontWeight: FontWeight.w900),
        h6Padding: headingPadding,
        strong: body.copyWith(fontWeight: FontWeight.w900),
        em: body.copyWith(fontStyle: FontStyle.italic),
        a: body.copyWith(
          color: TitoColors.deepBlue,
          decoration: TextDecoration.none,
        ),
        code: compact.copyWith(
          backgroundColor: TitoColors.skyBlue.withValues(alpha: 0.26),
          fontFamily: 'monospace',
        ),
        blockSpacing: 8,
        listIndent: 18,
        listBullet: body.copyWith(fontWeight: FontWeight.w900),
        listBulletPadding: const EdgeInsets.only(right: 6),
        tableHead: compact.copyWith(
          color: TitoColors.deepBlue,
          fontWeight: FontWeight.w900,
        ),
        tableBody: compact,
        tableHeadAlign: TextAlign.left,
        tablePadding: const EdgeInsets.symmetric(vertical: 4),
        tableBorder: TableBorder.all(
          color: TitoColors.deepBlue.withValues(alpha: 0.25),
        ),
        tableColumnWidth: const IntrinsicColumnWidth(),
        tableScrollbarThumbVisibility: true,
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 6,
        ),
        tableHeadCellsDecoration: BoxDecoration(
          color: TitoColors.skyBlue.withValues(alpha: 0.22),
        ),
        blockquote: body.copyWith(color: TitoColors.mutedInk),
        blockquotePadding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
        blockquoteDecoration: BoxDecoration(
          color: TitoColors.skyBlue.withValues(alpha: 0.16),
          border: Border(
            left: BorderSide(
              color: TitoColors.deepBlue.withValues(alpha: 0.45),
              width: 3,
            ),
          ),
        ),
        codeblockPadding: const EdgeInsets.all(10),
        codeblockDecoration: BoxDecoration(
          color: TitoColors.skyBlue.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(TitoRadii.sm),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: TitoColors.deepBlue.withValues(alpha: 0.24)),
          ),
        ),
      ),
    );
  }
}
