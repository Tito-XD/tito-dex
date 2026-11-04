import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/motion_preferences.dart';
import '../theme/tito_motion.dart';

/// Interpolates changes to one visible metric, never its first presentation.
/// [identity] changes when the subject or metric changes, not its parameters.
class TitoAnimatedNumber extends StatefulWidget {
  const TitoAnimatedNumber({
    super.key,
    required this.value,
    required this.identity,
    this.style,
    this.textKey,
  });

  final int value;
  final Object identity;
  final TextStyle? style;
  final Key? textKey;

  @override
  State<TitoAnimatedNumber> createState() => _TitoAnimatedNumberState();
}

class _TitoAnimatedNumberState extends State<TitoAnimatedNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TitoMotion.standard,
    value: 1,
  );
  late double _from = widget.value.toDouble();
  late double _target = _from;
  bool _tickerEnabled = true;
  bool _systemReduced = false;

  bool get _canAnimate =>
      _tickerEnabled &&
      !_systemReduced &&
      motionPreferences.listAnimationsEnabled;

  double get _displayed =>
      _from +
      (_target - _from) * Curves.easeOutCubic.transform(_controller.value);

  @override
  void initState() {
    super.initState();
    motionPreferences.addListener(_motionChanged);
  }

  void _snap() {
    _from = _target = widget.value.toDouble();
    _controller.value = 1;
  }

  void _motionChanged() {
    if (!_canAnimate) {
      setState(_snap);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _systemReduced = MediaQuery.disableAnimationsOf(context);
    if (!_canAnimate) _snap();
  }

  @override
  void didUpdateWidget(covariant TitoAnimatedNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity ||
        !_canAnimate ||
        HardwareKeyboard.instance.logicalKeysPressed.isNotEmpty) {
      _snap();
    } else if (oldWidget.value != widget.value) {
      // Retarget from the currently painted value, including an interrupted run.
      _from = _displayed;
      _target = widget.value.toDouble();
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    motionPreferences.removeListener(_motionChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    return Semantics(
      label: '${widget.value}',
      // Intermediate frames are decoration; assistive technology reads the result.
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Text(
          '${_canAnimate ? _displayed.round() : widget.value}',
          key: widget.textKey,
          style: style.copyWith(
            fontFeatures: [
              ...?style.fontFeatures,
              const FontFeature.tabularFigures(),
            ],
          ),
        ),
      ),
    );
  }
}
