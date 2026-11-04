import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';
import '../theme/tito_surface_tokens.dart';
import 'handheld_input.dart';
import 'liquid_glass.dart';

/// Circular title-bar button shared by the home header and every secondary
/// page header. It owns the per-finish look so pages never branch on theme:
/// plastic renders [LiquidGlassRoundButton], paper and material render a
/// filled circle from the `headerButton` surface role.
class TitoHeaderRoundButton extends StatelessWidget {
  const TitoHeaderRoundButton({
    super.key,
    required this.size,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    this.fill,
    this.glassOpacity = 0.9,
  });

  final double size;
  final String semanticLabel;
  final VoidCallback? onTap;
  final Widget child;

  /// Overrides the role fill (and the plastic glass tint), e.g. an edition
  /// accent behind a letter badge.
  final Color? fill;
  final double glassOpacity;

  @override
  Widget build(BuildContext context) {
    final tokens = TitoSurfaceTokens.of(context);
    final button = tokens.surface(TitoSurfaceRole.headerButton);
    final content = IconTheme.merge(
      data: IconThemeData(color: button.foreground),
      child: child,
    );

    if (tokens.finish == TitoSurfaceFinish.plastic) {
      return LiquidGlassRoundButton(
        size: size,
        semanticLabel: semanticLabel,
        onTap: onTap,
        tint: fill ?? TitoColors.card,
        opacity: glassOpacity,
        child: content,
      );
    }

    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Semantics(
        button: onTap != null,
        label: semanticLabel,
        child: Material(
          color: fill ?? button.fill,
          shape: CircleBorder(side: button.outline),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox.square(dimension: size, child: content),
          ),
        ),
      ),
    );
  }
}

/// Icon variant of [TitoHeaderRoundButton] with a tooltip; the glyph is 62%
/// of the button so the gear reads at one size on every title bar.
class TitoHeaderIconButton extends StatelessWidget {
  const TitoHeaderIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.size,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: TitoHeaderRoundButton(
        size: size,
        semanticLabel: label,
        onTap: onTap,
        child: Icon(icon, size: size * 0.62),
      ),
    );
  }
}
