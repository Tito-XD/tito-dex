import 'package:flutter/material.dart';

import '../theme/motion_preferences.dart';
import '../theme/tito_motion.dart';

/// One finite entrance shared by a screen's sections. Keep this above adaptive
/// layouts so rebuilding, changing data or returning from a route cannot replay
/// it. Readiness delays the first reveal without creating per-item timers.
class TitoEntrance extends StatefulWidget {
  const TitoEntrance({
    super.key,
    required this.child,
    required this.itemCount,
    this.ready = true,
  }) : assert(itemCount > 0);

  final Widget child;
  final int itemCount;
  final bool ready;

  @override
  State<TitoEntrance> createState() => _TitoEntranceState();
}

class _TitoEntranceState extends State<TitoEntrance>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);
  Animation<double>? _routeAnimation;
  TitoSurfaceMotion? _motion;
  bool _consumed = false;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    motionPreferences.addListener(_preferencesChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = TitoMotion.of(context);
    if (TitoMotion.disabled(context) ||
        (_motion != null && _motion != motion) ||
        ModalRoute.of(context)?.isCurrent == false) {
      _settle();
    }
    _motion = motion;
    _configure();
  }

  @override
  void didUpdateWidget(TitoEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configure();
  }

  void _preferencesChanged() {
    if (!motionPreferences.listAnimationsEnabled) _settle();
  }

  void _configure() {
    if (_consumed || _scheduled || !widget.ready) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _consumed || !widget.ready) return;
      final animation = ModalRoute.of(context)?.animation;
      if (animation != null && animation.status != AnimationStatus.completed) {
        _detachRoute();
        _routeAnimation = animation;
        animation.addStatusListener(_routeChanged);
      } else {
        _start();
      }
    });
  }

  void _routeChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _detachRoute();
      if (widget.ready) _start();
    } else if (status == AnimationStatus.reverse ||
        status == AnimationStatus.dismissed) {
      _settle();
    }
  }

  void _start() {
    if (_consumed) return;
    _consumed = true;
    final motion = _motion!;
    _controller.duration =
        motion.enter + motion.stagger * (widget.itemCount - 1);
    _controller.forward();
  }

  void _settle() {
    if (!mounted) return;
    _consumed = true;
    _detachRoute();
    _controller.value = 1;
  }

  void _detachRoute() {
    _routeAnimation?.removeStatusListener(_routeChanged);
    _routeAnimation = null;
  }

  @override
  void dispose() {
    motionPreferences.removeListener(_preferencesChanged);
    _detachRoute();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    // An early interaction settles the source before a Hero or focus action.
    onPointerDown: (_) => _settle(),
    child: Focus(
      canRequestFocus: false,
      onFocusChange: (focused) {
        if (focused) _settle();
      },
      child: _EntranceScope(
        animation: _controller,
        motion: _motion!,
        itemCount: widget.itemCount,
        ready: widget.ready || _consumed,
        child: widget.child,
      ),
    ),
  );
}

class _EntranceScope extends InheritedWidget {
  const _EntranceScope({
    required this.animation,
    required this.motion,
    required this.itemCount,
    required this.ready,
    required super.child,
  });

  final Animation<double> animation;
  final TitoSurfaceMotion motion;
  final int itemCount;
  final bool ready;

  @override
  bool updateShouldNotify(_EntranceScope oldWidget) =>
      motion != oldWidget.motion ||
      ready != oldWidget.ready ||
      itemCount != oldWidget.itemCount ||
      animation != oldWidget.animation;
}

class TitoEntranceItem extends StatelessWidget {
  const TitoEntranceItem({super.key, required this.index, required this.child})
    : assert(index >= 0);

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_EntranceScope>();
    if (scope == null) return child;
    assert(index < scope.itemCount);
    return AnimatedBuilder(
      animation: scope.animation,
      child: child,
      builder: (context, child) {
        final motion = scope.motion;
        final total = motion.enter + motion.stagger * (scope.itemCount - 1);
        final progress = !scope.ready || scope.animation.value == 1
            ? 1.0
            : ((scope.animation.value * total.inMicroseconds -
                          index * motion.stagger.inMicroseconds) /
                      motion.enter.inMicroseconds)
                  .clamp(0.0, 1.0);
        final eased = motion.settleCurve.transform(progress);
        final pop = motion.enterCurve.transform(progress);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, motion.travel * (1 - eased)),
            transformHitTests: false,
            child: Transform.scale(
              scale: motion.startScale + (1 - motion.startScale) * pop,
              transformHitTests: false,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
