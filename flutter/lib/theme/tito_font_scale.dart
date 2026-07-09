import 'package:flutter/material.dart';

/// Overrides handheld font scaling — use on Search to keep default sizes.
class TitoFontScale extends InheritedWidget {
  const TitoFontScale({
    super.key,
    required this.multiplier,
    required super.child,
  });

  final double multiplier;

  static TitoFontScale? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TitoFontScale>();
  }

  @override
  bool updateShouldNotify(covariant TitoFontScale oldWidget) {
    return oldWidget.multiplier != multiplier;
  }
}
