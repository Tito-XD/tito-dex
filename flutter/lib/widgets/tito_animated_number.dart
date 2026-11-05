import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/motion_preferences.dart';
import '../theme/number_style_preferences.dart';
import '../theme/tito_motion.dart';
import 'tito_retro_digits.dart';

/// An odometer for one visible metric. When the value changes only the
/// characters that differ roll, each exactly one step from its old glyph to its
/// new one (never through the digits in between): 120 → 136 rolls the "20" to
/// "36", 136 → 236 rolls only the hundreds, 236 → 210 rolls the "36" down to
/// "10". Glyphs roll up when the value grows and down when it shrinks. With
/// [countUp] the first presentation (and a new [identity]) rolls in from zero.
///
/// [identity] names the metric slot for as long as its page lives. The last
/// value shown per identity is remembered, so a slot that is rebuilt (a range
/// gaining its minimum, a card that briefly had no result) rolls on from what
/// it showed instead of counting up from zero again.
/// Assistive technology and every caller read [value]; the rolling frames are
/// decoration. App/system reduced motion, hidden tabs and held keys show the
/// final value at once.
class TitoAnimatedNumber extends StatefulWidget {
  const TitoAnimatedNumber({
    super.key,
    required this.value,
    required this.identity,
    this.style,
    this.textKey,
    this.fractionDigits = 0,
    this.suffix = '',
    this.countUp = false,
    this.retro = false,
  });

  final num value;
  final Object identity;
  final TextStyle? style;

  /// Key of the plain [Text] painted at rest.
  final Key? textKey;

  /// Digits after the decimal point, for percentages such as `29.7`.
  final int fractionDigits;

  /// Appended after the number (`%`, `×`); rolls only if it changes.
  final String suffix;

  /// Roll in from zero when the result first appears or its subject changes.
  final bool countUp;

  /// Opt in to the experimental glyph style chosen in Settings (segment, dot
  /// matrix, pixel, split flap). Only hero numbers pass this; with the
  /// standard style, or when false, the number is drawn exactly as before.
  final bool retro;

  @override
  State<TitoAnimatedNumber> createState() => TitoAnimatedNumberState();
}

@visibleForTesting
class TitoAnimatedNumberState extends State<TitoAnimatedNumber>
    with SingleTickerProviderStateMixin {
  /// Last value painted per identity; bounded, oldest dropped first.
  static final _memory = <Object, num>{};

  /// Forgets every remembered value, so tests start from a clean slate.
  @visibleForTesting
  static void debugResetMemory() => _memory.clear();

  static void _remember(Object identity, num value) {
    _memory.remove(identity);
    _memory[identity] = value;
    if (_memory.length > 128) _memory.remove(_memory.keys.first);
  }

  late final AnimationController _controller;
  List<_Wheel> _wheels = const [];
  bool _tickerEnabled = true;
  bool _systemReduced = false;
  bool _entered = false;
  Curve _curve = Curves.easeOutCubic;
  final _widths = <String, double>{};
  TextStyle? _measuredStyle;
  TextScaler? _measuredScaler;

  bool get _canAnimate =>
      _tickerEnabled &&
      !_systemReduced &&
      motionPreferences.listAnimationsEnabled;

  bool get _rolling => _controller.isAnimating && _wheels.isNotEmpty;

  /// What the wheels show right now (nearest glyph per wheel); the final text
  /// at rest. Lets tests follow the roll without reading pixels.
  @visibleForTesting
  String get displayedText {
    if (!_rolling) return _text(widget.value);
    final t = _curve.transform(_controller.value);
    return _wheels.map((w) => w.glyphAt(t)).join();
  }

  String _text(num value) {
    final number = widget.fractionDigits == 0
        ? '${value.round()}'
        : value.toDouble().toStringAsFixed(widget.fractionDigits);
    return '$number${widget.suffix}';
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: 1)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _wheels = const []);
        }
      });
    motionPreferences.addListener(_motionChanged);
    if (widget.retro) numberStylePreferences.addListener(_styleChanged);
  }

  void _styleChanged() {
    if (mounted) setState(_snap);
  }

  void _snap() {
    _wheels = const [];
    _controller.value = 1;
  }

  void _roll(String from, String to, {required bool up, required bool entry}) {
    if (from == to) return _snap();
    _wheels = _Wheel.between(from, to, up: up);
    _curve = entry ? Curves.easeOutQuart : Curves.easeOutCubic;
    _controller.duration = entry ? TitoMotion.countUp : TitoMotion.odometer;
    _controller.forward(from: 0);
  }

  /// Entrance for a new slot: roll on from what this identity showed last,
  /// or count up from zero the first time it appears.
  void _countUp() {
    final last = _memory[widget.identity];
    if (last != null) {
      _roll(
        _text(last),
        _text(widget.value),
        up: widget.value >= last,
        entry: false,
      );
    } else if (widget.value != 0) {
      _roll(_text(0), _text(widget.value), up: widget.value >= 0, entry: true);
    }
  }

  void _motionChanged() {
    if (!_canAnimate) setState(_snap);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _systemReduced = MediaQuery.disableAnimationsOf(context);
    if (!_canAnimate) {
      _snap();
    } else if (!_entered && widget.countUp) {
      _countUp();
    }
    _entered = true;
    _remember(widget.identity, widget.value);
  }

  @override
  void didUpdateWidget(covariant TitoAnimatedNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.retro != widget.retro) {
      widget.retro
          ? numberStylePreferences.addListener(_styleChanged)
          : numberStylePreferences.removeListener(_styleChanged);
    }
    _update(oldWidget);
    _remember(widget.identity, widget.value);
  }

  void _update(TitoAnimatedNumber oldWidget) {
    if (oldWidget.identity != widget.identity) {
      // A new subject is a new result: roll it in (activation keys such as A
      // may still be down here, so they don't suppress the entrance).
      if (widget.countUp && _canAnimate) {
        _snap();
        _countUp();
      } else {
        _snap();
      }
    } else if (!_canAnimate ||
        HardwareKeyboard.instance.logicalKeysPressed.isNotEmpty) {
      // Held arrows repeat edits faster than any animation could follow.
      _snap();
    } else if (_text(oldWidget.value) != _text(widget.value) ||
        oldWidget.suffix != widget.suffix) {
      // Continue from what is painted, including an interrupted roll.
      final from = _rolling
          ? displayedText
          : '${_numberOnly(oldWidget)}${oldWidget.suffix}';
      _roll(
        from,
        _text(widget.value),
        up: widget.value >= oldWidget.value,
        entry: false,
      );
    }
  }

  String _numberOnly(TitoAnimatedNumber w) => w.fractionDigits == 0
      ? '${w.value.round()}'
      : w.value.toDouble().toStringAsFixed(w.fractionDigits);

  @override
  void dispose() {
    motionPreferences.removeListener(_motionChanged);
    numberStylePreferences.removeListener(_styleChanged);
    _controller.dispose();
    super.dispose();
  }

  double _width(String glyph, TextStyle style, TextScaler scaler) {
    if (glyph.isEmpty) return 0;
    return _widths.putIfAbsent(glyph, () {
      final painter = TextPainter(
        text: TextSpan(text: glyph, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    });
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final style = base.copyWith(
      fontFeatures: [...?base.fontFeatures, const FontFeature.tabularFigures()],
    );
    final scaler = MediaQuery.textScalerOf(context);
    if (_measuredStyle != style || _measuredScaler != scaler) {
      _widths.clear();
      _measuredStyle = style;
      _measuredScaler = scaler;
    }
    final finalText = _text(widget.value);
    return Semantics(
      label: finalText,
      // Rolling frames are decoration; assistive technology reads the result.
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final retro = widget.retro
              ? numberStylePreferences.style
              : TitoNumberStyle.standard;
          if (retro != TitoNumberStyle.standard &&
              titoRetroSupports(finalText)) {
            final rolling = _canAnimate && _rolling;
            if (!rolling) {
              return KeyedSubtree(
                key: widget.textKey,
                child: TitoRetroNumber(
                  numberStyle: retro,
                  slots: TitoRetroNumber.restSlots(finalText),
                  style: style,
                ),
              );
            }
            final slots = [for (final w in _wheels) w.retroSlot];
            if (slots.every((s) => titoRetroSupports(s.from + s.to))) {
              return TitoRetroNumber(
                numberStyle: retro,
                slots: slots,
                style: style,
                t: _curve.transform(_controller.value),
                up: _wheels.first.up,
              );
            }
          }
          if (!_canAnimate || !_rolling) {
            return Text(
              finalText,
              key: widget.textKey,
              maxLines: 1,
              softWrap: false,
              style: style,
            );
          }
          final t = _curve.transform(_controller.value);
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              for (final wheel in _wheels)
                wheel.build(t, style, (g) => _width(g, style, scaler)),
            ],
          );
        },
      ),
    );
  }
}

/// One character slot. A still slot keeps its glyph; a changed slot (digit,
/// sign, a new leading digit appearing, decimal point) rolls exactly one step
/// from its old glyph to its new one, never through the digits in between.
class _Wheel {
  _Wheel(this.glyphs, {required this.up});

  /// Glyph per step, first = old, last = new. '' is an empty slot.
  final List<String> glyphs;
  final bool up;

  int get steps => glyphs.length - 1;

  /// This slot's old and new glyph for the retro styles.
  TitoRetroSlot get retroSlot => TitoRetroSlot(glyphs.first, glyphs.last);

  String glyphAt(double t) => glyphs[(t * steps).round().clamp(0, steps)];

  static List<_Wheel> between(String from, String to, {required bool up}) {
    // Right-align so ones line up with ones and the suffix with the suffix.
    final length = from.length > to.length ? from.length : to.length;
    final a = from.padLeft(length);
    final b = to.padLeft(length);
    return [for (var i = 0; i < length; i++) _Wheel.slot(a[i], b[i], up: up)];
  }

  factory _Wheel.slot(String a, String b, {required bool up}) {
    if (a == b) return _Wheel([a == ' ' ? '' : a], up: up);
    return _Wheel([a == ' ' ? '' : a, b == ' ' ? '' : b], up: up);
  }

  Widget build(double t, TextStyle style, double Function(String) widthOf) {
    if (steps == 0) {
      return Text(glyphs.single, style: style, maxLines: 1, softWrap: false);
    }
    final position = t * steps;
    final width =
        widthOf(glyphs.first) +
        (widthOf(glyphs.last) - widthOf(glyphs.first)) * t;
    // An empty line sets the slot height and baseline; glyphs are laid out
    // at its top-left and only translated while painting.
    return SizedBox(
      width: width,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text('', style: style, maxLines: 1),
            for (var k = 0; k <= steps; k++)
              if ((k - position).abs() < 1.05)
                Positioned(
                  left: (width - widthOf(glyphs[k])) / 2,
                  top: 0,
                  child: FractionalTranslation(
                    // Rolling up, later digits wait below; down, above.
                    translation: Offset(0, (up ? 1 : -1) * (k - position)),
                    child: Text(
                      glyphs[k],
                      style: style,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
