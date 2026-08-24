import 'package:flutter/material.dart';

import '../theme/retro_style.dart';
import '../theme/tito_colors.dart';
import 'liquid_glass.dart';

/// A lighter surface language reserved for the assistant conversation.
///
/// Conversation panels use a slightly quieter glass recipe than dashboard
/// cards so long answers remain easy to scan. Flat mode removes their depth.
class AssistantSurface extends StatelessWidget {
  const AssistantSurface({
    super.key,
    required this.child,
    this.color = TitoColors.card,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
    this.borderColor,
    this.borderWidth = 1.25,
    this.shadow = true,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final double radius;
  final Color? borderColor;
  final double borderWidth;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final outline = borderColor ?? TitoColors.ink.withValues(alpha: 0.28);
    return ListenableBuilder(
      listenable: retroStyle,
      builder: (context, content) => LiquidGlassSurface(
        tint: color,
        opacity: 0.74,
        radius: borderRadius.topLeft.x,
        blurSigma: 12,
        borderColor: outline,
        borderWidth: borderWidth,
        padding: padding,
        boxShadow: shadow && retroStyle.enabled
            ? TitoShadows.stickerSmall
            : null,
        child: content!,
      ),
      child: child,
    );
  }
}

/// A small four-point glint used sparingly around assistant motion states.
class AssistantSparkle extends StatelessWidget {
  const AssistantSparkle({
    super.key,
    this.size = 14,
    this.color = TitoColors.coral,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _AssistantSparklePainter(color: color)),
  );
}

class _AssistantSparklePainter extends CustomPainter {
  const _AssistantSparklePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final waist = radius * 0.22;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + waist,
        center.dy - waist,
        center.dx + radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + waist,
        center.dy + waist,
        center.dx,
        center.dy + radius,
      )
      ..quadraticBezierTo(
        center.dx - waist,
        center.dy + waist,
        center.dx - radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - waist,
        center.dy - waist,
        center.dx,
        center.dy - radius,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _AssistantSparklePainter oldDelegate) =>
      oldDelegate.color != color;
}
