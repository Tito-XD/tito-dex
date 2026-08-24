import 'package:flutter/material.dart';

/// Compatibility wrapper for call sites that previously added sticker press
/// physics and a second shadow.
///
/// Material controls already expose press, hover, focus and disabled states
/// through their Ink state layer, so this branch deliberately avoids adding
/// translation or scale on top. Keeping the wrapper lets the experiment stay
/// visual-only and leaves every feature widget's interaction contract intact.
class StickerPressable extends StatelessWidget {
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
  Widget build(BuildContext context) => child;
}
