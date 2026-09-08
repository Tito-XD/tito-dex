import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../theme/app_visual_style.dart';
import '../theme/tito_typography.dart';
import 'tito_pokeball_loading.dart';
import 'sticker_card.dart';
import 'tito_progress_bar.dart';
import 'tito_skeleton.dart';
import 'tito_delayed_loading.dart';

/// In-card loading panel — delayed pale ball or immediate measured progress.
///
/// Prefer this over a bare [CircularProgressIndicator] so pages do not look
/// frozen while async work runs.
class TitoLoadingPanel extends StatelessWidget {
  const TitoLoadingPanel({
    super.key,
    this.message,
    this.progress,
    this.compact = false,
    this.showSkeleton = false,
    this.onLightSurface = true,
  });

  final String? message;
  final double? progress;
  final bool compact;
  final bool showSkeleton;

  /// Outline the pale Poké Ball. Defaults to `true` because the panel always
  /// sits on its own cream [StickerCard]; pass `false` only when the card
  /// variant is deep / type-tinted. Flat UI always keeps the faint outline.
  final bool onLightSurface;

  @override
  Widget build(BuildContext context) {
    final outlinedBall = onLightSurface || appVisualStyle.usesFlatUi;
    final panel = StickerCard(
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
            Center(child: TitoPokeballLoading(onLight: outlinedBall)),
        ],
      ),
    );
    // Determinate downloads report progress immediately. Short local reads
    // keep a quiet slot and do not construct a spinner until actually needed.
    return progress != null
        ? panel
        : TitoDelayedLoading(
            placeholder: const SizedBox(height: 64),
            child: panel,
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
    return TitoProgressBar(
      value: 0.5,
      label: AppZh.bootstrapLoading,
      height: 6,
    );
  }
}
