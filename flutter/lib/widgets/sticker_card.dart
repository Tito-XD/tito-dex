import 'package:flutter/material.dart';

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
    final colors = switch (variant) {
      StickerVariant.cream => (TitoColors.card, TitoColors.ink),
      StickerVariant.deep => (TitoColors.deepBlue, TitoColors.card),
      StickerVariant.sky => (TitoColors.skyBlue, TitoColors.ink),
      StickerVariant.mint => (TitoColors.mint, TitoColors.ink),
      StickerVariant.softYellow => (TitoColors.softYellow, TitoColors.ink),
    };

    // Retro style: the signature solid drop shadow on every card; flat mode
    // lets the bold ink border carry the sticker look on its own.
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
}
