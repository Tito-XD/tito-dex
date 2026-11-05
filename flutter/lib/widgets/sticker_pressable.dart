import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/motion_preferences.dart';
import '../theme/tito_motion.dart';
import '../theme/tito_surface_tokens.dart';
import '../theme/retro_style.dart';
import 'handheld_input.dart';

/// Press feedback for buttons and cards. Trainer's Journal sinks like a hard
/// physical sticker, Solid Plastic uses the softer glass depth recipe, and
/// Flat UI delegates feedback to its Material state layers.
///
/// Release is a real under-damped spring: the surface rises back, overshoots
/// a hair past rest and settles. Reduced motion snaps straight back.
class StickerPressable extends StatefulWidget {
  const StickerPressable({
    super.key,
    required this.borderRadius,
    required this.child,
    this.interactive = true,
    this.ownShadow = true,
  });

  final BorderRadius borderRadius;
  final Widget child;
  final bool interactive;
  final bool ownShadow;

  @override
  State<StickerPressable> createState() => _StickerPressableState();
}

class _StickerPressableState extends State<StickerPressable>
    with SingleTickerProviderStateMixin {
  static const _minHold = Duration(milliseconds: 120);
  static const _pressIn = Duration(milliseconds: 70);

  // 0 = resting, 1 = fully pressed; the spring dips below 0 on release.
  late final AnimationController _press;
  var _pointerDown = false;
  var _keyHeld = false;
  DateTime? _pressedAt;

  bool get _down => _pointerDown || _keyHeld;

  @override
  void initState() {
    super.initState();
    _press = AnimationController.unbounded(vsync: this);
  }

  bool get _reduced =>
      MediaQuery.disableAnimationsOf(context) ||
      !motionPreferences.listAnimationsEnabled;

  void _sync() {
    if (!mounted) return;
    if (_down) {
      _pressedAt ??= DateTime.now();
      if (_reduced) {
        _press.value = 1;
      } else {
        _press.animateTo(1, duration: _pressIn, curve: Curves.easeOut);
      }
      return;
    }
    final pressedAt = _pressedAt;
    if (pressedAt == null) return;
    final elapsed = DateTime.now().difference(pressedAt);
    if (elapsed < _minHold) {
      // A quick tap still shows a full press before springing back.
      Future<void>.delayed(_minHold - elapsed, () {
        if (mounted && !_down) _release();
      });
      return;
    }
    _release();
  }

  void _release() {
    _pressedAt = null;
    if (_reduced) {
      _press.value = 0;
      return;
    }
    _press
        .animateWith(
          SpringSimulation(
            TitoMotion.pressSpring,
            _press.value,
            0,
            _press.velocity,
            tolerance: const Tolerance(distance: 0.002, velocity: 0.02),
          ),
        )
        .then((_) {
          // Land exactly at rest so the shadow matches the resting recipe.
          if (mounted && !_down) _press.value = 0;
        });
  }

  void _setPointer(bool down) {
    if (_pointerDown == down) return;
    _pointerDown = down;
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final held = widget.interactive && HandheldPressed.of(context);
    if (held != _keyHeld) {
      _keyHeld = held;
      // Dependencies change during build; animate after this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  @override
  void didUpdateWidget(covariant StickerPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.interactive && oldWidget.interactive) {
      _pointerDown = _keyHeld = false;
      _pressedAt = null;
      _press.value = 0;
    }
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = TitoSurfaceTokens.of(context);
    final sink = tokens.pressSink;
    if (sink == 0) return widget.child;

    Widget result = ListenableBuilder(
      listenable: Listenable.merge([retroStyle, _press]),
      builder: (context, child) {
        final depthEnabled = retroStyle.enabled;
        final v = _press.value;
        final pressed = v.clamp(0.0, 1.0);
        final shadow = !depthEnabled || !widget.ownShadow
            ? null
            : pressed == 0
            ? tokens.controlShadow
            : pressed == 1
            ? tokens.pressedShadow
            : BoxShadow.lerpList(
                tokens.controlShadow,
                tokens.pressedShadow,
                pressed,
              );
        return Transform.translate(
          offset: Offset(0, depthEnabled ? sink * v : 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: shadow,
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
    if (widget.interactive) {
      result = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _setPointer(true),
        onPointerUp: (_) => _setPointer(false),
        onPointerCancel: (_) => _setPointer(false),
        child: result,
      );
    }
    return result;
  }
}
