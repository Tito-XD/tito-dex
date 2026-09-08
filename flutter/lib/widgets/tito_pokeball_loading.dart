import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../theme/tito_colors.dart';

/// A pale white silhouette spins in place with constant colour, letting the
/// surrounding type tint show through.
///
/// On cream / white surfaces the white silhouette vanishes; pass
/// [onLight] to add a faint outline without changing the white fill.
class TitoPokeballLoading extends StatefulWidget {
  const TitoPokeballLoading({
    super.key,
    this.size = 28,
    this.inkColor,
    this.onLight = false,
  });

  final double size;

  /// Silhouette colour. Defaults to pale white.
  final Color? inkColor;

  /// Add a faint outline for cream / white cards.
  final bool onLight;

  @override
  State<TitoPokeballLoading> createState() => _TitoPokeballLoadingState();
}

class _TitoPokeballLoadingState extends State<TitoPokeballLoading>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.inkColor ?? Colors.white.withValues(alpha: .8);
    return Semantics(
      label: AppZh.loadingSemantics,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _PokeballPainter(color, widget.onLight),
            ),
          ),
          builder: (context, child) {
            final t = _controller.value;
            return Center(
              child: Transform.rotate(angle: t * 2 * math.pi, child: child),
            );
          },
        ),
      ),
    );
  }
}

class _PokeballPainter extends CustomPainter {
  const _PokeballPainter(this.color, this.onLight);
  final Color color;
  final bool onLight;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(.5);
    final center = rect.center;
    final radius = size.width / 2;
    final body = Path()..addOval(rect);
    final gap = Path()
      ..addRect(
        Rect.fromCenter(
          center: center,
          width: size.width,
          height: size.height * .13,
        ),
      );
    final halves = Path.combine(PathOperation.difference, body, gap);
    final ring = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius * .43));
    final silhouette = Path.combine(PathOperation.difference, halves, ring)
      ..addOval(Rect.fromCircle(center: center, radius: radius * .27));
    canvas.drawPath(silhouette, Paint()..color = color);
    if (onLight) {
      canvas.drawPath(
        silhouette,
        Paint()
          ..color = TitoColors.ink.withValues(alpha: .25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8,
      );
    }
  }

  @override
  bool shouldRepaint(_PokeballPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.onLight != onLight;
}
