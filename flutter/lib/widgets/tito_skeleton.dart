import 'package:flutter/material.dart';

import '../theme/retro_style.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_skin.dart';
import 'sticker_card.dart';
import 'type_badge.dart';

/// Placeholder block for loading layouts (detail header, cards, etc.).
class TitoSkeletonBox extends StatelessWidget {
  const TitoSkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.radius = TitoRadii.md,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    return ListenableBuilder(
      listenable: retroStyle,
      builder: (context, _) {
        final side = dexSkinSide(context);
        // Flat has no skin stroke while retro stickers are on, so a bar
        // takes the same outlined block as an uncaught dex cell.
        final border = side == BorderSide.none
            ? (skin.isFlat
                  ? Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.5,
                    )
                  : null)
            : Border.fromBorderSide(
                BorderSide(
                  color: side.color.withValues(alpha: 0.45),
                  width: side.width,
                ),
              );
        final fill = skin.isFlat
            ? skin.paper
            : Color.alphaBlend(skin.ink.withValues(alpha: 0.07), skin.paper);
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius),
            border: border,
          ),
        );
      },
    );
  }
}

class TitoDetailHeaderSkeleton extends StatelessWidget {
  const TitoDetailHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      variant: StickerVariant.deep,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Expanded(
            child: TitoSkeletonBox(height: 18, width: double.infinity),
          ),
          const SizedBox(width: 8),
          TitoSkeletonBox(height: 52, width: 52, radius: TitoRadii.sm),
        ],
      ),
    );
  }
}

class TitoCardSkeleton extends StatelessWidget {
  const TitoCardSkeleton({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TitoSkeletonBox(height: 14, width: 96),
          const SizedBox(height: 10),
          TitoSkeletonBox(height: height, width: double.infinity),
        ],
      ),
    );
  }
}

class TitoDexMiniCardSkeleton extends StatelessWidget {
  const TitoDexMiniCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    // Mirrors PokemonMiniCard: flexible sprite slot, number, name, type row.
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: TitoSkeletonBox(
              height: 40,
              width: 40,
              radius: skin.radiusSm,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const TitoSkeletonBox(height: 9, width: 32),
        const SizedBox(height: 4),
        const TitoSkeletonBox(height: 11, width: 56),
        const SizedBox(height: 5),
        const TitoSkeletonBox(height: 13, width: 64),
      ],
    );
    if (skin.isFlat) {
      return DecoratedBox(
        decoration: dexFlatSeparatedDecoration(context, radius: skin.radiusMd),
        child: Padding(padding: const EdgeInsets.all(6), child: body),
      );
    }
    return StickerCard.dense(padding: const EdgeInsets.all(6), child: body);
  }
}

class TitoDexGridSkeleton extends StatelessWidget {
  const TitoDexGridSkeleton({
    super.key,
    this.crossAxisCount = 2,
    this.itemCount = 6,
    this.childAspectRatio = 0.78,
  });

  final int crossAxisCount;
  final int itemCount;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        // Match the live dex grid so the swap doesn't shift layout.
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const TitoDexMiniCardSkeleton(),
    );
  }
}
