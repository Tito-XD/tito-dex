import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';
import '../theme/tito_surface_tokens.dart';
import 'liquid_glass.dart';

/// Opaque Material surface matching [DeviceShell] so route transitions never
/// flash through a transparent or mismatched background.
class TitoPageContainer extends StatelessWidget {
  const TitoPageContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final finish = TitoSurfaceTokens.of(context).finish;
    final flatUi = finish == TitoSurfaceFinish.material;
    if (finish == TitoSurfaceFinish.plastic) {
      return Scaffold(
        backgroundColor: TitoColors.glassBackgroundBottom,
        body: BackdropGroup(
          child: LiquidGlassBackground(child: SafeArea(child: child)),
        ),
      );
    }
    return Scaffold(
      backgroundColor: flatUi ? scheme.surface : TitoColors.slateBlue,
      // Edge-to-edge shell: the surface paints behind the system bars so
      // predictive back retracts the whole screen; content remains safe.
      body: flatUi
          ? ColoredBox(
              color: scheme.surface,
              child: SafeArea(child: child),
            )
          : DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    TitoColors.shellGradientTop,
                    TitoColors.shellGradientBottom,
                  ],
                ),
              ),
              child: SafeArea(child: child),
            ),
    );
  }
}
