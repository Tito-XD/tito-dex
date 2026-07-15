import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
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
            TitoSkeletonBox(height: compact ? 72 : 96, width: double.infinity),
            const SizedBox(height: 10),
            const TitoSkeletonBox(height: 12, width: 180),
            SizedBox(height: compact ? 14 : 18),
          ],
          if (progress != null)
            TitoProgressBar(value: progress!.clamp(0.0, 1.0), height: 6)
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

/// Replaces [child] with loading content without an app-defined transition.
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
    return loading
        ? (loadingChild ?? TitoLoadingPanel(progress: progress))
        : child;
  }
}

/// Static bootstrap progress under the home trainer card.
class TitoBootstrapProgress extends StatelessWidget {
  const TitoBootstrapProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return const TitoProgressBar(
      value: 0.5,
      label: AppZh.bootstrapLoading,
      height: 6,
    );
  }
}
