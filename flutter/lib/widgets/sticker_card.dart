import 'package:flutter/material.dart';

import '../theme/device_layout.dart';
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: TitoColors.ink, width: TitoBorders.card),
        // 0.6.6 experiment: drop the hard offset shadow — the bold ink
        // border carries the sticker look on its own, flatter and cleaner.
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
