import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';
import 'handheld_input.dart';

/// Shared optical backdrop for the experimental Liquid Glass visual system.
///
/// The painter keeps the background cheap and deterministic while still
/// giving translucent surfaces enough colour and depth to refract. Page-level
/// animation is intentionally avoided so RG handhelds do not spend battery on
/// a decorative infinite ticker.
class LiquidGlassBackground extends StatelessWidget {
  const LiquidGlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TitoColors.glassBackgroundBottom,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: CustomPaint(painter: _LiquidLightFieldPainter()),
          ),
          child,
        ],
      ),
    );
  }
}

/// A reusable translucent material with a specular rim and grouped backdrop
/// blur. Put multiple instances under one [BackdropGroup] to share the blur
/// pass; [TitoPageContainer] already provides that group for every route.
class LiquidGlassSurface extends StatelessWidget {
  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.tint = TitoColors.card,
    this.padding = EdgeInsets.zero,
    this.radius = TitoRadii.lg,
    this.opacity = 0.72,
    this.blurSigma = 16,
    this.borderColor,
    this.borderWidth = TitoBorders.glass,
    this.boxShadow,
    this.showSpecular = true,
  });

  final Widget child;
  final Color tint;
  final EdgeInsets padding;
  final double radius;
  final double opacity;
  final double blurSigma;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;
  final bool showSpecular;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final darkTint = tint.computeLuminance() < 0.35;
    final outline =
        borderColor ??
        (darkTint
            ? Colors.white.withValues(alpha: 0.38)
            : Colors.white.withValues(alpha: 0.78));
    final top = Color.alphaBlend(
      Colors.white.withValues(alpha: darkTint ? 0.14 : 0.34),
      tint,
    ).withValues(alpha: opacity);
    final middle = tint.withValues(alpha: opacity * 0.94);
    final bottom = Color.alphaBlend(
      TitoColors.deepBlue.withValues(alpha: darkTint ? 0.12 : 0.06),
      tint,
    ).withValues(alpha: opacity * 0.88);

    return DecoratedBox(
      key: const ValueKey('liquid-glass-shadow'),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter.grouped(
          filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: outline, width: borderWidth),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0, 0.46, 1],
                colors: [top, middle, bottom],
              ),
            ),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Padding(padding: padding, child: child),
                if (showSpecular)
                  const Positioned(
                    left: 1,
                    right: 1,
                    top: 1,
                    child: IgnorePointer(child: _SpecularRim()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular glass control shared by the home and secondary title bars.
class LiquidGlassRoundButton extends StatelessWidget {
  const LiquidGlassRoundButton({
    super.key,
    required this.size,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    this.tint = TitoColors.card,
    this.opacity = 0.72,
  });

  final double size;
  final String semanticLabel;
  final VoidCallback? onTap;
  final Widget child;
  final Color tint;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Semantics(
        button: onTap != null,
        label: semanticLabel,
        child: SizedBox.square(
          dimension: size,
          child: LiquidGlassSurface(
            tint: tint,
            opacity: opacity,
            radius: radius,
            blurSigma: 14,
            boxShadow: TitoShadows.glassSmall,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                splashColor: Colors.white.withValues(alpha: 0.22),
                highlightColor: Colors.white.withValues(alpha: 0.12),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecularRim extends StatelessWidget {
  const _SpecularRim();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.4,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.82),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
      ),
    );
  }
}

class _LiquidLightFieldPainter extends CustomPainter {
  const _LiquidLightFieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          TitoColors.glassBackgroundTop,
          TitoColors.glassBackgroundMid,
          TitoColors.glassBackgroundBottom,
        ],
        stops: [0, 0.54, 1],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    _drawGlow(
      canvas,
      center: Offset(size.width * 0.08, size.height * 0.16),
      radius: size.shortestSide * 0.74,
      color: TitoColors.glassCyan,
      alpha: 0.34,
    );
    _drawGlow(
      canvas,
      center: Offset(size.width * 0.94, size.height * 0.38),
      radius: size.shortestSide * 0.58,
      color: TitoColors.glassLavender,
      alpha: 0.24,
    );
    _drawGlow(
      canvas,
      center: Offset(size.width * 0.28, size.height * 0.96),
      radius: size.shortestSide * 0.7,
      color: TitoColors.glassMint,
      alpha: 0.2,
    );

    final ribbon = Path()
      ..moveTo(-size.width * 0.08, size.height * 0.7)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.54,
        size.width * 0.58,
        size.height * 0.78,
        size.width * 1.08,
        size.height * 0.58,
      );
    canvas.drawPath(
      ribbon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.18
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.045),
    );
  }

  void _drawGlow(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double alpha,
  }) {
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidLightFieldPainter oldDelegate) => false;
}
