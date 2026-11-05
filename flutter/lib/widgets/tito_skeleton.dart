import 'package:flutter/material.dart';

import '../theme/motion_preferences.dart';
import '../theme/tito_surface_tokens.dart';
import '../theme/tito_colors.dart';
import 'sticker_card.dart';
import 'tito_delayed_loading.dart';
import 'tito_pokeball_loading.dart';

/// Placeholder block for loading layouts (detail header, cards, sprites…).
///
/// This is the single placeholder implementation: image slots, list rows and
/// section skeletons all draw this box so every theme shows the same idle
/// surface. Set [shimmer] while the real content is genuinely in flight — a
/// light band then sweeps across the box. Layouts with many boxes wrap the
/// whole group in one [TitoShimmer] instead, so they share a single ticker.
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

  /// Sweep a highlight across this box while content loads.
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    final surface = TitoSurfaceTokens.of(
      context,
    ).surface(TitoSurfaceRole.party);
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: surface.fill,
        borderRadius: BorderRadius.circular(radius),
        border: surface.border,
      ),
    );
    return shimmer ? TitoShimmer(child: box) : box;
  }
}

/// Sweeps one diagonal light band across [child] every [period] while it is
/// on screen. Reduced motion, the App motion switch and hidden tabs keep the
/// placeholder static.
class TitoShimmer extends StatefulWidget {
  const TitoShimmer({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 1300),
  });

  final Widget child;
  final Duration period;

  @override
  State<TitoShimmer> createState() => _TitoShimmerState();
}

class _TitoShimmerState extends State<TitoShimmer>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  bool get _enabled =>
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled &&
      motionPreferences.listAnimationsEnabled;

  @override
  void initState() {
    super.initState();
    motionPreferences.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    if (_enabled) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating || _controller.value != 0) {
      _controller
        ..stop()
        ..value = 0;
      setState(() {});
    }
  }

  @override
  void dispose() {
    motionPreferences.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // The band travels from fully left of the box to fully right of it.
        final t = Curves.easeInOutSine.transform(_controller.value);
        final center = -1.0 + 3.0 * t;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            transform: const GradientRotation(0.26),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.42),
              Colors.white.withValues(alpha: 0),
            ],
            stops: [
              (center - 0.35).clamp(0.0, 1.0),
              center.clamp(0.0, 1.0),
              (center + 0.35).clamp(0.0, 1.0),
            ],
          ).createShader(bounds),
          child: child,
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
      child: const Row(
        children: [
          Expanded(
            child: TitoSkeletonBox(
              height: 18,
              width: double.infinity,
              shimmer: true,
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            height: 52,
            width: 52,
            child: Center(child: TitoPokeballLoading()),
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
      child: TitoShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TitoSkeletonBox(height: 14, width: 96),
            const SizedBox(height: 10),
            TitoSkeletonBox(height: height, width: double.infinity),
          ],
        ),
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
          Expanded(
            child: Center(child: TitoSkeletonBox(height: 40, width: 40)),
          ),
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
    this.showLoading = false,
  });

  final int crossAxisCount;
  final int itemCount;
  final double childAspectRatio;
  final bool showLoading;

  @override
  Widget build(BuildContext context) {
    // One shared sweep for the whole grid rather than a ticker per cell.
    final grid = TitoShimmer(
      child: GridView.builder(
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
      ),
    );
    if (!showLoading) return grid;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        grid,
        const Padding(
          padding: EdgeInsets.only(top: 32),
          child: TitoDelayedLoading(child: TitoPokeballLoading(onLight: true)),
        ),
      ],
    );
  }
}
