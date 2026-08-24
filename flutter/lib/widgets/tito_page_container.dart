import 'package:flutter/material.dart';

import '../theme/app_visual_style.dart';
import '../theme/tito_colors.dart';

/// Opaque Material surface matching [DeviceShell] so route transitions never
/// flash through a transparent or mismatched background.
class TitoPageContainer extends StatelessWidget {
  const TitoPageContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final material = appVisualStyle.usesMaterial;
    return Scaffold(
      backgroundColor: material ? scheme.surface : TitoColors.slateBlue,
      // Edge-to-edge shell: the surface paints behind the system bars so
      // predictive back retracts the whole screen; content remains safe.
      body: material
          ? ColoredBox(
              color: scheme.surface,
              child: SafeArea(child: child),
            )
          : DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF5D728A), TitoColors.slateBlue],
                ),
              ),
              child: SafeArea(child: child),
            ),
    );
  }
}
