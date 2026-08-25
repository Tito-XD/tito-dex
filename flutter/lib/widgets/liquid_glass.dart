import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import 'handheld_input.dart';

/// Optical backdrop used by the Solid Plastic theme. It is intentionally
/// static so the translucent treatment remains practical on RG handhelds.
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

class LiquidGlassSurface extends StatelessWidget {
  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.tint = TitoColors.card,
    this.padding = EdgeInsets.zero,
    this.radius = TitoRadii.lg,
    this.opacity = 0.9,
    this.blurSigma = 6,
    this.blurBackdrop = false,
    this.borderColor,
    this.borderWidth = TitoBorders.glass,
    this.boxShadow,
  });

  final Widget child;
  final Color tint;
  final EdgeInsets padding;
  final double radius;
  final double opacity;
  final double blurSigma;

  /// Real backdrop sampling is reserved for compact, high-value chrome.
  ///
  /// Normal cards use the static optical layers below. This keeps scrolling
  /// lists cheap on RG handhelds while a title control can still opt in to a
  /// small Telegram-like depth cue.
  final bool blurBackdrop;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;

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
      Colors.white.withValues(alpha: darkTint ? 0.16 : 0.24),
      tint,
    ).withValues(alpha: opacity);
    final middle = Color.alphaBlend(
      TitoColors.glassCyan.withValues(alpha: darkTint ? 0.025 : 0.045),
      tint,
    ).withValues(alpha: opacity * 0.98);
    final bottom = Color.alphaBlend(
      TitoColors.deepBlue.withValues(alpha: darkTint ? 0.16 : 0.075),
      tint,
    ).withValues(alpha: opacity * 0.95);

    final staticFill = DecoratedBox(
      key: const ValueKey('solid-plastic-static-fill'),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: outline, width: borderWidth),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, 0.42, 1],
          colors: [top, middle, bottom],
        ),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Padding(padding: padding, child: child),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _PlasticOpticsPainter(
                  radius: radius,
                  darkTint: darkTint,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final useBackdrop =
        blurBackdrop &&
        blurSigma > 0 &&
        !MediaQuery.disableAnimationsOf(context);
    final effectiveBlurSigma = DeviceLayout.useHandheldChrome(context)
        ? blurSigma.clamp(0.0, 3.5)
        : blurSigma;
    final surface = useBackdrop
        ? BackdropFilter.grouped(
            key: const ValueKey('solid-plastic-backdrop'),
            filter: ui.ImageFilter.blur(
              sigmaX: effectiveBlurSigma,
              sigmaY: effectiveBlurSigma,
            ),
            child: staticFill,
          )
        : staticFill;

    return DecoratedBox(
      key: const ValueKey('solid-plastic-shadow'),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: surface),
    );
  }
}

class LiquidGlassRoundButton extends StatelessWidget {
  const LiquidGlassRoundButton({
    super.key,
    required this.size,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    this.tint = TitoColors.card,
    this.opacity = 0.9,
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
            blurSigma: 5.5,
            blurBackdrop: true,
            boxShadow: SolidPlasticShadows.glassSmall,
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

/// One cheap static paint pass gives moulded matte plastic its edge depth: a
/// light-to-dark inner rim. It does not sample the pixels behind the card, so
/// long lists stay close to opaque-card rendering cost. The earlier glossy
/// treatments (diagonal sheen + top specular line) were removed — solid
/// plastic reads matte now, with no reflection streaks.
class _PlasticOpticsPainter extends CustomPainter {
  const _PlasticOpticsPainter({required this.radius, required this.darkTint});

  final double radius;
  final bool darkTint;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final bounds = Offset.zero & size;
    final inset = 1.35;
    final innerRect = bounds.deflate(inset);
    if (innerRect.isEmpty) {
      return;
    }
    final innerRadius = (radius - inset).clamp(0.0, radius);
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, Radius.circular(innerRadius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, 0.48, 1],
          colors: [
            Colors.white.withValues(alpha: darkTint ? 0.12 : 0.26),
            Colors.white.withValues(alpha: 0.03),
            TitoColors.deepBlue.withValues(alpha: darkTint ? 0.26 : 0.15),
          ],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant _PlasticOpticsPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.darkTint != darkTint;
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
      alpha: 0.18,
    );
    _drawGlow(
      canvas,
      center: Offset(size.width * 0.94, size.height * 0.38),
      radius: size.shortestSide * 0.58,
      color: TitoColors.glassLavender,
      alpha: 0.14,
    );
    _drawGlow(
      canvas,
      center: Offset(size.width * 0.28, size.height * 0.96),
      radius: size.shortestSide * 0.7,
      color: TitoColors.glassMint,
      alpha: 0.12,
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
