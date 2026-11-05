import 'package:flutter/material.dart';

import '../theme/motion_preferences.dart';
import '../theme/tito_motion.dart';

/// Types [text] out one character at a time, for short spoken lines such as
/// the companion's quote bubble. Not for menus, reference data or numbers.
///
/// The full line is laid out from the first frame (unrevealed characters are
/// transparent), so the bubble never grows while typing. Screen readers get
/// the full text at once; reduced motion and hidden tabs show it immediately.
class TitoTypewriterText extends StatefulWidget {
  const TitoTypewriterText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.charsPerSecond = TitoMotion.typewriterCharsPerSecond,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final double charsPerSecond;

  @override
  State<TitoTypewriterText> createState() => _TitoTypewriterTextState();
}

class _TitoTypewriterTextState extends State<TitoTypewriterText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
  );
  late List<String> _chars = widget.text.characters.toList();
  bool _primed = false;

  bool get _canAnimate =>
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled &&
      motionPreferences.listAnimationsEnabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_primed) {
      _primed = true;
      _start();
    } else if (!_canAnimate) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant TitoTypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _chars = widget.text.characters.toList();
      _start();
    }
  }

  void _start() {
    if (!_canAnimate || _chars.length <= 1) {
      _controller.value = 1;
      return;
    }
    _controller.duration = Duration(
      milliseconds: (_chars.length / widget.charsPerSecond * 1000).round(),
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final shown = (_chars.length * _controller.value).ceil();
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(text: _chars.take(shown).join()),
                TextSpan(
                  text: _chars.skip(shown).join(),
                  style: style.copyWith(color: Colors.transparent),
                ),
              ],
            ),
            style: style,
            textAlign: widget.textAlign,
            maxLines: widget.maxLines,
            overflow: widget.overflow,
          );
        },
      ),
    );
  }
}
