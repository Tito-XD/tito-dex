import 'package:flutter/material.dart';

import '../../theme/tito_colors.dart';

enum StickerVariant { cream, deep, sky }

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
    final colors = switch (variant) {
      StickerVariant.cream => (TitoColors.card, TitoColors.ink),
      StickerVariant.deep => (TitoColors.deepBlue, TitoColors.card),
      StickerVariant.sky => (TitoColors.skyBlue, TitoColors.ink),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(TitoRadii.lg),
        border: Border.all(color: TitoColors.ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3818283B),
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
