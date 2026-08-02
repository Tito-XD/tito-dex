import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/dex/dex_search_terms.dart';
import '../theme/tito_colors.dart';

/// Pokémon HOME-style mark for one Pokédex body style (体形).
///
/// 「四足兽形」 and 「双腿形」 are words a player has to decode; the shape they
/// half-remember is a picture. These fourteen original vector drawings follow
/// HOME's recognisable creature-like poses and white eyes without bundling its
/// raster artwork. They scale cleanly, cost no CDN bytes, and work offline.
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
    child: CustomPaint(
      painter: _DexShapePainter(slug: slug, color: color),
    ),
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

void _capsule(
  Canvas canvas,
  Color color,
  Offset from,
  Offset to,
  double width,
) {
  canvas.drawLine(from, to, _stroke(color, width));
}

void _oval(
  Canvas canvas,
  Paint fill,
  double cx,
  double cy,
  double rx,
  double ry,
) {
  canvas.drawOval(
    Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
    fill,
  );
}

void _eye(
  Canvas canvas,
  Color pupilColor,
  double cx,
  double cy, {
  double rx = 1.35,
  double ry = 1.75,
}) {
  final white = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  _oval(canvas, white, cx, cy, rx, ry);
  canvas.drawCircle(
    Offset(cx + rx * .12, cy + ry * .08),
    math.min(rx, ry) * .43,
    Paint()
      ..color = pupilColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true,
  );
}

void _eyePair(
  Canvas canvas,
  Color pupilColor,
  double leftX,
  double rightX,
  double cy, {
  double rx = 1.25,
  double ry = 1.65,
}) {
  _eye(canvas, pupilColor, leftX, cy, rx: rx, ry: ry);
  _eye(canvas, pupilColor, rightX, cy, rx: rx, ry: ry);
}

/// One drawer per slug in [kDexShapeSlugs].
final Map<String, _ShapeDrawer> _shapes = <String, _ShapeDrawer>{
  // Body01 / 球形 — a soft round creature, not a geometry swatch.
  'ball': (canvas, fill, color) {
    final body = Path()
      ..moveTo(4.0, 12.4)
      ..cubicTo(4.1, 6.7, 7.6, 3.7, 12.2, 3.7)
      ..cubicTo(17.3, 3.7, 20.3, 7.1, 20.0, 12.5)
      ..cubicTo(19.7, 17.9, 16.8, 20.3, 11.8, 20.2)
      ..cubicTo(6.8, 20.1, 3.8, 17.5, 4.0, 12.4)
      ..close();
    canvas.drawPath(body, fill);
    _eyePair(canvas, color, 8.6, 14.4, 11.9);
  },

  // Body02 / 蛇形 — side-on head flowing into an S-shaped tail.
  'squiggle': (canvas, fill, color) {
    final body = Path()
      ..moveTo(2.7, 10.2)
      ..cubicTo(2.7, 6.0, 5.9, 3.7, 9.5, 4.0)
      ..cubicTo(13.1, 4.3, 14.5, 7.6, 13.1, 10.5)
      ..cubicTo(11.7, 13.3, 9.0, 14.7, 10.5, 16.6)
      ..cubicTo(12.0, 18.5, 14.1, 14.4, 17.0, 13.3)
      ..cubicTo(20.4, 12.0, 22.2, 14.6, 21.4, 19.9)
      ..cubicTo(19.5, 17.9, 18.0, 17.2, 16.5, 19.3)
      ..cubicTo(13.9, 22.8, 7.1, 22.0, 5.4, 18.0)
      ..cubicTo(4.3, 15.3, 6.0, 12.9, 7.2, 11.4)
      ..cubicTo(5.6, 11.5, 4.2, 11.2, 2.7, 10.2)
      ..close();
    canvas.drawPath(body, fill);
    _eye(canvas, color, 8.6, 7.8, rx: 1.25, ry: 1.65);
  },

  // Body03 / 鱼形 — fish profile with dorsal and tail fins.
  'fish': (canvas, fill, color) {
    final body = Path()
      ..moveTo(2.2, 12.6)
      ..cubicTo(5.4, 7.7, 10.8, 6.0, 16.2, 8.0)
      ..lineTo(20.8, 5.2)
      ..lineTo(20.2, 9.7)
      ..lineTo(22.4, 12.1)
      ..lineTo(20.1, 14.1)
      ..lineTo(20.7, 18.7)
      ..lineTo(16.2, 15.8)
      ..cubicTo(10.6, 17.7, 5.2, 16.5, 2.2, 12.6)
      ..close();
    canvas.drawPath(body, fill);
    _eye(canvas, color, 7.2, 11.3, rx: 1.15, ry: 1.55);
  },

  // Body04 / 双手形 — round head framed by two heavy curling arms.
  'arms': (canvas, fill, color) {
    canvas.drawCircle(const Offset(12, 9.8), 5.4, fill);
    final leftArm = Path()
      ..moveTo(7.3, 8.5)
      ..cubicTo(4.5, 7.2, 2.0, 7.8, 1.5, 10.9)
      ..cubicTo(0.9, 14.2, 2.2, 19.2, 5.6, 20.4)
      ..cubicTo(7.7, 21.1, 9.4, 19.0, 8.5, 17.3)
      ..cubicTo(7.8, 16.0, 5.6, 16.7, 5.2, 14.3)
      ..cubicTo(4.9, 12.4, 6.8, 12.1, 8.0, 12.8)
      ..close();
    canvas.drawPath(leftArm, fill);
    canvas.save();
    canvas.translate(24, 0);
    canvas.scale(-1, 1);
    canvas.drawPath(leftArm, fill);
    canvas.restore();
    _eyePair(canvas, color, 9.4, 14.6, 9.7, rx: 1.1, ry: 1.5);
  },

  // Body05 / 柱形 — head tapering into a broad grounded base.
  'blob': (canvas, fill, color) {
    final body = Path()
      ..moveTo(5.3, 8.9)
      ..cubicTo(6.0, 5.4, 8.5, 3.6, 12.0, 3.6)
      ..cubicTo(15.5, 3.6, 18.0, 5.4, 18.7, 8.9)
      ..cubicTo(19.0, 11.0, 17.4, 13.0, 16.5, 14.5)
      ..lineTo(19.5, 20.3)
      ..lineTo(4.5, 20.3)
      ..lineTo(7.5, 14.5)
      ..cubicTo(6.6, 13.0, 5.0, 11.0, 5.3, 8.9)
      ..close();
    canvas.drawPath(body, fill);
    _eyePair(canvas, color, 9.6, 14.4, 9.4, rx: 1.15, ry: 1.55);
  },

  // Body06 / 双足兽形 — a compact dinosaur-like side profile.
  'upright': (canvas, fill, color) {
    final body = Path()
      ..moveTo(2.5, 9.0)
      ..cubicTo(3.7, 5.5, 7.0, 3.3, 10.4, 4.2)
      ..cubicTo(12.8, 4.8, 13.7, 7.2, 12.5, 9.6)
      ..cubicTo(11.7, 11.2, 13.2, 12.1, 15.0, 12.7)
      ..cubicTo(18.4, 13.9, 20.9, 12.6, 22.1, 10.3)
      ..cubicTo(22.2, 14.5, 20.1, 17.0, 16.6, 17.4)
      ..lineTo(17.8, 21.0)
      ..lineTo(13.0, 21.0)
      ..lineTo(11.9, 17.7)
      ..lineTo(9.1, 17.7)
      ..lineTo(7.7, 21.0)
      ..lineTo(3.1, 21.0)
      ..cubicTo(4.4, 17.5, 5.8, 14.4, 7.1, 12.1)
      ..cubicTo(5.4, 11.9, 3.6, 11.0, 2.5, 9.0)
      ..close();
    canvas.drawPath(body, fill);
    _eye(canvas, color, 7.5, 7.4, rx: 1.1, ry: 1.5);
  },

  // Body07 / 双腿形 — a head sitting directly on two splayed legs.
  'legs': (canvas, fill, color) {
    canvas.drawCircle(const Offset(12, 9.2), 5.8, fill);
    final legs = Path()
      ..moveTo(7.7, 12.8)
      ..cubicTo(7.0, 14.2, 5.8, 15.4, 4.2, 16.2)
      ..cubicTo(2.1, 17.2, 2.1, 20.3, 5.4, 20.5)
      ..cubicTo(8.0, 20.7, 9.8, 18.4, 12.0, 17.5)
      ..cubicTo(14.2, 18.4, 16.0, 20.7, 18.6, 20.5)
      ..cubicTo(21.9, 20.3, 21.9, 17.2, 19.8, 16.2)
      ..cubicTo(18.2, 15.4, 17.0, 14.2, 16.3, 12.8)
      ..close();
    canvas.drawPath(legs, fill);
    _eyePair(canvas, color, 9.4, 14.6, 9.0, rx: 1.1, ry: 1.5);
  },

  // Body08 / 四足兽形 — a long-backed quadruped seen from the side.
  'quadruped': (canvas, fill, color) {
    final body = Path()
      ..moveTo(2.1, 8.9)
      ..lineTo(4.1, 6.6)
      ..lineTo(4.8, 3.8)
      ..lineTo(7.0, 5.6)
      ..cubicTo(9.6, 5.8, 12.0, 7.7, 13.5, 9.3)
      ..cubicTo(16.8, 9.2, 19.5, 10.2, 21.6, 12.0)
      ..cubicTo(20.6, 14.1, 19.4, 14.7, 17.9, 14.8)
      ..lineTo(18.6, 20.5)
      ..lineTo(15.2, 20.5)
      ..lineTo(14.3, 15.1)
      ..lineTo(10.1, 15.1)
      ..lineTo(9.2, 20.5)
      ..lineTo(5.8, 20.5)
      ..lineTo(6.5, 14.1)
      ..cubicTo(4.1, 13.6, 2.3, 11.9, 2.1, 8.9)
      ..close();
    canvas.drawPath(body, fill);
    _eye(canvas, color, 6.5, 8.6, rx: 1.05, ry: 1.45);
  },

  // Body09 / 双翅形 — side-on flying creature with one wing pair.
  'wings': (canvas, fill, color) {
    final wings = Path()
      ..moveTo(9.4, 10.9)
      ..cubicTo(11.8, 5.5, 16.1, 2.6, 21.8, 3.0)
      ..cubicTo(20.8, 7.4, 18.7, 10.5, 15.4, 12.8)
      ..cubicTo(18.2, 14.0, 19.6, 16.0, 19.8, 19.4)
      ..cubicTo(14.4, 19.4, 10.8, 17.4, 8.8, 14.4)
      ..close();
    canvas.drawPath(wings, fill);
    final head = Path()
      ..moveTo(2.0, 12.3)
      ..cubicTo(3.7, 8.7, 7.5, 7.1, 10.7, 9.0)
      ..cubicTo(12.5, 10.1, 12.8, 13.2, 10.9, 15.1)
      ..cubicTo(8.0, 18.0, 3.6, 16.0, 2.0, 12.3)
      ..close();
    canvas.drawPath(head, fill);
    _eye(canvas, color, 7.4, 11.9, rx: 1.05, ry: 1.45);
  },

  // Body10 / 触手形 — a jelly-like dome with a rounded multiped skirt.
  'tentacles': (canvas, fill, color) {
    final body = Path()
      ..moveTo(4.1, 11.2)
      ..cubicTo(4.1, 6.2, 7.2, 3.6, 12.0, 3.6)
      ..cubicTo(16.8, 3.6, 19.9, 6.2, 19.9, 11.2)
      ..lineTo(20.3, 18.7)
      ..cubicTo(19.0, 17.8, 17.8, 18.2, 16.6, 20.4)
      ..cubicTo(15.4, 18.1, 13.9, 18.0, 12.6, 20.5)
      ..cubicTo(11.3, 18.0, 9.8, 18.0, 8.5, 20.4)
      ..cubicTo(7.1, 18.1, 5.9, 17.8, 3.7, 18.9)
      ..close();
    canvas.drawPath(body, fill);
    _eyePair(canvas, color, 9.4, 14.6, 10.0, rx: 1.1, ry: 1.5);
  },

  // Body11 / 组合形 — three connected bodies with one shared face.
  'heads': (canvas, fill, color) {
    canvas.drawCircle(const Offset(12, 9.4), 5.3, fill);
    _capsule(
      canvas,
      color,
      const Offset(8.7, 12.6),
      const Offset(6.3, 16.0),
      2.8,
    );
    _capsule(
      canvas,
      color,
      const Offset(15.3, 12.6),
      const Offset(17.7, 16.0),
      2.8,
    );
    canvas.drawCircle(const Offset(5.3, 17.7), 3.8, fill);
    canvas.drawCircle(const Offset(18.7, 17.7), 3.8, fill);
    _eyePair(canvas, color, 9.5, 14.5, 9.1, rx: 1.1, ry: 1.5);
  },

  // Body12 / 人形 — upright torso with a tuft, arms and two feet.
  'humanoid': (canvas, fill, color) {
    final body = Path()
      ..moveTo(10.6, 4.5)
      ..lineTo(12.0, 1.9)
      ..lineTo(13.4, 4.5)
      ..cubicTo(16.1, 5.0, 17.4, 7.2, 16.8, 9.8)
      ..cubicTo(20.0, 10.6, 21.6, 13.0, 20.8, 16.2)
      ..cubicTo(19.9, 18.8, 17.8, 18.4, 16.7, 16.8)
      ..lineTo(16.1, 20.8)
      ..lineTo(12.8, 20.8)
      ..lineTo(12.0, 17.5)
      ..lineTo(11.2, 20.8)
      ..lineTo(7.9, 20.8)
      ..lineTo(7.3, 16.8)
      ..cubicTo(6.2, 18.4, 4.1, 18.8, 3.2, 16.2)
      ..cubicTo(2.4, 13.0, 4.0, 10.6, 7.2, 9.8)
      ..cubicTo(6.6, 7.2, 7.9, 5.0, 10.6, 4.5)
      ..close();
    canvas.drawPath(body, fill);
    _eyePair(canvas, color, 9.6, 14.4, 8.1, rx: 1.05, ry: 1.45);
  },

  // Body13 / 多翅形 — small head beside two clearly separated wing pairs.
  'bug-wings': (canvas, fill, color) {
    final wings = Path()
      ..moveTo(10.5, 11.1)
      ..cubicTo(12.5, 5.5, 16.4, 2.7, 21.1, 4.2)
      ..cubicTo(21.7, 8.2, 19.4, 11.1, 15.7, 12.5)
      ..cubicTo(19.8, 13.0, 21.4, 15.5, 20.3, 19.4)
      ..cubicTo(15.7, 20.0, 12.1, 17.7, 10.1, 14.1)
      ..close();
    canvas.drawPath(wings, fill);
    final head = Path()
      ..moveTo(2.1, 12.2)
      ..cubicTo(3.0, 8.8, 6.0, 7.1, 9.1, 8.3)
      ..lineTo(10.8, 6.0)
      ..lineTo(11.6, 8.8)
      ..cubicTo(13.3, 10.8, 12.7, 14.1, 10.3, 15.8)
      ..cubicTo(7.0, 18.1, 3.2, 16.1, 2.1, 12.2)
      ..close();
    canvas.drawPath(head, fill);
    _eye(canvas, color, 7.0, 11.6, rx: 1.05, ry: 1.45);
  },

  // Body14 / 虫形 — low insectoid body with antennae and rear segments.
  'armor': (canvas, fill, color) {
    final body = Path()
      ..moveTo(2.0, 14.5)
      ..cubicTo(3.0, 10.7, 5.8, 8.3, 9.1, 8.0)
      ..lineTo(7.5, 5.2)
      ..lineTo(10.3, 6.5)
      ..lineTo(11.5, 3.4)
      ..lineTo(13.3, 6.6)
      ..cubicTo(16.6, 6.4, 19.6, 8.1, 20.2, 11.0)
      ..lineTo(22.3, 12.8)
      ..lineTo(20.0, 14.2)
      ..cubicTo(21.6, 16.7, 20.3, 19.8, 17.0, 19.9)
      ..cubicTo(15.5, 21.7, 12.3, 21.6, 11.2, 19.7)
      ..cubicTo(8.4, 21.0, 5.4, 19.8, 5.2, 17.6)
      ..cubicTo(3.6, 17.5, 2.3, 16.5, 2.0, 14.5)
      ..close();
    canvas.drawPath(body, fill);
    _eyePair(canvas, color, 8.5, 12.2, 12.2, rx: 1.0, ry: 1.4);
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
      painter: _DexSizePainter(radius: _radii[bucket] ?? 5.8, color: color),
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
