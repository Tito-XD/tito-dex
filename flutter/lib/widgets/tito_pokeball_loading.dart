import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../theme/tito_colors.dart';

/// A pale white silhouette spins in place with a soft shimmer, letting the
/// surrounding type tint show through.
///
/// On cream / white surfaces the white silhouette vanishes; pass
/// [onLight] (or an explicit [inkColor]) to draw a dark ink silhouette.
class TitoPokeballLoading extends StatefulWidget {
  const TitoPokeballLoading({
    super.key,
    this.size = 28,
    this.inkColor,
    this.onLight = false,
  });

  final double size;

  /// Silhouette colour. Defaults to white (or ink when [onLight] is set).
  final Color? inkColor;

  /// Render the dark variant for cream / white cards.
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
    final color =
        widget.inkColor ?? (widget.onLight ? TitoColors.ink : Colors.white);
    return Semantics(
      label: AppZh.loadingSemantics,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            return Center(
              child: Transform.rotate(
                angle: t * 2 * math.pi,
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: _PokeballShimmerPainter(t, color),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PokeballShimmerPainter extends CustomPainter {
  const _PokeballShimmerPainter(this.phase, this.color);
  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
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
    final highlight = math.sin(phase * 2 * math.pi);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(highlight - 1, -.4),
        end: Alignment(highlight + 1, .4),
        colors: [
          color.withValues(alpha: 0.4),
          color.withValues(alpha: 0.8),
          color.withValues(alpha: 0.4),
        ],
        stops: const [0, .5, 1],
      ).createShader(rect);
    canvas.drawPath(silhouette, paint);
  }

  @override
  bool shouldRepaint(_PokeballShimmerPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}
