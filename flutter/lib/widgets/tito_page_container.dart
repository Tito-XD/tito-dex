import 'package:flutter/material.dart';

import '../theme/tito_skin.dart';
import 'tito_paper.dart';

/// Opaque Material surface matching [DeviceShell] so route transitions never
/// flash through a transparent or mismatched background.
class TitoPageContainer extends StatelessWidget {
  const TitoPageContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    // Edge-to-edge shell: the surface paints behind the system bars so
    // predictive back retracts the whole screen; content remains safe.
    final page = TitoPageBackground(child: SafeArea(child: child));
    return Scaffold(
      backgroundColor: skin.pageBase,
      body: skin.isPlastic ? BackdropGroup(child: page) : page,
    );
  }
}
