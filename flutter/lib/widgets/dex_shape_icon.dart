import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/dex/dex_search_terms.dart';
import '../theme/tito_colors.dart';

/// Silhouette for one Pokédex body style (体形).
///
/// 「四足兽形」 and 「双腿形」 are words a player has to decode; the shape they
/// half-remember is a picture. These are the same fourteen silhouettes the
/// in-game Pokédex search uses, drawn as vector paths in the app's ink so they
/// scale on the handheld's small screen, cost no bytes on the CDN, and stay on
/// the right side of the "hand-drawn icons ship in the APK" rule.
class DexShapeIcon extends StatelessWidget {
  const DexShapeIcon({
    super.key,
    required this.slug,
    this.size = 26,
    this.color = TitoColors.ink,
  });

  final String slug;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _DexShapePainter(slug: slug, color: color)),
  );
}

class _DexShapePainter extends CustomPainter {
  const _DexShapePainter({required this.slug, required this.color});

  final String slug;
  final Color color;

  /// Every shape is drawn inside a 24×24 box and scaled to fit.
  static const _canvas = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _canvas, size.height / _canvas);
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final draw = _shapes[slug];
    if (draw != null) {
      draw(canvas, fill, color);
    } else {
      // An unknown slug still needs to occupy its slot rather than vanish.
      canvas.drawCircle(const Offset(12, 12), 6, fill);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DexShapePainter oldDelegate) =>
      oldDelegate.slug != slug || oldDelegate.color != color;
}

typedef _ShapeDrawer = void Function(Canvas canvas, Paint fill, Color color);

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

void _capsule(Canvas canvas, Color color, Offset from, Offset to, double width) {
  canvas.drawLine(from, to, _stroke(color, width));
}

void _oval(Canvas canvas, Paint fill, double cx, double cy, double rx, double ry) {
  canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2), fill);
}

/// One drawer per slug in [kDexShapeSlugs].
final Map<String, _ShapeDrawer> _shapes = <String, _ShapeDrawer>{
  // 球形 — a plain sphere.
  'ball': (canvas, fill, color) {
    canvas.drawCircle(const Offset(12, 12), 7.5, fill);
  },

  // 蛇形 — a serpentine body, head end thickened.
  'squiggle': (canvas, fill, color) {
    final path = Path()
      ..moveTo(3, 17.5)
      ..cubicTo(6, 22, 10, 12, 12.5, 12)
      ..cubicTo(15, 12, 17, 17, 20, 12.5);
    canvas.drawPath(path, _stroke(color, 3.2));
    canvas.drawCircle(const Offset(20.5, 9.5), 2.6, fill);
  },

  // 鱼形 — body plus tail fin.
  'fish': (canvas, fill, color) {
    _oval(canvas, fill, 13.5, 12, 7, 4.6);
    final tail = Path()
      ..moveTo(8, 12)
      ..lineTo(2, 6.5)
      ..lineTo(2, 17.5)
      ..close();
    canvas.drawPath(tail, fill);
    canvas.drawCircle(const Offset(17.5, 10.6), 1.0, Paint()..color = TitoColors.card);
  },

  // 双手形 — head with arms, no legs.
  'arms': (canvas, fill, color) {
    // Arms reach sideways, never straight up: raised they read as ears, and
    // angled down they read as the 双腿形 icon two chips away.
    canvas.drawCircle(const Offset(12, 14), 6.4, fill);
    _capsule(canvas, color, const Offset(7.0, 11.5), const Offset(2.0, 8.5), 3.0);
    _capsule(canvas, color, const Offset(17.0, 11.5), const Offset(22.0, 8.5), 3.0);
  },

  // 柱形 — head on a wide base.
  'blob': (canvas, fill, color) {
    canvas.drawCircle(const Offset(12, 9.5), 5.6, fill);
    final base = Path()
      ..moveTo(6.5, 13)
      ..lineTo(17.5, 13)
      ..lineTo(20, 20)
      ..lineTo(4, 20)
      ..close();
    canvas.drawPath(base, fill);
  },

  // 双足兽形 — bipedal with a tail.
  'upright': (canvas, fill, color) {
    canvas.drawCircle(const Offset(11, 6), 3.8, fill);
    _oval(canvas, fill, 11.5, 13.5, 4.2, 5.2);
    _capsule(canvas, color, const Offset(9.5, 17.5), const Offset(9, 21), 3.0);
    _capsule(canvas, color, const Offset(13.5, 17.5), const Offset(14, 21), 3.0);
    final tail = Path()
      ..moveTo(15, 13)
      ..quadraticBezierTo(21, 13.5, 20.5, 19.5);
    canvas.drawPath(tail, _stroke(color, 2.4));
  },

  // 双腿形 — head with legs, no arms.
  'legs': (canvas, fill, color) {
    canvas.drawCircle(const Offset(12, 9), 6.0, fill);
    _capsule(canvas, color, const Offset(9.5, 14), const Offset(8, 21), 3.0);
    _capsule(canvas, color, const Offset(14.5, 14), const Offset(16, 21), 3.0);
  },

  // 四足兽形 — four legs and a tail.
  'quadruped': (canvas, fill, color) {
    _oval(canvas, fill, 11.5, 11.5, 6.4, 3.9);
    canvas.drawCircle(const Offset(18.5, 8.8), 3.4, fill);
    for (final x in const [7.0, 10.5, 14.0, 17.0]) {
      _capsule(canvas, color, Offset(x, 13.5), Offset(x, 20), 2.6);
    }
    final tail = Path()
      ..moveTo(5.5, 10)
      ..quadraticBezierTo(2, 8.5, 2.5, 5);
    canvas.drawPath(tail, _stroke(color, 2.2));
  },

  // 双翅形 — one body, two wings.
  'wings': (canvas, fill, color) {
    _oval(canvas, fill, 12, 14, 3.2, 5.6);
    canvas.drawCircle(const Offset(12, 7.0), 3.0, fill);
    final left = Path()
      ..moveTo(9.6, 11)
      ..quadraticBezierTo(3.5, 3.5, 1.5, 10.5)
      ..quadraticBezierTo(4.5, 15.5, 9.6, 16)
      ..close();
    final right = Path()
      ..moveTo(14.4, 11)
      ..quadraticBezierTo(20.5, 3.5, 22.5, 10.5)
      ..quadraticBezierTo(19.5, 15.5, 14.4, 16)
      ..close();
    canvas.drawPath(left, fill);
    canvas.drawPath(right, fill);
  },

  // 触手形 — a dome trailing tentacles.
  'tentacles': (canvas, fill, color) {
    final dome = Path()
      ..addArc(Rect.fromCircle(center: const Offset(12, 10), radius: 6.6), math.pi, math.pi)
      ..close();
    canvas.drawPath(dome, fill);
    for (final x in const [6.0, 9.4, 12.8, 16.2]) {
      final tentacle = Path()
        ..moveTo(x + 0.6, 10)
        ..quadraticBezierTo(x - 1.2, 15, x + 1.2, 20);
      canvas.drawPath(tentacle, _stroke(color, 2.1));
    }
  },

  // 组合形 — several bodies acting as one.
  'heads': (canvas, fill, color) {
    canvas.drawCircle(const Offset(12, 6.5), 4.2, fill);
    canvas.drawCircle(const Offset(6.5, 16), 4.6, fill);
    canvas.drawCircle(const Offset(17.5, 16), 4.6, fill);
  },

  // 人形 — head, torso, arms, legs.
  'humanoid': (canvas, fill, color) {
    canvas.drawCircle(const Offset(12, 5.5), 3.4, fill);
    _oval(canvas, fill, 12, 12.5, 3.2, 4.4);
    _capsule(canvas, color, const Offset(9.5, 10), const Offset(5.5, 15), 2.6);
    _capsule(canvas, color, const Offset(14.5, 10), const Offset(18.5, 15), 2.6);
    _capsule(canvas, color, const Offset(10.4, 16.5), const Offset(9.5, 21.5), 2.8);
    _capsule(canvas, color, const Offset(13.6, 16.5), const Offset(14.5, 21.5), 2.8);
  },

  // 多翅形 — insect body under two pairs of wings.
  'bug-wings': (canvas, fill, color) {
    _oval(canvas, fill, 12, 13.5, 2.4, 6.0);
    canvas.drawCircle(const Offset(12, 5.8), 2.6, fill);
    _capsule(canvas, color, const Offset(11, 3.6), const Offset(9, 1.5), 1.6);
    _capsule(canvas, color, const Offset(13, 3.6), const Offset(15, 1.5), 1.6);
    for (final side in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(12, 0);
      canvas.scale(side, 1);
      _oval(canvas, fill, 5.0, 9.5, 4.4, 2.6);
      _oval(canvas, fill, 4.4, 15.5, 3.8, 2.2);
      canvas.restore();
    }
  },

  // 虫形 — a segmented, armoured body.
  'armor': (canvas, fill, color) {
    canvas.drawCircle(const Offset(12, 5.6), 3.4, fill);
    _capsule(canvas, color, const Offset(10.5, 3.2), const Offset(8.5, 1.2), 1.5);
    _capsule(canvas, color, const Offset(13.5, 3.2), const Offset(15.5, 1.2), 1.5);
    _oval(canvas, fill, 12, 11.0, 5.6, 2.4);
    _oval(canvas, fill, 12, 16.0, 5.0, 2.2);
    _oval(canvas, fill, 12, 20.4, 4.0, 1.8);
  },
};

/// Relative-size mark for one [DexSizeBucket].
///
/// Same job as [DexShapeIcon] for the height axis: a word like 「极小」 is
/// clearer next to a circle that is actually tiny. Five filled discs, one
/// scale each, drawn in the app ink so they match the shape chips.
class DexSizeIcon extends StatelessWidget {
  const DexSizeIcon({
    super.key,
    required this.bucket,
    this.size = 26,
    this.color = TitoColors.ink,
  });

  final DexSizeBucket bucket;
  final double size;
  final Color color;

  /// Disc radius inside the 24×24 canvas, tiny → huge.
  static const _radii = <DexSizeBucket, double>{
    DexSizeBucket.tiny: 2.4,
    DexSizeBucket.small: 4.0,
    DexSizeBucket.medium: 5.8,
    DexSizeBucket.large: 7.6,
    DexSizeBucket.huge: 9.6,
  };

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _DexSizePainter(
        radius: _radii[bucket] ?? 5.8,
        color: color,
      ),
    ),
  );
}

class _DexSizePainter extends CustomPainter {
  const _DexSizePainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  static const _canvas = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _canvas, size.height / _canvas);
    // Sit on a shared baseline so a tiny next to a huge still reads as size,
    // not as five unrelated dots floating at different heights.
    canvas.drawCircle(
      Offset(12, 12 + (9.6 - radius) * 0.35),
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DexSizePainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.color != color;
}
