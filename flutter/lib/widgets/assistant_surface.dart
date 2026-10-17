import 'package:flutter/material.dart';

import '../theme/retro_style.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_skin.dart';
import 'liquid_glass.dart';

/// Conversation surface for Ask TitoDex.
///
/// The shell follows [TitoSkin]: a hard sticker drop on Journal, a static
/// moulded shell on Solid Plastic (no backdrop blur), and a flat colour
/// block with no elevation. [borderColor] and [borderWidth] stay on the
/// widget so existing callers and tests can still read them; the painted
/// edge comes from the skin.
class AssistantSurface extends StatelessWidget {
  const AssistantSurface({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
    this.borderColor,
    this.borderWidth = 1.25,
    this.shadow = true,
  });

  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  final double radius;
  final Color? borderColor;
  final double borderWidth;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    final borderRadius = BorderRadius.circular(radius);
    return ListenableBuilder(
      listenable: retroStyle,
      builder: (context, content) {
        final drop = shadow
            ? skin.cardShadow(small: true, paperEdge: true)
            : null;
        if (skin.isPlastic) {
          return LiquidGlassSurface(
            tint: color ?? skin.paper,
            opacity: 0.98,
            radius: radius,
            blurBackdrop: false,
            borderColor: skin.outline,
            borderWidth: skin.outlineWidth,
            padding: padding,
            boxShadow: drop,
            child: content!,
          );
        }
        final scheme = Theme.of(context).colorScheme;
        final side = skin.isFlat
            ? (retroStyle.enabled
                  ? BorderSide.none
                  : BorderSide(color: scheme.outlineVariant, width: 1.5))
            : BorderSide(
                color: skin.outline ?? skin.ink,
                width: skin.outlineWidth,
              );
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: drop,
          ),
          child: Material(
            type: MaterialType.card,
            color: color ?? skin.paper,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius,
              side: side,
            ),
            child: content,
          ),
        );
      },
      child: Padding(padding: padding, child: child),
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
