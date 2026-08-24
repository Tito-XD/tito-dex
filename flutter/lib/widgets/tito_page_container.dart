import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';
import 'liquid_glass.dart';

/// Opaque page backdrop matching [DeviceShell] so route transitions never flash
/// through a transparent or mismatched surface.
class TitoPageContainer extends StatelessWidget {
  const TitoPageContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TitoColors.glassBackgroundBottom,
      body: BackdropGroup(
        child: LiquidGlassBackground(
          // Edge-to-edge shell: the light field paints behind the system bars
          // while SafeArea keeps route content out of native chrome.
          child: SafeArea(child: child),
        ),
      ),
    );
  }
}
