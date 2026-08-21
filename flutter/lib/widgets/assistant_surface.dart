import 'package:flutter/material.dart';

import '../theme/retro_style.dart';
import '../theme/tito_colors.dart';

/// A lighter surface language reserved for the assistant conversation.
///
/// It keeps TitoDex's cream/slate palette while replacing the global sticker
/// border and solid drop shadow with hairline outlines, shallow depth and two
/// restrained guide-corner marks. Flat mode still removes the shadow.
class AssistantSurface extends StatelessWidget {
  const AssistantSurface({
    super.key,
    required this.child,
    this.color = TitoColors.card,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
    this.borderColor,
    this.borderWidth = 1.25,
    this.cornerAccent,
    this.shadow = true,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final double radius;
  final Color? borderColor;
  final double borderWidth;
  final Color? cornerAccent;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final outline = borderColor ?? TitoColors.ink.withValues(alpha: 0.28);
    return ListenableBuilder(
      listenable: retroStyle,
      builder: (context, content) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color,
          borderRadius: borderRadius,
          border: Border.all(color: outline, width: borderWidth),
          boxShadow: shadow && retroStyle.enabled
              ? const [
                  BoxShadow(
                    color: Color(0x2418283B),
                    offset: Offset(0, 5),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: content,
      ),
      child: Stack(
        children: [
          Padding(padding: padding, child: child),
          if (cornerAccent case final accent?)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _AssistantCornerPainter(color: accent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssistantCornerPainter extends CustomPainter {
  const _AssistantCornerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 44 || size.height < 32) return;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const inset = 10.0;
    const length = 13.0;
    canvas.drawLine(
      const Offset(inset, inset + length),
      const Offset(inset, inset),
      paint,
    );
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset + length, inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset - length, size.height - inset),
      Offset(size.width - inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset),
      Offset(size.width - inset, size.height - inset - length),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AssistantCornerPainter oldDelegate) =>
      oldDelegate.color != color;
}
