import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/dex/type_chart.dart';
import '../features/journey/ask_motion_theme.dart';
import '../theme/tito_colors.dart';

/// An answer was found, no supported answer was found, or a neutral interruption.
enum AskMotionOutcome { caught, escaped, neutral }

/// The small, centered title above an Ask TitoDex answer.
///
/// Props belong to a change of words, so there is no repeating loading animation.
/// A completed answer mounted from history is still; only a live outcome changes
/// the title into the brief catch / escape finish.
class AskAnswerMotionTitle extends StatefulWidget {
  const AskAnswerMotionTitle({
    super.key,
    required this.text,
    required this.theme,
    this.stage = 'lookup',
    this.outcome,
    this.style,
    this.height = 18,
  });

  final String text;
  final AskMotionTheme theme;
  final String stage;
  final AskMotionOutcome? outcome;
  final TextStyle? style;
  final double height;

  @override
  State<AskAnswerMotionTitle> createState() => _AskAnswerMotionTitleState();
}

class _AskAnswerMotionTitleState extends State<AskAnswerMotionTitle>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  String _previous = '';
  bool _active = false;
  bool _reduced = false;
  bool _visible = true;
  bool _foreground = true;
  Size? _lastLayoutSize;
  Object? _layoutInputs;
  _TitleLayout? _layout;
  int _revision = 0;
  int _scheduledRevision = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _motion = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted && _active) {
          setState(() => _active = false);
        }
      });
    _active = widget.outcome == null && widget.text.isNotEmpty;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (_reduced || !_visible || !_foreground) _finish();
  }

  @override
  void didUpdateWidget(covariant AskAnswerMotionTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.text != widget.text ||
        oldWidget.stage != widget.stage ||
        oldWidget.outcome != widget.outcome ||
        oldWidget.theme.topic != widget.theme.topic ||
        oldWidget.theme.kind != widget.theme.kind ||
        !listEquals(oldWidget.theme.assets, widget.theme.assets);
    if (!changed) return;
    _motion.stop();
    _motion.value = 0;
    _revision++;
    _previous = oldWidget.text;
    _active =
        !_reduced &&
        _visible &&
        _foreground &&
        widget.text.isNotEmpty &&
        widget.outcome != AskMotionOutcome.neutral &&
        (widget.outcome == null || oldWidget.outcome != widget.outcome);
  }

  void _finish() {
    _motion.stop();
    _revision++;
    _active = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed && mounted && _active) {
      setState(_finish);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    _layout?.dispose();
    super.dispose();
  }

  _TitleLayout _measureLayout(
    double maxWidth,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final inputs = (
      _previous,
      widget.text,
      maxWidth,
      style,
      scaler,
      direction,
      widget.height,
      widget.theme.kind,
    );
    if (_layout != null && inputs == _layoutInputs) return _layout!;
    var width = maxWidth;
    if (!width.isFinite) {
      final natural = _Label.measure(
        widget.text,
        style,
        scaler,
        direction,
        double.infinity,
      );
      width = math.max(18.0, natural.width);
      natural.painter.dispose();
    }
    final reserve = widget.theme.kind == AskMotionKind.berries && width > 100
        ? 26.0
        : 0.0;
    final layout = _TitleLayout(
      old: _Label.measure(
        _previous,
        style,
        scaler,
        direction,
        math.max(0, width - reserve),
      ),
      fresh: _Label.measure(
        widget.text,
        style,
        scaler,
        direction,
        math.max(0, width - reserve),
      ),
      width: width,
      minimumHeight: widget.height,
    );
    _layout?.dispose();
    _layout = layout;
    _layoutInputs = inputs;
    return layout;
  }

  void _startAfterLayout(Duration duration) {
    if (_scheduledRevision == _revision) return;
    final revision = _revision;
    _scheduledRevision = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_active || revision != _revision) return;
      _motion.duration = duration;
      _motion.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(
      widget.style ??
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: TitoColors.deepBlue.withValues(alpha: .72),
            height: 1.2,
          ),
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return Semantics(
      label: widget.text,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _measureLayout(
              constraints.maxWidth,
              style,
              scaler,
              direction,
            );
            final width = layout.width;
            final size = Size(layout.width, layout.height);
            if (_lastLayoutSize != null && _lastLayoutSize != size && _active) {
              // Resizing should not change the speed halfway through a roll.
              _finish();
            }
            _lastLayoutSize = size;
            if (!_active) {
              return SizedBox(
                width: width,
                height: layout.height,
                child: Center(
                  child: SizedBox(
                    width: layout.fresh.width,
                    child: Text(
                      widget.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: style,
                    ),
                  ),
                ),
              );
            }
            final duration = _duration(
              layout,
              widget.theme.kind,
              widget.outcome,
              widget.theme.assets.length,
            );
            _startAfterLayout(
              Duration(microseconds: (duration * 1000).round()),
            );
            return SizedBox(
              width: width,
              height: layout.height,
              child: AnimatedBuilder(
                animation: _motion,
                builder: (context, child) {
                  final ms = _motion.value * duration;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _TitlePainter(
                            layout: layout,
                            kind: widget.theme.kind,
                            outcome: widget.outcome,
                            ms: ms,
                            duration: duration,
                          ),
                        ),
                      ),
                      ..._props(layout, ms, duration),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _props(_TitleLayout layout, double ms, double duration) {
    final center = layout.width / 2;
    final top = (layout.height - 18) / 2;
    final assets = widget.theme.assets.isEmpty
        ? const ['assets/ask_motion/sonias-book.png']
        : widget.theme.assets;
    if (widget.outcome == AskMotionOutcome.caught ||
        widget.outcome == AskMotionOutcome.escaped) {
      final opacity = _segment(ms, 70, 180) * (1 - _segment(ms, 850, 1040));
      final rock =
          math.sin(_clamp((ms - 190) / 470) * math.pi * 4) *
          9 *
          (1 - _segment(ms, 190, 700));
      return [
        Positioned(
          left: center - 9,
          top: top - 2 * (1 - _segment(ms, 90, 210)),
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: rock * math.pi / 180,
              alignment: const Alignment(0, .7),
              child: _OutcomeBall(outcome: widget.outcome!, ms: ms),
            ),
          ),
        ),
      ];
    }
    switch (widget.theme.kind) {
      case AskMotionKind.ball:
        final travel = math.min(layout.ballDistance, ms / 1000 * 48);
        final x = layout.ballStart + travel;
        return [
          Positioned(
            left: 0,
            top: top,
            child: Transform.translate(
              key: const ValueKey('ask-motion-ball-position'),
              offset: Offset(x - 9, 0),
              child: Opacity(
                opacity: _clamp(math.min(ms / 130, (duration - ms) / 130)),
                child: Transform.rotate(
                  key: const ValueKey('ask-motion-ball-rotation'),
                  angle: travel / 7.2,
                  child: const _PropImage(
                    asset: 'assets/ask_motion/poke-ball.png',
                  ),
                ),
              ),
            ),
          ),
        ];
      case AskMotionKind.book:
      case AskMotionKind.map:
        final spread = _segment(ms, 170, 420) * (1 - _segment(ms, 760, 960));
        final page = _segment(
          ms,
          widget.stage == 'verify' ? 470 : 420,
          widget.stage == 'organize' ? 660 : 730,
        );
        final subject = widget.theme.kind == AskMotionKind.book
            ? assets
                  .where((path) => !path.endsWith('sonias-book.png'))
                  .firstOrNull
            : null;
        return [
          Positioned(
            left: center - 12,
            top: top,
            child: Opacity(
              opacity: _segment(ms, 140, 310) * (1 - _segment(ms, 800, 970)),
              child: SizedBox(
                key: ValueKey('ask-motion-${widget.theme.kind.name}'),
                width: 24,
                height: 18,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _BookPainter(
                          spread: spread,
                          page: page,
                          pageOpacity:
                              _segment(ms, 380, 450) *
                              (1 - _segment(ms, 690, 760)),
                          map: widget.theme.kind == AskMotionKind.map,
                        ),
                      ),
                    ),
                    if (subject != null)
                      Positioned(
                        top: 4,
                        right: 2,
                        child: Opacity(
                          opacity: spread * .9,
                          child: _PropImage(asset: subject, size: 8),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ];
      case AskMotionKind.berry:
      case AskMotionKind.berries:
        final landings = _landings(layout, widget.theme.kind);
        return [
          for (var i = 0; i < landings.length; i++)
            _fruit(assets[i % assets.length], landings[i], top, ms, i),
        ];
      case AskMotionKind.emblems:
        final keys = assets.take(2).toList(growable: false);
        final spread = _segment(ms, 160, 390);
        final collect = _segment(ms, 620, 810);
        final gap = widget.stage == 'verify' ? 12.0 : 15.0;
        return [
          for (var i = 0; i < keys.length; i++)
            Positioned(
              left:
                  center -
                  9 +
                  (keys.length == 1 ? 0 : (i == 0 ? -1 : 1)) *
                      gap *
                      spread *
                      (1 - collect),
              top: top - 1.5 * (1 - spread),
              child: Opacity(
                opacity:
                    _segment(ms, 160 + i * 45, 320 + i * 45) *
                    (1 - _segment(ms, 690, 860)),
                child: _PropImage(
                  key: ValueKey('ask-motion-emblem-$i'),
                  asset: keys[i],
                ),
              ),
            ),
        ];
      case AskMotionKind.tokens:
        // A short title has room for a brief exchange, not an inventory parade.
        final keys = assets.take(3).toList(growable: false);
        return [
          for (var i = 0; i < keys.length; i++)
            Positioned(
              left: center - 9,
              top: top,
              child: Opacity(
                opacity:
                    _segment(ms, 170 + i * 230, 330 + i * 230) *
                    (1 -
                        _segment(
                          ms,
                          keys.length == 1 ? 540 : 380 + i * 230,
                          keys.length == 1 ? 690 : 530 + i * 230,
                        )),
                child: _PropImage(
                  key: ValueKey('ask-motion-token-$i'),
                  asset: keys[i],
                ),
              ),
            ),
        ];
    }
  }

  Widget _fruit(String asset, _Landing landing, double top, double ms, int i) {
    final fall = _clamp(
      (ms - landing.start) / (landing.impact - landing.start),
    );
    final rebound = ms < landing.impact
        ? 0.0
        : -2 * math.sin(math.pi * _clamp((ms - landing.impact) / 180));
    return Positioned(
      left: landing.x - 9,
      top: top - 12 + 12 * fall * fall + rebound,
      child: Opacity(
        opacity:
            _segment(ms, landing.start, landing.start + 100) *
            (1 - _segment(ms, landing.impact + 90, landing.impact + 270)),
        child: _PropImage(key: ValueKey('ask-motion-berry-$i'), asset: asset),
      ),
    );
  }
}

double _clamp(double value) => value.clamp(0.0, 1.0);
double _segment(double ms, num from, num to) {
  final t = _clamp((ms - from) / (to - from));
  return t * t * (3 - 2 * t);
}

double _duration(
  _TitleLayout layout,
  AskMotionKind kind,
  AskMotionOutcome? outcome,
  int assetCount,
) {
  if (outcome != null) return 1180;
  return switch (kind) {
    AskMotionKind.ball => layout.ballDistance / 48 * 1000,
    AskMotionKind.book || AskMotionKind.map => 1260,
    AskMotionKind.berry || AskMotionKind.berries => math.max(
      1000,
      layout.fresh.characterCenters.fold<double>(0, (last, x) {
            final arrival = _arrival(layout, kind, x);
            return math.max(last, arrival);
          }) +
          210,
    ),
    AskMotionKind.emblems => 1050,
    AskMotionKind.tokens => assetCount > 1 ? 1280 : 960,
  };
}

class _Label {
  _Label(this.text, this.painter);

  factory _Label.measure(
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    return _Label(text, painter);
  }

  final String text;
  final TextPainter painter;
  double get width => painter.width;
  double get height => painter.height;
  // The wave reaches its farthest point at an edge or near the center.
  List<double> get characterCenters => [0, width / 2, width];
}

class _TitleLayout {
  _TitleLayout({
    required this.old,
    required this.fresh,
    required this.width,
    required double minimumHeight,
  }) : height = math.max(minimumHeight, math.max(old.height, fresh.height));

  final _Label old;
  final _Label fresh;
  final double width;
  final double height;
  double left(_Label label) => (width - label.width) / 2;
  double get spanWidth => math.max(old.width, fresh.width);
  double get ballStart => (width - spanWidth) / 2 - 7.2;
  double get ballDistance => spanWidth + 14.4;
  void dispose() {
    old.painter.dispose();
    fresh.painter.dispose();
  }
}

class _Landing {
  const _Landing(this.x, this.start, this.impact);
  final double x;
  final double start;
  final double impact;
}

List<_Landing> _landings(_TitleLayout layout, AskMotionKind kind) {
  if (kind == AskMotionKind.berry) {
    return [_Landing(layout.width / 2, 100, 410)];
  }
  return [
    _Landing(layout.width < 100 ? 7 : layout.left(layout.fresh) - 7, 100, 410),
    _Landing(
      layout.width < 100
          ? layout.width - 7
          : layout.left(layout.fresh) + layout.fresh.width + 7,
      190,
      500,
    ),
  ];
}

double _arrival(_TitleLayout layout, AskMotionKind kind, double localX) {
  final x = localX + layout.left(layout.fresh);
  return _landings(layout, kind)
      .map(
        (landing) => landing.impact + 80 + (x - landing.x).abs() / 220 * 1000,
      )
      .reduce(math.min);
}

class _TitlePainter extends CustomPainter {
  const _TitlePainter({
    required this.layout,
    required this.kind,
    required this.outcome,
    required this.ms,
    required this.duration,
  });

  final _TitleLayout layout;
  final AskMotionKind kind;
  final AskMotionOutcome? outcome;
  final double ms;
  final double duration;

  void _draw(Canvas canvas, _Label label, {double opacity = 1, Rect? clip}) {
    if (opacity <= 0 || label.text.isEmpty) return;
    final bounds = Rect.fromLTWH(0, 0, layout.width, layout.height);
    canvas.save();
    canvas.clipRect(clip?.intersect(bounds) ?? bounds);
    if (opacity < 1) {
      canvas.saveLayer(
        bounds,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
    label.painter.paint(
      canvas,
      Offset(layout.left(label), (layout.height - label.height) / 2),
    );
    if (opacity < 1) canvas.restore();
    canvas.restore();
  }

  Rect _centerClip(_Label label, double fraction) => Rect.fromCenter(
    center: Offset(layout.width / 2, layout.height / 2),
    width: label.width * fraction,
    height: layout.height,
  );

  void _centerReveal(Canvas canvas, double fraction) {
    _draw(
      canvas,
      layout.fresh,
      opacity: fraction,
      clip: _centerClip(layout.fresh, fraction),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (outcome != null) {
      _draw(canvas, layout.old, opacity: 1 - _segment(ms, 0, 160));
      _centerReveal(canvas, _segment(ms, 820, 1180));
      return;
    }
    switch (kind) {
      case AskMotionKind.ball:
        final x =
            layout.ballStart + math.min(layout.ballDistance, ms / 1000 * 48);
        final edge = x.clamp(0.0, layout.width);
        _draw(
          canvas,
          layout.old,
          clip: Rect.fromLTRB(edge, 0, layout.width, layout.height),
        );
        _draw(
          canvas,
          layout.fresh,
          clip: Rect.fromLTRB(0, 0, edge, layout.height),
        );
      case AskMotionKind.book:
      case AskMotionKind.map:
        _draw(
          canvas,
          layout.old,
          opacity: 1 - _segment(ms, 160, 290),
          clip: _centerClip(layout.old, 1 - _segment(ms, 0, 290)),
        );
        _centerReveal(canvas, _segment(ms, 850, 1260));
      case AskMotionKind.berry:
      case AskMotionKind.berries:
        _draw(canvas, layout.old, opacity: 1 - _segment(ms, 0, 230));
        // Mask the shaped text once; per-letter offscreen layers are expensive
        // on the handheld and would break combining marks and the ellipsis.
        final left = layout.left(layout.fresh);
        if (layout.fresh.width > 0) {
          final bounds = Rect.fromLTWH(
            left,
            0,
            layout.fresh.width,
            layout.height,
          );
          final stops = List<double>.generate(25, (i) => i / 24);
          canvas.saveLayer(bounds, Paint());
          _draw(canvas, layout.fresh);
          canvas.drawRect(
            bounds,
            Paint()
              ..blendMode = BlendMode.dstIn
              ..shader = LinearGradient(
                stops: stops,
                colors: [
                  for (final stop in stops)
                    Colors.white.withValues(
                      alpha: _segment(
                        ms,
                        _arrival(layout, kind, stop * layout.fresh.width),
                        _arrival(layout, kind, stop * layout.fresh.width) + 210,
                      ),
                    ),
                ],
              ).createShader(bounds),
          );
          canvas.restore();
        }
      case AskMotionKind.emblems:
        _draw(canvas, layout.old, opacity: 1 - _segment(ms, 0, 210));
        _centerReveal(canvas, _segment(ms, 720, 1050));
      case AskMotionKind.tokens:
        _draw(canvas, layout.old, opacity: 1 - _segment(ms, 0, 210));
        _centerReveal(canvas, _segment(ms, duration - 300, duration));
    }
  }

  @override
  bool shouldRepaint(covariant _TitlePainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.ms != ms ||
      oldDelegate.kind != kind ||
      oldDelegate.outcome != outcome;
}

class _PropImage extends StatelessWidget {
  const _PropImage({super.key, required this.asset, this.size = 18});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    final type = asset.startsWith('assets/type_icons/')
        ? asset.split('/').last.replaceAll('.png', '')
        : null;
    return Container(
      width: size,
      height: size,
      padding: type == null ? EdgeInsets.zero : EdgeInsets.all(size / 6),
      decoration: type == null
          ? null
          : BoxDecoration(color: typeTileColor(type), shape: BoxShape.circle),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: type == null ? FilterQuality.none : FilterQuality.low,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) => const CustomPaint(
          painter: _BookPainter(spread: 1, page: 0, pageOpacity: 0),
        ),
      ),
    );
  }
}

class _BookPainter extends CustomPainter {
  const _BookPainter({
    required this.spread,
    required this.page,
    required this.pageOpacity,
    this.map = false,
  });

  final double spread;
  final double page;
  final double pageOpacity;
  final bool map;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 18);
    final angle = (1 - spread) * 82 * math.pi / 180;
    final w = 11 * math.cos(angle);
    final border = Paint()
      ..color = const Color(0xFF648B85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final paper = Paint()..color = const Color(0xFFF0EEDC);
    void leaf(double left, double width, {bool back = false}) {
      final shape = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 2, width, 14),
        const Radius.circular(1.2),
      );
      canvas.drawRRect(shape, paper);
      canvas.drawRRect(shape, border);
      canvas.save();
      canvas.clipRRect(shape);
      if (map) {
        final river = Path()
          ..moveTo(left + width * .2, 3)
          ..cubicTo(left + width * .8, 6, left, 10, left + width * .8, 15);
        canvas.drawPath(
          river,
          Paint()
            ..color = const Color(0xFF9ABCBF)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
        final route = Path()
          ..moveTo(left, 12)
          ..lineTo(left + width * .5, 8)
          ..lineTo(left + width, 9);
        canvas.drawPath(
          route,
          Paint()
            ..color = const Color(0xFFB7A878)
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
        );
        canvas.drawCircle(
          Offset(left + width * .5, 8),
          .9,
          Paint()..color = const Color(0xFF648B85),
        );
      } else {
        for (var y = 5.0; y < 13; y += 3) {
          canvas.drawLine(
            Offset(left + 2, y),
            Offset(left + width - 2, y),
            Paint()
              ..color = const Color(0xFFA2ABA0)
              ..strokeWidth = .65,
          );
        }
      }
      canvas.restore();
    }

    leaf(12 - w, w);
    leaf(12, w);
    if (!map && pageOpacity > 0) {
      canvas.saveLayer(
        const Rect.fromLTWH(0, 0, 24, 18),
        Paint()..color = Colors.white.withValues(alpha: pageOpacity),
      );
      final turnWidth = 11 * math.cos(math.pi * page);
      leaf(turnWidth >= 0 ? 12 : 12 + turnWidth, turnWidth.abs());
      canvas.restore();
    }
    canvas.drawLine(
      const Offset(12, 3),
      const Offset(12, 15),
      Paint()
        ..color = const Color(0xFF849B8D)
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BookPainter oldDelegate) =>
      oldDelegate.spread != spread ||
      oldDelegate.page != page ||
      oldDelegate.pageOpacity != pageOpacity ||
      oldDelegate.map != map;
}

class _OutcomeBall extends StatelessWidget {
  const _OutcomeBall({required this.outcome, required this.ms});
  final AskMotionOutcome outcome;
  final double ms;

  @override
  Widget build(BuildContext context) {
    final caught = outcome == AskMotionOutcome.caught;
    final open = caught ? 0.0 : _segment(ms, 450, 650);
    Widget half(bool upper) => ClipRect(
      clipper: _BallHalfClipper(upper),
      child: const _PropImage(asset: 'assets/ask_motion/poke-ball.png'),
    );
    return SizedBox(
      key: ValueKey('ask-motion-${outcome.name}'),
      width: 18,
      height: 18,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Transform.translate(offset: Offset(0, open), child: half(false)),
          Transform.translate(
            offset: Offset(0, -3 * open),
            child: Transform.rotate(
              key: const ValueKey('ask-motion-ball-lid'),
              angle: -24 * open * math.pi / 180,
              alignment: const Alignment(-.6, 0),
              child: half(true),
            ),
          ),
          if (caught)
            Positioned(
              left: 7,
              top: 7,
              child: Opacity(
                opacity: _segment(ms, 580, 650) * (1 - _segment(ms, 730, 870)),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFFA6C9A5),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          for (var i = 0; i < (caught ? 2 : 1); i++) _glint(caught, i),
        ],
      ),
    );
  }

  Widget _glint(bool caught, int i) {
    final p = _segment(ms, 610 + i * 40, 870 + i * 40);
    final x = caught ? (i == 0 ? -1 : 1) * (9 + p * 3) : 0.0;
    final y = caught ? -3 - p * 2 : -8 * _segment(ms, 540, 880);
    final scale = caught ? .65 + p * .25 : 1 - _segment(ms, 600, 900) * .7;
    final opacity = caught
        ? math.sin(p * math.pi) * .8
        : _segment(ms, 500, 600) * (1 - _segment(ms, 650, 880));
    return Positioned(
      left: 8 + x,
      top: 6 + y,
      child: Opacity(
        opacity: _clamp(opacity),
        child: Transform.scale(
          scale: scale,
          child: const CustomPaint(size: Size(3, 5), painter: _GlintPainter()),
        ),
      ),
    );
  }
}

class _BallHalfClipper extends CustomClipper<Rect> {
  const _BallHalfClipper(this.upper);
  final bool upper;

  @override
  Rect getClip(Size size) => upper
      ? Rect.fromLTRB(0, 0, size.width, size.height * .51)
      : Rect.fromLTRB(0, size.height * .49, size.width, size.height);

  @override
  bool shouldReclip(covariant _BallHalfClipper oldClipper) =>
      oldClipper.upper != upper;
}

class _GlintPainter extends CustomPainter {
  const _GlintPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .5, 0)
      ..lineTo(size.width * .65, size.height * .35)
      ..lineTo(size.width, size.height * .5)
      ..lineTo(size.width * .65, size.height * .65)
      ..lineTo(size.width * .5, size.height)
      ..lineTo(size.width * .35, size.height * .65)
      ..lineTo(0, size.height * .5)
      ..lineTo(size.width * .35, size.height * .35)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFB4CBB1));
  }

  @override
  bool shouldRepaint(covariant _GlintPainter oldDelegate) => false;
}
