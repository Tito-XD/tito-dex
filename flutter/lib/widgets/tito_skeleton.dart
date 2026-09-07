import 'package:flutter/material.dart';

import '../theme/app_visual_style.dart';
import '../theme/tito_colors.dart';
import 'sticker_card.dart';

/// Placeholder block for loading layouts (detail header, cards, sprites…).
///
/// This is the single placeholder implementation: image slots, list rows and
/// section skeletons all draw this box so every theme shows the same idle
/// surface. Set [shimmer] while the real content is genuinely in flight — the
/// box then pulses gently instead of showing a spinner.
class TitoSkeletonBox extends StatelessWidget {
  const TitoSkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.radius = TitoRadii.sm,
    this.shimmer = false,
  });

  final double? height;
  final double? width;
  final double radius;

  /// Pulse the box while content loads. Off by default so static layouts
  /// (grid skeletons, detail headers) do not run a ticker per cell.
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final BoxBorder? border;
    if (appVisualStyle.usesFlatUi) {
      fill = Theme.of(context).colorScheme.surfaceContainerHighest;
      border = null;
    } else if (appVisualStyle.usesSolidPlastic) {
      fill = Colors.white.withValues(alpha: 0.35);
      border = Border.all(
        color: Colors.white.withValues(alpha: 0.78),
        width: TitoBorders.glass,
      );
    } else {
      fill = TitoColors.card.withValues(alpha: 0.45);
      border = Border.all(
        color: TitoColors.ink.withValues(alpha: 0.10),
        width: TitoBorders.element,
      );
    }
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
    );
    if (!shimmer) {
      return box;
    }
    return _SkeletonPulse(child: box);
  }
}

class _SkeletonPulse extends StatefulWidget {
  const _SkeletonPulse({required this.child});

  final Widget child;

  @override
  State<_SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<_SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final _opacity = Tween<double>(
    begin: 0.55,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}

class TitoDetailHeaderSkeleton extends StatelessWidget {
  const TitoDetailHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      variant: StickerVariant.deep,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: const Row(
        children: [
          Expanded(child: TitoSkeletonBox(height: 18, width: double.infinity)),
          SizedBox(width: 8),
          TitoSkeletonBox(height: 52, width: 52),
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
    // Mirrors PokemonMiniCard: flexible sprite slot, number, name, type row.
    return StickerCard(
      padding: const EdgeInsets.all(6),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Center(child: TitoSkeletonBox(height: 40, width: 40))),
          SizedBox(height: 4),
          TitoSkeletonBox(height: 9, width: 32),
          SizedBox(height: 4),
          TitoSkeletonBox(height: 11, width: 56),
          SizedBox(height: 5),
          TitoSkeletonBox(height: 13, width: 64),
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
