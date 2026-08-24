import 'package:flutter/material.dart';

/// Opaque Material surface matching [DeviceShell] so route transitions never
/// flash through a transparent or mismatched background.
class TitoPageContainer extends StatelessWidget {
  const TitoPageContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      // Edge-to-edge shell: the surface paints behind the system bars so
      // predictive back retracts the whole screen; content remains safe.
      body: ColoredBox(
        color: scheme.surface,
        child: SafeArea(child: child),
      ),
    );
  }
}
