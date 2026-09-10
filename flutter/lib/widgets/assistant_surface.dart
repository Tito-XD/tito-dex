import 'package:flutter/material.dart';

import '../theme/app_visual_style.dart';
import '../theme/retro_style.dart';
import '../theme/tito_colors.dart';
import '../theme/trainer_journal.dart';
import 'liquid_glass.dart';

/// Surface used by the assistant conversation (status pill, composer, answer
/// cards).
///
/// Defaults follow the active visual style: Trainer's Journal keeps the warm
/// assistant paper, Solid Plastic renders a milky glass sheet, Flat UI uses
/// the Material low container. Explicit [color] / [borderColor] still win so
/// callers can tint individual cards.
class AssistantSurface extends StatelessWidget {
  const AssistantSurface({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
    this.borderColor,
    this.borderWidth = TitoBorders.element,
    this.shadow = true,
  });

  /// Warm assistant paper used by Trainer's Journal when no [color] is given.
  static const paper = Color(0xFFFFFBF2);

  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  final double radius;
  final Color? borderColor;
  final double borderWidth;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(radius);
    if (appVisualStyle.usesSolidPlastic) {
      return ListenableBuilder(
        listenable: retroStyle,
        builder: (context, content) => LiquidGlassSurface(
          tint: color ?? Colors.white,
          opacity: color == null ? 0.82 : 0.92,
          radius: radius,
          borderColor: borderColor,
          borderWidth: borderColor == null ? TitoBorders.glass : borderWidth,
          padding: padding,
          boxShadow: shadow && retroStyle.enabled
              ? SolidPlasticShadows.stickerSmall
              : null,
          child: content!,
        ),
        child: child,
      );
    }
    if (appVisualStyle.usesTrainerJournal) {
      // Hard offset shadow lives on the outer box; the Material keeps ink
      // ripples and clipping for the content exactly as before.
      return ListenableBuilder(
        listenable: retroStyle,
        builder: (context, content) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: shadow && retroStyle.enabled
                ? TrainerJournalShadows.stickerSmall
                : null,
          ),
          child: content,
        ),
        child: Material(
          type: MaterialType.card,
          color: color ?? paper,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(
              color: borderColor ?? TrainerJournal.edge,
              width: borderWidth == TitoBorders.element
                  ? TitoBorders.journalCard
                  : borderWidth,
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      );
    }
    final outline = borderColor ?? scheme.outlineVariant;
    return ListenableBuilder(
      listenable: retroStyle,
      builder: (context, content) => Material(
        type: MaterialType.card,
        color: color ?? scheme.surfaceContainerLow,
        elevation: shadow && retroStyle.enabled ? 1 : 0,
        shadowColor: scheme.shadow,
        surfaceTintColor: scheme.surfaceTint,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: outline, width: borderWidth),
        ),
        child: content,
      ),
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
