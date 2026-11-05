import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/number_style_preferences.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_surface_tokens.dart';

/// One character position of a retro number: [from] rolls to [to] (equal for a
/// still character). '' is an empty slot (padding before a new leading digit).
@immutable
class TitoRetroSlot {
  const TitoRetroSlot(this.from, this.to);

  final String from;
  final String to;

  bool get still => from == to;
}

/// 5-column bitmap font (7 rows, MSB = left column) shared by the dot-matrix
/// and pixel styles.
class _Bitmap {
  const _Bitmap(this.cols, this.rows);

  final int cols;
  final List<int> rows;
}

const _blank = _Bitmap(0, [0, 0, 0, 0, 0, 0, 0]);

const _bitmaps = <String, _Bitmap>{
  '0': _Bitmap(5, [14, 17, 19, 21, 25, 17, 14]),
  '1': _Bitmap(5, [4, 12, 4, 4, 4, 4, 14]),
  '2': _Bitmap(5, [14, 17, 1, 2, 4, 8, 31]),
  '3': _Bitmap(5, [31, 2, 4, 2, 1, 17, 14]),
  '4': _Bitmap(5, [2, 6, 10, 18, 31, 2, 2]),
  '5': _Bitmap(5, [31, 16, 30, 1, 1, 17, 14]),
  '6': _Bitmap(5, [6, 8, 16, 30, 17, 17, 14]),
  '7': _Bitmap(5, [31, 1, 2, 4, 8, 8, 8]),
  '8': _Bitmap(5, [14, 17, 17, 14, 17, 17, 14]),
  '9': _Bitmap(5, [14, 17, 17, 15, 1, 2, 12]),
  '.': _Bitmap(2, [0, 0, 0, 0, 0, 3, 3]),
  '%': _Bitmap(5, [25, 26, 2, 4, 8, 11, 19]),
  '-': _Bitmap(5, [0, 0, 0, 14, 0, 0, 0]),
  '–': _Bitmap(5, [0, 0, 0, 31, 0, 0, 0]),
  '×': _Bitmap(5, [0, 17, 10, 4, 10, 17, 0]),
  '/': _Bitmap(5, [1, 1, 2, 4, 8, 16, 16]),
  ' ': _Bitmap(3, [0, 0, 0, 0, 0, 0, 0]),
};

// Segment bits: a top, b top-right, c bottom-right, d bottom, e bottom-left,
// f top-left, g middle; then the extras used by punctuation.
const _segDot = 128;
const _segSlash = 256;
const _segBack = 512;
const _segPctTop = 1024;
const _segPctBottom = 2048;
const _segCross = 4096;

const _segmentMasks = <String, int>{
  '0': 63,
  '1': 6,
  '2': 91,
  '3': 79,
  '4': 102,
  '5': 109,
  '6': 125,
  '7': 7,
  '8': 127,
  '9': 111,
  '-': 64,
  '–': 64,
  '.': _segDot,
  '%': _segSlash | _segPctTop | _segPctBottom,
  '×': _segCross | _segBack,
  '/': _segSlash,
  ' ': 0,
};

/// Whether every character of [text] has a retro glyph; otherwise callers
/// fall back to the normal font.
bool titoRetroSupports(String text) {
  for (var i = 0; i < text.length; i++) {
    if (!_bitmaps.containsKey(text[i])) return false;
  }
  return true;
}

/// Sizes derived from the scaled font size: the glyph cell is about one font
/// size tall and ~0.6 as wide (split-flap tiles ~0.7 of their height).
class _Metrics {
  const _Metrics(this.style, this.finish, this.size);

  final TitoNumberStyle style;
  final TitoSurfaceFinish finish;
  final double size;

  double get glyph => size * .86;
  double get tile => size * 1.02;
  double get segWidth => glyph * .56;
  double get pitchY => glyph / 7;
  double get pitchX => glyph * .12;
  double get thickness =>
      glyph *
      switch (finish) {
        TitoSurfaceFinish.paper => .105,
        TitoSurfaceFinish.plastic => .125,
        TitoSurfaceFinish.material => .1,
      };
  double get gap => switch (style) {
    TitoNumberStyle.segment => glyph * .2,
    TitoNumberStyle.splitFlap => tile * .08,
    _ => glyph * .16,
  };

  /// Drawn width of one glyph, without the gap after it.
  double body(String ch) {
    if (ch.isEmpty) return 0;
    return switch (style) {
      TitoNumberStyle.segment => switch (ch) {
        '.' => thickness * 1.6,
        ' ' => glyph * .25,
        '%' => segWidth * 1.1,
        '×' => segWidth * .9,
        '/' => segWidth * .7,
        _ => segWidth,
      },
      TitoNumberStyle.splitFlap => switch (ch) {
        '.' => tile * .34,
        ' ' => tile * .4,
        _ => tile * .7,
      },
      _ => (_bitmaps[ch] ?? _blank).cols * pitchX,
    };
  }

  double advance(String ch) => ch.isEmpty ? 0 : body(ch) + gap;

  double width(TitoRetroSlot slot, double t) => slot.still
      ? advance(slot.to)
      : lerpDouble(advance(slot.from), advance(slot.to), t)!;
}

/// Colours and edges for one number, all taken from the active theme tokens
/// and the text colour it inherits.
class _Look {
  const _Look({
    required this.color,
    required this.unlit,
    required this.tileFill,
    required this.outline,
    required this.highlight,
    required this.shadows,
    required this.shade,
    required this.textStyle,
  });

  final Color color;
  final Color unlit;
  final Color tileFill;
  final BorderSide outline;
  final Color highlight;
  final List<BoxShadow> shadows;
  final Color shade;
  final TextStyle textStyle;

  factory _Look.resolve(
    BuildContext context,
    TitoSurfaceTokens tokens,
    TextStyle style,
  ) {
    final color =
        style.color ??
        DefaultTextStyle.of(context).style.color ??
        tokens.surface(TitoSurfaceRole.card).foreground;
    final finish = tokens.finish;
    // Light digits sit on a deep card: take a plate darker than it. Dark
    // digits sit on a cream card: take the pale inset plate.
    final plate = color.computeLuminance() > .5
        ? Color.lerp(
            tokens.surface(TitoSurfaceRole.deep).fill,
            TitoColors.ink,
            .4,
          )!
        : tokens.surface(TitoSurfaceRole.inset).fill;
    return _Look(
      color: color,
      unlit: color.withValues(alpha: color.a * .14),
      tileFill: plate,
      outline: finish == TitoSurfaceFinish.material
          ? BorderSide.none
          : BorderSide(
              color: color.withValues(alpha: color.a * .3),
              width: finish == TitoSurfaceFinish.paper
                  ? TitoBorders.journalHairline
                  : TitoBorders.element,
            ),
      highlight: tokens.surface(TitoSurfaceRole.knob).fill,
      shadows: finish == TitoSurfaceFinish.plastic
          ? tokens.elementShadow
          : const [],
      shade: TitoColors.ink,
      textStyle: style.copyWith(color: color, height: 1, shadows: const []),
    );
  }
}

/// A number drawn with a retro glyph style. [slots] carry each character's old
/// and new glyph; [t] (0..1, already eased) is the roll progress and [up] the
/// direction (value growing). Colours come from the inherited text colour and
/// the theme's surface tokens.
class TitoRetroNumber extends StatelessWidget {
  const TitoRetroNumber({
    super.key,
    required this.numberStyle,
    required this.slots,
    required this.style,
    this.t = 1,
    this.up = true,
  });

  /// Slots for text at rest (no character is rolling).
  static List<TitoRetroSlot> restSlots(String text) => [
    for (var i = 0; i < text.length; i++) TitoRetroSlot(text[i], text[i]),
  ];

  final TitoNumberStyle numberStyle;
  final List<TitoRetroSlot> slots;
  final TextStyle style;
  final double t;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final tokens = TitoSurfaceTokens.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final size = scaler.scale(style.fontSize ?? 14);
    final metrics = _Metrics(numberStyle, tokens.finish, size);
    var width = 0.0;
    for (final slot in slots) {
      width += metrics.width(slot, t);
    }
    width = math.max(0, width - metrics.gap);
    return SizedBox(
      width: width,
      // The empty line sets the box height and the text baseline, so the
      // number sits on the same baseline as the text around it.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text('', style: style, maxLines: 1),
          Positioned.fill(
            child: CustomPaint(
              painter: _RetroPainter(
                metrics,
                _Look.resolve(context, tokens, style),
                slots,
                t,
                up,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RetroPainter extends CustomPainter {
  const _RetroPainter(this.m, this.look, this.slots, this.t, this.up);

  final _Metrics m;
  final _Look look;
  final List<TitoRetroSlot> slots;
  final double t;
  final bool up;

  @override
  bool shouldRepaint(covariant _RetroPainter old) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    var x = 0.0;
    for (final slot in slots) {
      final w = m.width(slot, t);
      final body = math.max(0.0, w - m.gap);
      final cx = x + body / 2;
      final start = x;
      x += w;
      if (slot.from.isEmpty && slot.to.isEmpty) continue;
      switch (m.style) {
        case TitoNumberStyle.segment:
          canvas.save();
          if (!slot.still) {
            // Two glyph widths cross-fade in one slot: keep them inside it.
            canvas.clipRect(
              Rect.fromLTRB(start, -size.height, start + w, size.height * 2),
            );
          }
          _segments(canvas, cx, cy, slot);
          canvas.restore();
        case TitoNumberStyle.dotMatrix || TitoNumberStyle.pixel:
          _matrix(canvas, Offset(cx, cy), slot);
        case TitoNumberStyle.splitFlap:
          final tile = Rect.fromCenter(
            center: Offset(cx, cy),
            width: body,
            height: m.tile,
          );
          if (tile.width >= 1) _flap(canvas, tile, slot);
        case TitoNumberStyle.standard:
          break;
      }
    }
  }

  bool get _round => m.finish != TitoSurfaceFinish.material;

  /// Draws [draw] lit at weight [w]: plastic first adds a soft glow.
  void _lit(Canvas c, double w, void Function(Color, double, double) draw) {
    if (w <= .01) return;
    final a = look.color.a * w;
    if (m.finish == TitoSurfaceFinish.plastic) {
      draw(look.color.withValues(alpha: a * .35), 1.7, m.thickness * .9);
    }
    draw(look.color.withValues(alpha: a), 1, 0);
  }

  void _line(Canvas c, Offset a, Offset b, Color color, double k, double blur) {
    final d = b - a;
    final len = d.distance;
    if (len < .001) return;
    final ext = _round ? m.thickness / 2 : 0.0;
    final u = d / len;
    c.drawLine(
      a + u * ext,
      b - u * ext,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = m.thickness * k
        ..strokeCap = _round ? StrokeCap.round : StrokeCap.butt
        ..maskFilter = blur > 0
            ? MaskFilter.blur(BlurStyle.normal, blur)
            : null,
    );
  }

  void _blob(
    Canvas c,
    Offset at,
    double s,
    Color color,
    double k,
    double blur,
  ) {
    final paint = Paint()
      ..color = color
      ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;
    final r = s * k / 2;
    _round
        ? c.drawCircle(at, r, paint)
        : c.drawRect(Rect.fromCircle(center: at, radius: r), paint);
  }

  /// Visible end points of segment [bit] (0 = a … 6 = g) of a digit.
  (Offset, Offset) _bar(int bit, double cx, double cy) {
    final th = m.thickness, g = m.glyph, w = m.segWidth, gp = th * .3;
    final l = cx - w / 2 + th / 2, r = cx + w / 2 - th / 2;
    final top = cy - g / 2 + th / 2, bottom = cy + g / 2 - th / 2;
    final h0 = cx - w / 2 + gp, h1 = cx + w / 2 - gp;
    final v0 = cy - g / 2 + th + gp, v1 = cy - th / 2 - gp;
    final v2 = cy + th / 2 + gp, v3 = cy + g / 2 - th - gp;
    return switch (bit) {
      0 => (Offset(h0, top), Offset(h1, top)),
      1 => (Offset(r, v0), Offset(r, v1)),
      2 => (Offset(r, v2), Offset(r, v3)),
      3 => (Offset(h0, bottom), Offset(h1, bottom)),
      4 => (Offset(l, v2), Offset(l, v3)),
      5 => (Offset(l, v0), Offset(l, v1)),
      _ => (Offset(h0, cy), Offset(h1, cy)),
    };
  }

  static bool _ghosted(String ch) =>
      ch.isNotEmpty && '0123456789-–'.contains(ch);

  void _segments(Canvas c, double cx, double cy, TitoRetroSlot slot) {
    final from = _segmentMasks[slot.from] ?? 0;
    final to = _segmentMasks[slot.to] ?? 0;
    // Unlit segments stay faintly visible, like a real LCD.
    if (_ghosted(slot.from) || _ghosted(slot.to)) {
      for (var i = 0; i < 7; i++) {
        final (a, b) = _bar(i, cx, cy);
        _line(c, a, b, look.unlit, 1, 0);
      }
    }
    final k = slot.still ? 1.0 : t;
    void fade(int bit, void Function(Color, double, double) draw) {
      final wf = (from & bit) != 0 ? 1.0 : 0.0;
      final wt = (to & bit) != 0 ? 1.0 : 0.0;
      _lit(c, lerpDouble(wf, wt, k)!, draw);
    }

    for (var i = 0; i < 7; i++) {
      fade(1 << i, (color, scale, blur) {
        final (a, b) = _bar(i, cx, cy);
        _line(c, a, b, color, scale, blur);
      });
    }
    final g = m.glyph, th = m.thickness;
    String owner(int bit) => (to & bit) != 0 ? slot.to : slot.from;
    fade(_segDot, (color, scale, blur) {
      _blob(c, Offset(cx, cy + g / 2 - th / 2), th * 1.5, color, scale, blur);
    });
    fade(_segSlash, (color, scale, blur) {
      final bw = m.body(owner(_segSlash)) / 2;
      _line(
        c,
        Offset(cx + bw - th / 2, cy - g / 2 + th),
        Offset(cx - bw + th / 2, cy + g / 2 - th),
        color,
        scale,
        blur,
      );
    });
    for (final bit in [_segCross, _segBack]) {
      fade(bit, (color, scale, blur) {
        final bw = m.body(owner(bit)) / 2, h = g * .25;
        final flip = bit == _segBack ? 1.0 : -1.0;
        _line(
          c,
          Offset(cx - flip * bw, cy - h),
          Offset(cx + flip * bw, cy + h),
          color,
          scale,
          blur,
        );
      });
    }
    fade(_segPctTop, (color, scale, blur) {
      final bw = m.body(owner(_segPctTop)) / 2;
      final at = Offset(cx - bw + th, cy - g / 2 + th * 1.4);
      _blob(c, at, th * 2.2, color, scale, blur);
    });
    fade(_segPctBottom, (color, scale, blur) {
      final bw = m.body(owner(_segPctBottom)) / 2;
      final at = Offset(cx + bw - th, cy + g / 2 - th * 1.4);
      _blob(c, at, th * 2.2, color, scale, blur);
    });
  }

  void _matrix(Canvas c, Offset center, TitoRetroSlot slot) {
    final from = _bitmaps[slot.from] ?? _blank;
    final to = _bitmaps[slot.to] ?? _blank;
    final pixel = m.style == TitoNumberStyle.pixel;
    final cols = slot.still
        ? to.cols
        : lerpDouble(from.cols, to.cols, t)!.round();
    final px = m.pitchX, py = m.pitchY;
    final left = center.dx - cols * px / 2, top = center.dy - m.glyph / 2;
    // The new glyph pushes the old one out row by row: up when the value
    // grows (new rows enter from below), down when it shrinks.
    final shift = slot.still ? 7 : (t * 7).round().clamp(0, 7);
    final strip = slot.still
        ? [for (var r = 0; r < 7; r++) (to, r)]
        : [
            for (final bm in up ? [from, to] : [to, from])
              for (var r = 0; r < 7; r++) (bm, r),
          ];
    final start = slot.still ? 0 : (up ? shift : 7 - shift);
    final lit = Path(), off = Path();
    for (var r = 0; r < 7; r++) {
      final (bm, row) = strip[r + start];
      final bits = bm.rows[row], pad = (cols - bm.cols) ~/ 2;
      for (var col = 0; col < cols; col++) {
        final bc = col - pad;
        final on =
            bc >= 0 && bc < bm.cols && (bits >> (bm.cols - 1 - bc)) & 1 == 1;
        final cell = Rect.fromLTWH(left + col * px, top + r * py, px, py);
        final path = on ? lit : (pixel ? null : off);
        if (path == null) continue;
        if (pixel) {
          final r2 = cell.inflate(.4);
          _round
              ? path.addRRect(
                  RRect.fromRectAndRadius(r2, Radius.circular(px * .18)),
                )
              : path.addRect(r2);
        } else {
          final d = math.min(px, py) * .78;
          _round
              ? path.addOval(
                  Rect.fromCenter(center: cell.center, width: d, height: d),
                )
              : path.addRect(
                  Rect.fromCenter(center: cell.center, width: d, height: d),
                );
        }
      }
    }
    c.drawPath(off, Paint()..color = look.unlit);
    if (m.finish == TitoSurfaceFinish.plastic) {
      c.drawPath(
        lit,
        Paint()
          ..color = look.color.withValues(alpha: look.color.a * .35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, m.thickness * .9),
      );
    }
    c.drawPath(lit, Paint()..color = look.color);
  }

  RRect _tileShape(Rect r) => RRect.fromRectAndRadius(
    r,
    Radius.circular(
      r.height *
          switch (m.finish) {
            TitoSurfaceFinish.paper => .16,
            TitoSurfaceFinish.plastic => .22,
            TitoSurfaceFinish.material => .06,
          },
    ),
  );

  void _face(Canvas c, Rect r) {
    final shape = _tileShape(r);
    c.drawRRect(shape, Paint()..color = look.tileFill);
    if (m.finish == TitoSurfaceFinish.plastic) {
      c.drawRRect(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              look.highlight.withValues(alpha: .34),
              look.highlight.withValues(alpha: 0),
            ],
            stops: const [0, .55],
          ).createShader(r),
      );
    }
  }

  void _glyph(Canvas c, Rect r, String ch) {
    if (ch.isEmpty || ch == ' ') return;
    final painter = TextPainter(
      text: TextSpan(
        text: ch,
        style: look.textStyle.copyWith(
          fontSize: m.tile * .72,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    painter.paint(c, r.center - Offset(painter.width / 2, painter.height / 2));
    painter.dispose();
  }

  /// One half of a tile (top or bottom) folded by [angle] around the hinge.
  void _half(
    Canvas c,
    Rect r,
    String ch, {
    required bool top,
    double angle = 0,
  }) {
    c.save();
    final hinge = r.center;
    if (angle != 0) {
      final m4 = Matrix4.identity()
        ..setEntry(3, 2, .12 / r.height)
        ..rotateX(angle);
      c.translate(hinge.dx, hinge.dy);
      c.transform(m4.storage);
      c.translate(-hinge.dx, -hinge.dy);
    }
    c.clipRect(
      top
          ? Rect.fromLTRB(r.left, r.top, r.right, hinge.dy)
          : Rect.fromLTRB(r.left, hinge.dy, r.right, r.bottom),
    );
    _face(c, r);
    _glyph(c, r, ch);
    if (angle != 0) {
      final fold = math.sin(angle.abs());
      c.drawRect(r, Paint()..color = look.shade.withValues(alpha: .38 * fold));
    }
    c.restore();
  }

  void _flap(Canvas c, Rect r, TitoRetroSlot slot) {
    for (final s in look.shadows) {
      c.drawRRect(
        _tileShape(r.shift(s.offset).inflate(s.spreadRadius)),
        s.toPaint(),
      );
    }
    if (slot.still || t >= 1) {
      _face(c, r);
      _glyph(c, r, slot.to);
    } else if (t < .5) {
      // Old top folds down over the new top; old bottom stays put.
      _half(c, r, slot.to, top: true);
      _half(c, r, slot.from, top: false);
      _half(c, r, slot.from, top: true, angle: t * 2 * math.pi / 2);
    } else {
      // New bottom unfolds up over the old bottom; new top already shows.
      _half(c, r, slot.from, top: false);
      _half(c, r, slot.to, top: true);
      _half(c, r, slot.to, top: false, angle: -(1 - t) * 2 * math.pi / 2);
    }
    final shape = _tileShape(r);
    final hinge = Paint()
      ..color = look.shade.withValues(alpha: .55)
      ..strokeWidth = math.max(1, r.height * .035);
    c.drawLine(
      Offset(r.left, r.center.dy),
      Offset(r.right, r.center.dy),
      hinge,
    );
    if (look.outline.style != BorderStyle.none) {
      c.drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = look.outline.color
          ..strokeWidth = look.outline.width,
      );
    }
  }
}
