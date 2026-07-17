import 'package:flutter/material.dart';

import '../theme/retro_style.dart';
import '../theme/tito_colors.dart';

/// Retro press physics for interactive stickers: the signature solid drop
/// shadow, and on touch-down the sticker sinks ~3px while the shadow
/// squashes — releasing springs it back. All of it disappears when the
/// Retro style toggle is off, leaving the flat look untouched.
///
/// Uses a [Listener] so the child's own InkWell/GestureDetector keeps
/// receiving its taps unchanged.
class StickerPressable extends StatefulWidget {
  const StickerPressable({
    super.key,
    required this.borderRadius,
    required this.child,
    this.interactive = true,
  });

  final BorderRadius borderRadius;
  final Widget child;

  /// When false only the static shadow applies (display-only stickers).
  final bool interactive;

  @override
  State<StickerPressable> createState() => _StickerPressableState();
}

class _StickerPressableState extends State<StickerPressable> {
  var _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed != pressed && mounted) {
      setState(() => _pressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: retroStyle,
      builder: (context, child) {
        final retro = retroStyle.enabled;
        final sunk = retro && widget.interactive && _pressed;
        Widget result = AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, sunk ? 3 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: !retro
                ? null
                : sunk
                ? TitoShadows.stickerPressed
                : TitoShadows.sticker,
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
