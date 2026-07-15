import 'package:flutter/material.dart';

/// Stable keyed content swap without an application-defined animation.
///
/// The name remains for call-site compatibility while routes and controls use
/// Android's standard Material motion instead of animating each card body.
class TitoAnimatedSizeSwitcher extends StatelessWidget {
  const TitoAnimatedSizeSwitcher({
    super.key,
    required this.switchKey,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final Key switchKey;
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: switchKey, child: child);
  }
}
