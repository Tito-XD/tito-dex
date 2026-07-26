import 'package:flutter/material.dart';

import '../theme/motion_preferences.dart';

/// Small fade + upward-slide reveal for list/grid items and page sections.
///
/// Honors the global list-animation toggle: when disabled the child renders
/// immediately. The animation only plays once per widget lifetime — scrolling
/// an item back into view does not replay it.
class TitoListReveal extends StatefulWidget {
  const TitoListReveal({
    super.key,
    this.delay = Duration.zero,
    this.enabled = true,
    required this.child,
  });

  /// Convenience stagger: row/index-based delay with a bounded tail so long
  /// lists don't keep animating forever.
  static Duration staggerDelay(
    int index, {
    int stepMs = 30,
    int maxSteps = 10,
    int baseMs = 0,
  }) {
    final step = index < maxSteps ? index : maxSteps;
    return Duration(milliseconds: baseMs + step * stepMs);
  }

  final Duration delay;
  final bool enabled;
  final Widget child;

  @override
  State<TitoListReveal> createState() => _TitoListRevealState();
}

class _TitoListRevealState extends State<TitoListReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // Slower, smaller travel than the original 220ms / 0.12: the reveal
      // plays right after the route transition lands, so a gentle drift reads
      // as a cascade instead of a flash.
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _position = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_opacity);

    if (!widget.enabled || !motionPreferences.listAnimationsEnabled) {
      _controller.value = 1.0;
      return;
    }

    // Wait for the incoming route transition to finish so the list reveal does
    // not overlap with the page push animation (which causes visual flash and
    // dropped frames on long grids).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startAfterRouteTransition();
    });
  }

  void _startAfterRouteTransition() {
    final route = ModalRoute.of(context);
    final routeAnimation = route?.animation;
    if (routeAnimation != null &&
        routeAnimation.status != AnimationStatus.completed) {
      late VoidCallback listener;
      listener = () {
        if (routeAnimation.status == AnimationStatus.completed) {
          routeAnimation.removeListener(listener);
          _startAnimation();
        }
      };
      routeAnimation.addListener(listener);
      return;
    }
    _startAnimation();
  }

  void _startAnimation() {
    if (!mounted) return;
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _position, child: widget.child),
    );
  }
}
