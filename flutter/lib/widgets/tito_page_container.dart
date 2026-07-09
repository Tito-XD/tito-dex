import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';

/// Opaque page backdrop matching [DeviceShell] so route transitions never flash
/// through a transparent or mismatched surface.
class TitoPageContainer extends StatelessWidget {
  const TitoPageContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TitoColors.slateBlue,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              TitoColors.skyBlue,
              TitoColors.slateBlue,
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}
