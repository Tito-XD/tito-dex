import 'package:flutter/material.dart';

/// Smooth height transition when swapping children (v0.4.1 experimental).
///
/// Pair with a stable [switchKey] per logical view so [AnimatedSwitcher]
/// cross-fades while [AnimatedSize] eases layout height.
class TitoAnimatedSizeSwitcher extends StatelessWidget {
  const TitoAnimatedSizeSwitcher({
    super.key,
    required this.switchKey,
    required this.child,
    this.alignment = Alignment.topCenter,
    this.duration = const Duration(milliseconds: 220),
    this.switchDuration = const Duration(milliseconds: 200),
  });

  final Key switchKey;
  final Widget child;
  final Alignment alignment;
  final Duration duration;
  final Duration switchDuration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeInOut,
      alignment: alignment,
      child: AnimatedSwitcher(
        duration: switchDuration,
        layoutBuilder: (current, previous) =>
            current ?? const SizedBox.shrink(),
        child: KeyedSubtree(
          key: switchKey,
          child: child,
        ),
      ),
    );
  }
}
