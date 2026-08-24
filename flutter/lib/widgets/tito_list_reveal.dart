import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../theme/motion_preferences.dart';
import '../theme/tito_motion.dart';

/// Small fade + eight-pixel lift for list/grid items and page sections.
///
/// A bounded per-route memory prevents lazily disposed rows from replaying just
/// because the player scrolled them back into view. A new widget/replay key is
/// still treated as a new result set and can reveal again.
class TitoListReveal extends StatefulWidget {
  const TitoListReveal({
    super.key,
    this.delay = Duration.zero,
    this.enabled = true,
    this.replayKey,
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

  /// Optional generation/filter identity. Changing it permits the same row key
  /// to reveal as part of a genuinely new result set.
  final Object? replayKey;

  final Widget child;

  static final LinkedHashSet<_RevealMemoryKey> _playedItems =
      LinkedHashSet<_RevealMemoryKey>();
  static const _memoryLimit = 2048;

  @override
  State<TitoListReveal> createState() => _TitoListRevealState();
}

class _TitoListRevealState extends State<TitoListReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  Timer? _delayTimer;
  Animation<double>? _routeAnimation;
  VoidCallback? _routeListener;
  _RevealMemoryKey? _memoryKey;
  bool _configured = false;
  bool _started = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: TitoMotion.listReveal,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    motionPreferences.addListener(_handleMotionPreferenceChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final memoryKey = _resolveMemoryKey();

    if (_memoryKey != memoryKey) {
      _memoryKey = memoryKey;
      if (_isRemembered(memoryKey)) {
        _settle(remember: false);
      }
    }

    if (reduceMotion != _reduceMotion) {
      _reduceMotion = reduceMotion;
      if (reduceMotion) {
        _settle();
      }
    }

    if (!_canAnimate) {
      _settle();
    }

    if (!_configured) {
      _configured = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startIfAllowed();
        }
      });
    }
  }

  @override
  void didUpdateWidget(TitoListReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    final memoryKey = _resolveMemoryKey();
    if (_memoryKey != memoryKey) {
      _cancelPendingStart();
      _memoryKey = memoryKey;
      if (_isRemembered(memoryKey)) {
        _settle(remember: false);
      } else if (_canAnimate) {
        _started = false;
        _controller.value = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _startIfAllowed();
          }
        });
      } else {
        _settle();
      }
      return;
    }

    if (!widget.enabled && oldWidget.enabled) {
      _settle();
    }
  }

  bool get _canAnimate =>
      widget.enabled &&
      motionPreferences.listAnimationsEnabled &&
      !_reduceMotion;

  _RevealMemoryKey _resolveMemoryKey() {
    final route = ModalRoute.of(context);
    final navigator = Navigator.maybeOf(context);
    final scope = route ?? navigator ?? context.owner ?? context;
    final widgetKey = widget.key ?? widget.child.key;
    final item = (
      widget.replayKey?.toString(),
      widgetKey == null
          ? (widget.child.runtimeType, widget.delay.inMicroseconds)
          : (widgetKey.runtimeType, widgetKey.toString()),
    );
    return _RevealMemoryKey(identityHashCode(scope), item);
  }

  bool _isRemembered(_RevealMemoryKey key) =>
      TitoListReveal._playedItems.contains(key);

  void _remember() {
    final key = _memoryKey;
    if (key == null) {
      return;
    }
    final played = TitoListReveal._playedItems;
    played.remove(key);
    played.add(key);
    if (played.length > TitoListReveal._memoryLimit) {
      played.remove(played.first);
    }
  }

  void _handleMotionPreferenceChanged() {
    if (!mounted) {
      return;
    }
    if (!motionPreferences.listAnimationsEnabled) {
      _settle();
    }
  }

  void _startIfAllowed() {
    if (_started) {
      return;
    }
    if (!_canAnimate || (_memoryKey != null && _isRemembered(_memoryKey!))) {
      _settle();
      return;
    }
    _startAfterRouteTransition();
  }

  void _startAfterRouteTransition() {
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (routeAnimation != null &&
        routeAnimation.status != AnimationStatus.completed) {
      _routeAnimation = routeAnimation;
      _routeListener = () {
        if (routeAnimation.status == AnimationStatus.completed) {
          _removeRouteListener();
          _startAnimation();
        }
      };
      routeAnimation.addListener(_routeListener!);
      return;
    }
    _startAnimation();
  }

  void _startAnimation() {
    if (!mounted || _started) {
      return;
    }
    if (!_canAnimate) {
      _settle();
      return;
    }
    _started = true;
    _remember();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _delayTimer = Timer(widget.delay, () {
        _delayTimer = null;
        if (mounted && _canAnimate) {
          _controller.forward();
        } else if (mounted) {
          _settle();
        }
      });
    }
  }

  void _settle({bool remember = true}) {
    _cancelPendingStart();
    _started = true;
    if (remember) {
      _remember();
    }
    _controller.value = 1;
  }

  void _cancelPendingStart() {
    _delayTimer?.cancel();
    _delayTimer = null;
    _removeRouteListener();
  }

  void _removeRouteListener() {
    final listener = _routeListener;
    if (listener != null) {
      _routeAnimation?.removeListener(listener);
    }
    _routeListener = null;
    _routeAnimation = null;
  }

  @override
  void dispose() {
    motionPreferences.removeListener(_handleMotionPreferenceChanged);
    _cancelPendingStart();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (context, child) {
        final progress = _progress.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, TitoMotion.listTravel * (1 - progress)),
            child: child,
          ),
        );
      },
    );
  }
}

class _RevealMemoryKey {
  const _RevealMemoryKey(this.scope, this.item);

  final int scope;
  final Object item;

  @override
  bool operator ==(Object other) =>
      other is _RevealMemoryKey && other.scope == scope && other.item == item;

  @override
  int get hashCode => Object.hash(scope, item);
}
