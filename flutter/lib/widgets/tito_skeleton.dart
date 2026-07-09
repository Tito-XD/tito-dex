import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';
import 'sticker_card.dart';

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
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: TitoColors.card.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: TitoColors.ink.withValues(alpha: 0.12),
          width: 2,
        ),
      ),
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
          TitoSkeletonBox(
            height: 52,
            width: 52,
            radius: TitoRadii.sm,
          ),
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
    return StickerCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TitoSkeletonBox(
            height: 56,
            width: 56,
            radius: TitoRadii.sm,
          ),
          const SizedBox(height: 8),
          const TitoSkeletonBox(height: 10, width: 40),
          const SizedBox(height: 6),
          const TitoSkeletonBox(height: 12, width: 72),
          const Spacer(),
          const TitoSkeletonBox(height: 10, width: 48),
        ],
      ),
    );
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
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const TitoDexMiniCardSkeleton(),
    );
  }
}
