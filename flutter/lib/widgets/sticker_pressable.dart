import 'package:flutter/material.dart';

import '../theme/tito_surface_tokens.dart';
import '../theme/retro_style.dart';
import 'handheld_input.dart';

/// Trainer's Journal uses the original hard physical sticker press, Solid
/// Plastic uses the softer glass depth recipe, and Flat UI delegates feedback
/// to its Material state layers.
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

class _StickerPressableState extends State<StickerPressable> {
  static const _minHold = Duration(milliseconds: 120);

  var _pressed = false;
  DateTime? _pressedAt;

  void _setPressed(bool pressed) {
    if (!mounted) return;
    if (pressed) {
      if (!_pressed) {
        _pressedAt = DateTime.now();
        setState(() => _pressed = true);
      }
      return;
    }
    if (!_pressed) return;
    final elapsed = DateTime.now().difference(_pressedAt ?? DateTime.now());
    if (elapsed < _minHold) {
      Future<void>.delayed(_minHold - elapsed, () {
        if (mounted && _pressed) setState(() => _pressed = false);
      });
      return;
    }
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = TitoSurfaceTokens.of(context);
    if (tokens.pressSink == 0) return widget.child;

    return ListenableBuilder(
      listenable: retroStyle,
      builder: (context, child) {
        final depthEnabled = retroStyle.enabled;
        final keyHeld = widget.interactive && HandheldPressed.of(context);
        final sunk =
            depthEnabled && widget.interactive && (_pressed || keyHeld);
        final sink = tokens.pressSink;
        final restingShadow = tokens.controlShadow;
        final pressedShadow = tokens.pressedShadow;
        Widget result = AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, sunk ? sink : 0, 0),
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: !depthEnabled || !widget.ownShadow
                ? null
                : sunk
                ? pressedShadow
                : restingShadow,
          ),
          child: child,
        );
        if (widget.interactive) {
          result = Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _setPressed(true),
            onPointerUp: (_) => _setPressed(false),
            onPointerCancel: (_) => _setPressed(false),
            child: result,
          );
        }
        return result;
      },
      child: widget.child,
    );
  }
}
