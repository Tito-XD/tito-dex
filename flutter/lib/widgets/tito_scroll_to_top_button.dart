import 'package:flutter/material.dart';

import '../theme/tito_surface_tokens.dart';

/// Floating scroll-to-top action. Flat UI uses the stock small Material FAB
/// so it matches the rest of the Material surface; the gradient themes keep
/// the soft-yellow sticker disc with a themed stroke.
class TitoScrollToTopButton extends StatelessWidget {
  const TitoScrollToTopButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = TitoSurfaceTokens.of(context);
    if (tokens.finish == TitoSurfaceFinish.material) {
      return FloatingActionButton.small(
        heroTag: null,
        tooltip: label,
        onPressed: onTap,
        child: const Icon(Icons.vertical_align_top_rounded),
      );
    }
    final surface = tokens.surface(TitoSurfaceRole.softYellow);
    final accent = tokens.surface(TitoSurfaceRole.accent);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: surface.fill,
        shape: CircleBorder(side: surface.outline),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 44,
            child: Icon(
              Icons.vertical_align_top_rounded,
              color: accent.foreground,
            ),
          ),
        ),
      ),
    );
  }
}
