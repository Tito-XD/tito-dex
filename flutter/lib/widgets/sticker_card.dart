import 'package:flutter/material.dart';

import '../theme/tito_surface_tokens.dart';
import '../theme/retro_style.dart';
import '../theme/tito_colors.dart';
import 'liquid_glass.dart';

enum StickerVariant { cream, deep, sky, mint, softYellow }

class StickerCard extends StatelessWidget {
  const StickerCard({
    super.key,
    required this.child,
    this.variant = StickerVariant.cream,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final StickerVariant variant;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    const radius = TitoRadii.lg;
    final scheme = Theme.of(context).colorScheme;
    final tokens = TitoSurfaceTokens.of(context);
    final role = switch (variant) {
      StickerVariant.cream => TitoSurfaceRole.card,
      StickerVariant.deep => TitoSurfaceRole.deep,
      StickerVariant.sky => TitoSurfaceRole.sky,
      StickerVariant.mint => TitoSurfaceRole.mint,
      StickerVariant.softYellow => TitoSurfaceRole.softYellow,
    };
    final surface = tokens.surface(role);
    final shadow = variant == StickerVariant.deep
        ? tokens.deepShadow
        : tokens.cardShadow;
    if (!tokens.usesMaterial) {
      return ListenableBuilder(
        listenable: retroStyle,
        builder: (context, inner) => tokens.usesOptics
            ? LiquidGlassSurface(
                tint: surface.fill,
                opacity: surface.opacity,
                borderColor: surface.outline.color,
                borderWidth: surface.outline.width,
                radius: radius,
                padding: padding,
                boxShadow: retroStyle.enabled ? shadow : null,
                child: inner!,
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: surface.fill,
                  borderRadius: BorderRadius.circular(radius),
                  border: surface.border,
                  boxShadow: retroStyle.enabled ? shadow : null,
                ),
                child: Padding(padding: padding, child: inner),
              ),
        child: Material(type: MaterialType.transparency, child: child),
      );
    }
    // Keep the existing preference contract: enabled selects a lightly raised
    // Flat UI card; disabled selects its outlined variant.
    //
    // Paint the lip with [TitoShadows.sticker] *outside* the clipped Material.
    // `Material(elevation + clipAntiAlias)` eats its own shadow — and on the
    // first inflate (search results) Impeller often skips that elevation
    // until a later frame, which is the "cut-off sticker" flash.
    return ListenableBuilder(
      listenable: retroStyle,
      builder: (context, inner) {
        final raised = retroStyle.enabled;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: raised ? tokens.cardShadow : null,
          ),
          child: Material(
            type: MaterialType.card,
            color: surface.fill,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: raised ? scheme.surfaceTint : Colors.transparent,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: raised ? BorderSide.none : tokens.flatCardOutline,
            ),
            child: inner,
          ),
        );
      },
      child: Padding(padding: padding, child: child),
    );
  }
}
