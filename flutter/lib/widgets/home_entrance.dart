import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/motion_preferences.dart';
import '../theme/tito_motion.dart';

/// A single, finite entrance above Home's adaptive layout. The same state
/// survives data refreshes and orientation changes; returning never replays it.
class HomeEntrance extends StatefulWidget {
  const HomeEntrance({super.key, required this.ready, required this.child});

  final bool ready;
  final Widget child;

  static const itemCount = 6;
  static const stagger = Duration(milliseconds: 28);

  @override
  State<HomeEntrance> createState() => _HomeEntranceState();
}

class _HomeEntranceState extends State<HomeEntrance>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _controller = AnimationController(
    vsync: this,
    duration: TitoMotion.listReveal + HomeEntrance.stagger * 5,
  );
  Animation<double>? _routeAnimation;
  bool _consumed = false;
  bool _scheduled = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleKey);
    motionPreferences.addListener(_preferencesChanged);
  }

  bool get _visible =>
      _foreground &&
      TickerMode.valuesOf(context).enabled &&
      ModalRoute.of(context)?.isCurrent != false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TitoMotion.disabled(context) || (!_visible && _consumed)) {
      _settle();
    }
    _configure();
  }

  @override
  void didUpdateWidget(HomeEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ready && !widget.ready) _settle();
    _configure();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && _consumed) _settle();
    if (_foreground) _configure();
  }

  void _preferencesChanged() {
    if (!motionPreferences.listAnimationsEnabled) _settle();
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent && mounted && _visible) _settle();
    // The normal D-pad/activation handler must still receive this event.
    return false;
  }

  void _configure() {
    if (_consumed || _scheduled || !widget.ready || !_visible) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _consumed || !widget.ready || !_visible) return;
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
      if (widget.ready && _visible) _start();
    } else if (status == AnimationStatus.reverse ||
        status == AnimationStatus.dismissed) {
      _settle();
    }
  }

  void _start() {
    if (_consumed) return;
    _consumed = true;
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
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleKey);
    motionPreferences.removeListener(_preferencesChanged);
    _detachRoute();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _settle(),
    child: _HomeEntranceScope(
      animation: _controller,
      ready: widget.ready,
      child: widget.child,
    ),
  );
}

class _HomeEntranceScope extends InheritedWidget {
  const _HomeEntranceScope({
    required this.animation,
    required this.ready,
    required super.child,
  });

  final Animation<double> animation;
  final bool ready;

  @override
  bool updateShouldNotify(_HomeEntranceScope oldWidget) =>
      ready != oldWidget.ready || animation != oldWidget.animation;
}

class HomeEntranceItem extends StatelessWidget {
  const HomeEntranceItem({super.key, required this.index, required this.child})
    : assert(index >= 0 && index < HomeEntrance.itemCount);

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_HomeEntranceScope>();
    if (scope == null) return child;
    return AnimatedBuilder(
      animation: scope.animation,
      child: child,
      builder: (context, child) {
        final total = TitoMotion.listReveal + HomeEntrance.stagger * 5;
        final progress = !scope.ready || scope.animation.value == 1
            ? 1.0
            : ((scope.animation.value * total.inMicroseconds -
                          index * HomeEntrance.stagger.inMicroseconds) /
                      TitoMotion.listReveal.inMicroseconds)
                  .clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(progress);
        return Opacity(
          // Keep every action visible to both the player and the current
          // geometry-based D-pad traversal even before its stagger begins.
          opacity: 0.72 + 0.28 * eased,
          child: Transform.scale(
            // Keep painted and hit-tested bounds inside the adaptive parent's
            // layout box; a lift can draw the bottom edge outside its hit area.
            scale: 0.98 + 0.02 * eased,
            child: child,
          ),
        );
      },
    );
  }
}
