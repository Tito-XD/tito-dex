import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/motion_preferences.dart';
import '../theme/tito_motion.dart';

/// Rolls between exact formatted values, including decimals and fractions.
/// Unlike a numeric tween, intermediate frames never invent another value.
/// [identity] identifies the stable metric slot, not its changing parameters.
class TitoRollingValue extends StatefulWidget {
  const TitoRollingValue({
    super.key,
    required this.value,
    required this.identity,
    this.style,
    this.textKey,
  });

  final String value;
  final Object identity;
  final TextStyle? style;
  final Key? textKey;

  @override
  State<TitoRollingValue> createState() => _TitoRollingValueState();
}

class _TitoRollingValueState extends State<TitoRollingValue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TitoMotion.standard,
    value: 1,
  );
  String? _outgoing;
  TextStyle? _outgoingStyle;
  double _incomingStart = 0;
  double _outgoingStart = 0;
  double _outgoingEnd = -1;
  bool _tickerEnabled = true;
  bool _systemReduced = false;
  double _slotWidth = 0;
  TextStyle? _measuredStyle;
  TextScaler? _measuredScaler;

  bool get _canAnimate =>
      _tickerEnabled &&
      !_systemReduced &&
      motionPreferences.listAnimationsEnabled;

  double get _progress => Curves.easeOutCubic.transform(_controller.value);
  double get _incomingY => _incomingStart * (1 - _progress);
  double get _outgoingY =>
      _outgoingStart + (_outgoingEnd - _outgoingStart) * _progress;

  @override
  void initState() {
    super.initState();
    motionPreferences.addListener(_motionChanged);
  }

  void _snap() {
    _outgoing = null;
    _outgoingStyle = null;
    _incomingStart = 0;
    _controller.value = 1;
  }

  void _motionChanged() {
    if (!_canAnimate) setState(_snap);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _systemReduced = MediaQuery.disableAnimationsOf(context);
    if (!_canAnimate) _snap();
  }

  @override
  void didUpdateWidget(covariant TitoRollingValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _slotWidth = 0;
      _snap();
    } else if (!_canAnimate ||
        HardwareKeyboard.instance.logicalKeysPressed.isNotEmpty) {
      _snap();
    } else if (oldWidget.value != widget.value) {
      final currentY = _incomingY;
      final previousY = _outgoingY;
      final running = !_controller.isCompleted && _outgoing != null;
      if (running && _outgoing == widget.value) {
        // A quick reversal brings the existing token back from its position.
        _incomingStart = previousY;
        _outgoing = oldWidget.value;
        _outgoingStyle = oldWidget.style;
        _outgoingStart = currentY;
        _outgoingEnd = 1;
      } else {
        // Keep the more visible token in place and discard any older layer.
        // Repeated edits therefore never queue up a train of stale results.
        if (!running || currentY.abs() <= previousY.abs()) {
          _outgoing = oldWidget.value;
          _outgoingStyle = oldWidget.style;
          _outgoingStart = currentY;
        } else {
          _outgoingStart = previousY;
        }
        // Adjacent tokens remain a full row apart, even mid-transition.
        _incomingStart = _outgoingStart + 1;
        _outgoingEnd = -1;
      }
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    motionPreferences.removeListener(_motionChanged);
    _controller.dispose();
    super.dispose();
  }

  TextStyle _effectiveStyle(BuildContext context, TextStyle? style) {
    final inherited = DefaultTextStyle.of(context).style
        .merge(style)
        .merge(
          MediaQuery.boldTextOf(context)
              ? const TextStyle(fontWeight: FontWeight.bold)
              : null,
        );
    return inherited.copyWith(
      fontFeatures: [
        ...?inherited.fontFeatures,
        const FontFeature.tabularFigures(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _effectiveStyle(context, widget.style);
    final oldStyle = _effectiveStyle(context, _outgoingStyle);
    final scaler = MediaQuery.textScalerOf(context);
    if (_measuredStyle != style || _measuredScaler != scaler) {
      _slotWidth = 0;
      _measuredStyle = style;
      _measuredScaler = scaler;
    }
    Size measure(String value, TextStyle textStyle) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: textStyle),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        locale: Localizations.maybeLocaleOf(context),
        maxLines: 1,
      )..layout();
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final currentSize = measure(widget.value, style);
    final oldSize = _outgoing == null || _controller.isCompleted
        ? Size.zero
        : measure(_outgoing!, oldStyle);
    // Keep the widest value in this slot so adjacent labels don't jump back
    // when a longer fraction rolls out. Font/scale or identity changes reset it.
    _slotWidth = math.max(
      _slotWidth,
      math.max(currentSize.width, oldSize.width),
    );

    Widget layer(String value, TextStyle textStyle, double y, {Key? textKey}) =>
        Positioned.fill(
          child: FractionalTranslation(
            translation: Offset(0, y),
            child: Center(
              child: Text(
                value,
                key: textKey,
                style: textStyle,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        );

    return Semantics(
      label: widget.value,
      excludeSemantics: true,
      child: SizedBox(
        width: _slotWidth,
        height: math.max(currentSize.height, oldSize.height),
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Stack(
              children: [
                if (_canAnimate &&
                    !_controller.isCompleted &&
                    _outgoing != null)
                  layer(_outgoing!, oldStyle, _outgoingY),
                layer(
                  widget.value,
                  style,
                  _canAnimate ? _incomingY : 0,
                  textKey: widget.textKey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
