import 'package:flutter/material.dart';

import '../theme/app_visual_style.dart';
import '../theme/device_layout.dart';
import '../theme/retro_style.dart';
import '../theme/tito_colors.dart';

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
    final radius = DeviceLayout.rLg(context);
    final scheme = Theme.of(context).colorScheme;
    if (!appVisualStyle.usesFlatUi) {
      final colors = switch (variant) {
        StickerVariant.cream => (TitoColors.card, TitoColors.ink),
        StickerVariant.deep => (TitoColors.deepBlue, TitoColors.card),
        StickerVariant.sky => (TitoColors.skyBlue, TitoColors.ink),
        StickerVariant.mint => (TitoColors.mint, TitoColors.ink),
        StickerVariant.softYellow => (TitoColors.softYellow, TitoColors.ink),
      };
      return ListenableBuilder(
        listenable: retroStyle,
        builder: (context, inner) => DecoratedBox(
          decoration: BoxDecoration(
            color: colors.$1,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: TitoColors.ink, width: TitoBorders.card),
            boxShadow: retroStyle.enabled ? TitoShadows.sticker : null,
          ),
          child: inner,
        ),
        child: Padding(padding: padding, child: child),
      );
    }
    final colors = switch (variant) {
      StickerVariant.cream => (scheme.surfaceContainerLow, scheme.onSurface),
      StickerVariant.deep => (scheme.primary, scheme.onPrimary),
      StickerVariant.sky => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      StickerVariant.mint => (TitoColors.mint, TitoColors.ink),
      StickerVariant.softYellow => (TitoColors.softYellow, TitoColors.ink),
    };

    // Keep the existing preference contract: enabled selects a lightly raised
    // Flat UI card; disabled selects its outlined variant.
    return ListenableBuilder(
      listenable: retroStyle,
      builder: (context, inner) => Material(
        type: MaterialType.card,
        color: colors.$1,
        elevation: retroStyle.enabled ? 1 : 0,
        shadowColor: scheme.shadow,
        surfaceTintColor: scheme.surfaceTint,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: retroStyle.enabled
              ? BorderSide.none
              : BorderSide(color: scheme.outlineVariant),
        ),
        child: inner,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
