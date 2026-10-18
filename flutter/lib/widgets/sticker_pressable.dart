import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/motion_preferences.dart';
import '../theme/retro_style.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_motion.dart';
import '../theme/tito_skin.dart';
import 'handheld_input.dart';

/// Journal keeps its hard shadow and physical press; Plastic adds a restrained
/// compression. Flat delegates feedback to the child's Material state layer.
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
  final _pointers = <int, Offset>{};
  late final AnimationController _press;
  double _target = 0;

  @override
  void initState() {
    super.initState();
    _press = AnimationController.unbounded(vsync: this, value: 0);
    retroStyle.addListener(_preferencesChanged);
    motionPreferences.addListener(_preferencesChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TitoMotion.disabled(context) || TitoSkin.of(context).isFlat) {
      _pointers.clear();
    }
  }

  @override
  void didUpdateWidget(StickerPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.interactive) _pointers.clear();
  }

  void _preferencesChanged() {
    setState(() {
      if (!retroStyle.enabled || !motionPreferences.listAnimationsEnabled) {
        _pointers.clear();
      }
    });
  }

  void _release(int pointer) {
    if (mounted && _pointers.containsKey(pointer)) {
      setState(() => _pointers.remove(pointer));
    }
  }

  @override
  void dispose() {
    retroStyle.removeListener(_preferencesChanged);
    motionPreferences.removeListener(_preferencesChanged);
    _pointers.clear();
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    if (skin.isFlat) {
      _target = 0;
      _press.value = 0;
      return widget.child;
    }

    final motion = TitoMotion.of(context);
    final depthEnabled = retroStyle.enabled;
    final animate = depthEnabled && !TitoMotion.disabled(context);
    final keyHeld = HandheldPressed.of(context);
    final sunk =
        animate && widget.interactive && (_pointers.isNotEmpty || keyHeld);
    final target = sunk ? 1.0 : 0.0;
    if (!animate || !widget.interactive) {
      _target = 0;
      if (_press.value != 0 || _press.isAnimating) _press.value = 0;
    } else if (_target != target) {
      _target = target;
      // Retarget the actual painted value, not a tween re-evaluated with the
      // new curve. That keeps rapid press/release/repress position-continuous.
      _press.animateTo(
        target,
        duration: sunk ? motion.press : motion.release,
        curve: sunk ? motion.settleCurve : motion.releaseCurve,
      );
    }
    final restingShadow = skin.isJournal
        ? TrainerJournalShadows.sticker
        : SolidPlasticShadows.sticker;
    final pressedShadow = skin.isJournal
        ? TrainerJournalShadows.stickerPressed
        : SolidPlasticShadows.stickerPressed;

    return Listener(
      // The listener and hit region stay at their original size while only
      // painting moves. Each release belongs to its pointer, with no delayed
      // callback that could release a newer press.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (mounted && animate && widget.interactive) {
          setState(() => _pointers[event.pointer] = event.position);
        }
      },
      onPointerMove: (event) {
        final origin = _pointers[event.pointer];
        if (origin != null && (event.position - origin).distance > kTouchSlop) {
          _release(event.pointer);
        }
      },
      onPointerUp: (event) => _release(event.pointer),
      onPointerCancel: (event) => _release(event.pointer),
      child: AnimatedBuilder(
        animation: _press,
        child: widget.child,
        builder: (context, child) {
          // Apply the accessibility change on this very frame, even if an
          // implicit animation was halfway through a previous press.
          final progress = animate && widget.interactive ? _press.value : 0.0;
          final shadowProgress = progress.clamp(0.0, 1.0);
          return Transform.translate(
            offset: Offset(0, motion.pressDepth * progress),
            transformHitTests: false,
            child: Transform.scale(
              scaleX: 1 + (motion.pressScaleX - 1) * progress,
              scaleY: 1 + (motion.pressScaleY - 1) * progress,
              transformHitTests: false,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  boxShadow: !depthEnabled || !widget.ownShadow
                      ? null
                      : BoxShadow.lerpList(
                          restingShadow,
                          pressedShadow,
                          shadowProgress,
                        ),
                ),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
