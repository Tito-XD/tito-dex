import 'package:flutter/material.dart';

import '../theme/device_layout.dart';
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
    final radius = DeviceLayout.rLg(context);
    final (tint, opacity) = switch (variant) {
      StickerVariant.cream => (TitoColors.card, 0.68),
      StickerVariant.deep => (TitoColors.deepBlue, 0.86),
      StickerVariant.sky => (TitoColors.skyBlue, 0.64),
      StickerVariant.mint => (TitoColors.mint, 0.68),
      StickerVariant.softYellow => (TitoColors.softYellow, 0.72),
    };

    // Keep the existing live depth preference, but render every semantic card
    // through one translucent material instead of duplicating surface logic.
    return ListenableBuilder(
      listenable: retroStyle,
      builder: (context, inner) => LiquidGlassSurface(
        tint: tint,
        opacity: opacity,
        radius: radius,
        blurSigma: 14,
        padding: padding,
        boxShadow: retroStyle.enabled ? TitoShadows.sticker : null,
        child: inner!,
      ),
      child: child,
    );
  }
}
