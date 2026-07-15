import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../navigation/tito_page_transition.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'sticker_card.dart';
import 'tito_progress_bar.dart';
import 'tito_skeleton.dart';

/// In-card loading panel — skeleton hints + spinner or progress bar.
///
/// Prefer this over a bare [CircularProgressIndicator] so pages do not look
/// frozen while async work runs.
class TitoLoadingPanel extends StatelessWidget {
  const TitoLoadingPanel({
    super.key,
    this.message,
    this.progress,
    this.compact = false,
    this.showSkeleton = true,
  });

  final String? message;
  final double? progress;
  final bool compact;
  final bool showSkeleton;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null) ...[
            Text(
              message!,
              style: context.tito.cardBodyStrong.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: compact ? 10 : 14),
          ],
          if (showSkeleton) ...[
            const TitoSkeletonBox(height: 14, width: 120),
            const SizedBox(height: 10),
            TitoSkeletonBox(
              height: compact ? 72 : 96,
              width: double.infinity,
            ),
            const SizedBox(height: 10),
            const TitoSkeletonBox(height: 12, width: 180),
            SizedBox(height: compact ? 14 : 18),
          ],
          if (progress != null)
            TitoProgressBar(
              value: progress!.clamp(0.0, 1.0),
              height: 6,
            )
          else
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: TitoColors.deepBlue,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dims [child] and shows a slim top progress bar while [loading].
class TitoLoadingScope extends StatelessWidget {
  const TitoLoadingScope({
    super.key,
    required this.loading,
    required this.child,
    this.progress,
    this.loadingChild,
  });

  final bool loading;
  final Widget child;
  final double? progress;
  final Widget? loadingChild;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: TitoMotion.tabFadeDuration,
      switchInCurve: TitoMotion.standardCurve,
      switchOutCurve: TitoMotion.standardCurve,
      child: loading
          ? (loadingChild ??
              KeyedSubtree(
                key: const ValueKey('loading'),
                child: TitoLoadingPanel(progress: progress),
              ))
          : KeyedSubtree(
              key: const ValueKey('content'),
              child: child,
            ),
    );
  }
}

/// Indeterminate bootstrap progress under the home trainer card.
class TitoBootstrapProgress extends StatefulWidget {
  const TitoBootstrapProgress({super.key});

  @override
  State<TitoBootstrapProgress> createState() => _TitoBootstrapProgressState();
}

class _TitoBootstrapProgressState extends State<TitoBootstrapProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return TitoProgressBar(
          value: 0.35 + _pulse.value * 0.45,
          label: AppZh.bootstrapLoading,
          height: 6,
        );
      },
    );
  }
}
