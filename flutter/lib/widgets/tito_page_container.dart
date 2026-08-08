import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';

/// Opaque page backdrop matching [DeviceShell] so route transitions never flash
/// through a transparent or mismatched surface.
class TitoPageContainer extends StatelessWidget {
  const TitoPageContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TitoColors.slateBlue,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // v0.6.7 header refresh (picked in the gradient template v3):
            // #5D728A → slateBlue, a 60% melt from deepBlue into slate. The
            // cream title now sits on the dark end instead of the palest
            // end (was skyBlue→slate, 1.64:1 contrast).
            colors: [Color(0xFF5D728A), Color(0xFF7B91A6)],
          ),
        ),
        // Edge-to-edge shell: the gradient paints behind the system bars so
        // predictive back retracts the whole screen; the SafeArea keeps page
        // content where the old shell-level SafeArea put it.
        child: SafeArea(child: child),
      ),
    );
  }
}
