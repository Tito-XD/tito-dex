import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';
import '../theme/tito_skin.dart';
import 'liquid_glass.dart';

/// Dashed rounded-rectangle stroke. Flutter's [Border] has no dashed style.
///
/// Use through [TitoDashedFrame] or as a `foregroundPainter`.
class TitoDashedBorderPainter extends CustomPainter {
  const TitoDashedBorderPainter({
    required this.color,
    this.strokeWidth = 1,
    this.radius = 10,
    this.dash = 4,
    this.gap = 3,
    this.inset = 0,
  });

  final Color color;
  final double strokeWidth;
  final double radius;
  final double dash;
  final double gap;

  /// Distance from the painted box edge to the dash centreline's outer edge.
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(inset + strokeWidth / 2);
    if (rect.isEmpty) {
      return;
    }
    final r = math.max(0.0, math.min(radius, rect.shortestSide / 2));
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final dashes = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        dashes.addPath(metric.extractPath(distance, end), Offset.zero);
        distance = end + gap;
      }
    }
    canvas.drawPath(dashes, paint);
  }

  @override
  bool shouldRepaint(covariant TitoDashedBorderPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius ||
      old.dash != dash ||
      old.gap != gap ||
      old.inset != inset;
}

/// Draws a dashed outline over (or behind) [child].
///
/// Journal shelves use `inset: 5` for the stitched inner frame; empty slots
/// and drop targets use `inset: 0` as their only border.
class TitoDashedFrame extends StatelessWidget {
  const TitoDashedFrame({
    super.key,
    required this.child,
    required this.color,
    this.radius = 10,
    this.strokeWidth = 1,
    this.dash = 4,
    this.gap = 3,
    this.inset = 0,
    this.foreground = true,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;
  final double inset;
  final bool foreground;

  @override
  Widget build(BuildContext context) {
    final painter = TitoDashedBorderPainter(
      color: color,
      strokeWidth: strokeWidth,
      radius: radius,
      dash: dash,
      gap: gap,
      inset: inset,
    );
    return CustomPaint(
      painter: foreground ? null : painter,
      foregroundPainter: foreground ? painter : null,
      child: child,
    );
  }
}

/// A strip of washi tape (Journal hero cards only — never inside lists).
///
/// Position it with a [Positioned] that lets it overhang the card top by
/// about half its height; [TitoSkin.tapeColor] is transparent outside Journal.
class TitoWashiTape extends StatelessWidget {
  const TitoWashiTape({
    super.key,
    this.width = 62,
    this.height = 18,
    this.angleDegrees = -4,
    this.color,
  });

  final double width;
  final double height;
  final double angleDegrees;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tape = color ?? TitoSkin.of(context).tapeColor;
    return IgnorePointer(
      child: Transform.rotate(
        angle: angleDegrees * math.pi / 180,
        child: CustomPaint(
          size: Size(width, height),
          painter: _WashiTapePainter(tape),
        ),
      ),
    );
  }
}

class _WashiTapePainter extends CustomPainter {
  const _WashiTapePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (color.a == 0) {
      return;
    }
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    // Torn ends: dotted light perforation down both short edges.
    final dots = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final points = <Offset>[];
    for (var y = 2.0; y < size.height - 1; y += 4) {
      points
        ..add(Offset(1, y))
        ..add(Offset(size.width - 1, y));
    }
    canvas.drawPoints(ui.PointMode.points, points, dots);
    // Faint fibre stripe so the tape reads as paper, not a flat bar.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.62, size.width, 1),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant _WashiTapePainter old) => old.color != color;
}

/// Sheet / panel paper for the current skin.
///
/// Journal: warm paper with faint horizontal rules (the launcher's library
/// sheet). Solid Plastic: opaque milky gradient (no blur). Flat UI: plain
/// surface. Use as the body of bottom sheets, dialogs-as-pages and settings
/// panels — not behind dense lists that already sit on cards.
class TitoRuledPaper extends StatelessWidget {
  const TitoRuledPaper({
    super.key,
    required this.child,
    this.lineSpacing = 28,
    this.lineOffset = 27,
    this.ruled = true,
  });

  final Widget child;
  final double lineSpacing;

  /// Y of the first rule from the top of the paper.
  final double lineOffset;

  /// Set false to keep the paper colour without rules (Journal only).
  final bool ruled;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    if (skin.isPlastic) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0F8FA), Color(0xFFDCEAF0)],
          ),
        ),
        child: child,
      );
    }
    if (skin.isFlat || !ruled) {
      return ColoredBox(color: skin.sheetFill, child: child);
    }
    // CustomPaint (not a Stack) so the content keeps its incoming
    // constraints — sheets rely on tight heights for their scroll views.
    return ColoredBox(
      color: skin.sheetFill,
      child: CustomPaint(
        painter: _RuledLinesPainter(
          color: skin.ruleColor,
          spacing: lineSpacing,
          offset: lineOffset,
        ),
        child: child,
      ),
    );
  }
}

class _RuledLinesPainter extends CustomPainter {
  const _RuledLinesPainter({
    required this.color,
    required this.spacing,
    required this.offset,
  });

  final Color color;
  final double spacing;
  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    if (spacing <= 0) {
      return;
    }
    final paint = Paint()..color = color;
    for (var y = offset; y < size.height; y += spacing) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RuledLinesPainter old) =>
      old.color != color || old.spacing != spacing || old.offset != offset;
}

/// Full-bleed page backdrop for the current skin. Static paint only.
///
/// Journal: slate desk with a dotted grid and a faint postmark. Solid
/// Plastic: the blue-grey light field ([LiquidGlassBackground]). Flat UI:
/// cool surface with two pale geometric colour blocks.
class TitoPageBackground extends StatelessWidget {
  const TitoPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    if (skin.isPlastic) {
      return LiquidGlassBackground(child: child);
    }
    final journal = skin.isJournal;
    return ColoredBox(
      color: journal ? TitoColors.slateBlue : TitoColors.flatSurface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: journal
                  ? const _JournalDeskPainter()
                  : const _FlatBlocksPainter(),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _JournalDeskPainter extends CustomPainter {
  const _JournalDeskPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5D728A), TitoColors.slateBlue],
        ).createShader(rect),
    );
    // Dotted journal grid.
    const step = 14.0;
    final dots = <Offset>[];
    for (var y = step / 2; y < size.height; y += step) {
      for (var x = step / 2; x < size.width; x += step) {
        dots.add(Offset(x, y));
      }
    }
    canvas.drawPoints(
      ui.PointMode.points,
      dots,
      Paint()
        ..color = const Color(0x1FFFFAF0)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    // Postmark waves drifting in from the right edge.
    final wave = Paint()
      ..color = const Color(0x24FFFAF0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final startX = size.width * 0.38;
    final top = size.height * 0.28;
    final amplitude = math.max(6.0, size.shortestSide * 0.018);
    for (var i = 0; i < 4; i++) {
      final y0 = top + i * math.max(14.0, size.shortestSide * 0.04);
      final path = Path()..moveTo(startX, y0);
      for (var x = startX; x <= size.width; x += 4) {
        final t = (x - startX) / (size.width - startX);
        path.lineTo(x, y0 + math.sin(t * math.pi * 2.2) * amplitude + t * 18);
      }
      canvas.drawPath(path, wave);
    }
  }

  @override
  bool shouldRepaint(covariant _JournalDeskPainter oldDelegate) => false;
}

class _FlatBlocksPainter extends CustomPainter {
  const _FlatBlocksPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.drawCircle(
      Offset(size.width * 0.96, size.height * 0.04),
      s * 0.30,
      Paint()..color = TitoColors.softYellow.withValues(alpha: 0.26),
    );
    canvas.save();
    canvas.translate(size.width * 0.04, size.height * 0.98);
    canvas.rotate(-0.26);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: s * 0.62, height: s * 0.34),
        Radius.circular(s * 0.06),
      ),
      Paint()..color = TitoColors.skyBlue.withValues(alpha: 0.30),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlatBlocksPainter oldDelegate) => false;
}
