import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_visual_style.dart';
import 'tito_colors.dart';

/// Trainer's Journal paper language: thinner gray-blue outlines, a short
/// paper-edge shadow, and lighter type. Solid Plastic and Flat UI must not
/// read these values.
///
/// Font sizes stay on the existing [TitoTypography] / [DeviceLayout] rules.
/// Nunito ships Regular/SemiBold/Bold/ExtraBold (400/600/700/800), so body
/// uses Regular rather than a synthesized 500.
abstract final class TrainerJournal {
  static const ink = Color(0xFF36475B);
  static const muted = Color(0xFF647487);
  static const paper = Color(0xFFFFF9ED);
  static const paperWarm = Color(0xFFFFFAF0);
  static const edge = Color(0xFF7C8999);
  static const smallEdge = Color(0xFFABB2B6);
  static const cell = Color(0x80F3EFDF);
  static const selectedFill = Color(0xFFF5E7B6);
  static const selectedEdge = Color(0xFFAE9562);
  static const stamp = Color(0xFF93674F);
  static const stampBorder = Color(0xFFB18168);
  static const photoMat = Color(0xFFD9E3E1);
  static const photoBorder = Color(0xFFFFFDFA);
  static const tapeA = Color(0x9CD8D5B1);
  static const tapeB = Color(0x9CE7E0B9);
  static const rule = Color(0x16859CAF);
  static const levelFill = Color(0xFFEFE1B2);

  static const cardWidth = 1.25;
  static const elementWidth = 0.85;
  static const hairlineWidth = 0.75;
  static const focusWidth = 2.0;
  static const pressSink = 1.0;

  static const cardSide = BorderSide(color: edge, width: cardWidth);
  static const elementSide = BorderSide(color: smallEdge, width: elementWidth);
  static const hairlineSide = BorderSide(
    color: smallEdge,
    width: hairlineWidth,
  );
  static const selectedSide = BorderSide(
    color: selectedEdge,
    width: elementWidth,
  );

  static Border allCard() => Border.fromBorderSide(cardSide);
  static Border allElement() => Border.fromBorderSide(elementSide);

  static BoxDecoration cellDecoration({
    bool empty = false,
    bool selected = false,
    double radius = TitoRadii.sm,
  }) {
    return BoxDecoration(
      color: selected
          ? selectedFill
          : empty
          ? cell.withValues(alpha: 0.28)
          : cell,
      borderRadius: BorderRadius.circular(radius),
      border: selected ? Border.fromBorderSide(selectedSide) : null,
    );
  }

  /// Map the historical sticker weights onto fonts we actually ship.
  static FontWeight weight(FontWeight requested) {
    if (!appVisualStyle.usesTrainerJournal) return requested;
    if (requested.value >= 800) return FontWeight.w700;
    if (requested.value >= 700) return FontWeight.w600;
    if (requested.value >= 500) return FontWeight.w400;
    return requested;
  }
}

/// Ruled paper, used only on journey record surfaces.
class JournalRuledPaper extends StatelessWidget {
  const JournalRuledPaper({
    super.key,
    required this.child,
    this.lineSpacing = 29,
  });

  final Widget child;
  final double lineSpacing;

  @override
  Widget build(BuildContext context) {
    if (!appVisualStyle.usesTrainerJournal) return child;
    return CustomPaint(
      painter: _JournalRuledPainter(lineSpacing: lineSpacing),
      child: child,
    );
  }
}

class _JournalRuledPainter extends CustomPainter {
  const _JournalRuledPainter({this.lineSpacing = 29});

  final double lineSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TrainerJournal.rule
      ..strokeWidth = 1;
    for (var y = 11.0; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _JournalRuledPainter oldDelegate) =>
      oldDelegate.lineSpacing != lineSpacing;
}

/// Washi-style tape. Decorative only — never participates in hit testing.
class JournalTape extends StatelessWidget {
  const JournalTape({super.key, this.width = 64, this.height = 14});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: 3 * math.pi / 180,
        child: CustomPaint(
          size: Size(width, height),
          painter: const _JournalTapePainter(),
        ),
      ),
    );
  }
}

class _JournalTapePainter extends CustomPainter {
  const _JournalTapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.03, 0)
      ..lineTo(size.width * 0.98, 0)
      ..lineTo(size.width, size.height * 0.20)
      ..lineTo(size.width * 0.97, size.height * 0.44)
      ..lineTo(size.width, size.height * 0.65)
      ..lineTo(size.width * 0.98, size.height)
      ..lineTo(size.width * 0.01, size.height)
      ..lineTo(size.width * 0.03, size.height * 0.68)
      ..lineTo(0, size.height * 0.43)
      ..close();
    canvas.save();
    canvas.clipPath(path);
    const stripe = 3.0;
    var x = -size.height;
    while (x < size.width + size.height) {
      final paint = Paint()
        ..color = ((x / stripe).floor().isEven)
            ? TrainerJournal.tapeA
            : TrainerJournal.tapeB;
      canvas.drawRect(Rect.fromLTWH(x, 0, stripe, size.height), paint);
      x += stripe;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Slightly tilted photo mat for the trainer avatar.
class JournalPhotoFrame extends StatelessWidget {
  const JournalPhotoFrame({super.key, required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final frame = size * 0.9;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Transform.rotate(
          angle: -3 * math.pi / 180,
          child: Container(
            width: frame,
            height: frame,
            decoration: BoxDecoration(
              color: TrainerJournal.photoMat,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: TrainerJournal.photoBorder, width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0xFFBFC9C8), spreadRadius: 0.6),
                BoxShadow(color: Color(0x166A7E8D), offset: Offset(1, 2)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Small dashed seal around a short progress value.
class JournalStampLabel extends StatelessWidget {
  const JournalStampLabel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!appVisualStyle.usesTrainerJournal) return child;
    return Transform.rotate(
      angle: 8 * math.pi / 180,
      child: CustomPaint(
        painter: const _JournalStampPainter(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: DefaultTextStyle.merge(
            style: const TextStyle(
              color: TrainerJournal.stamp,
              fontWeight: FontWeight.w700,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _JournalStampPainter extends CustomPainter {
  const _JournalStampPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TrainerJournal.stampBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = TrainerJournal.hairlineWidth;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(999),
    ).deflate(0.6);
    const dash = 3.0;
    const gap = 2.2;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
