import 'package:flutter/material.dart';

import '../features/dex/dex_models.dart';
import '../l10n/app_zh.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'tito_progress_bar.dart';

/// Blocking progress dialog with cancel for long-running downloads.
Future<DexCacheProgress?> trackWhileDownloading({
  required BuildContext context,
  required Future<DexCacheProgress?> Function(
    void Function(DexCacheProgress progress) onProgress,
  )
  download,
  required VoidCallback onCancel,
  Future<void> Function(DexCacheProgress? progress)? onMinimize,
  String? title,
  bool showCancel = true,
}) async {
  DexCacheProgress? latest;
  var dialogOpen = true;
  var minimizing = false;

  if (!context.mounted) {
    return null;
  }

  final dialogFuture = showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) {
      return PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            void pushProgress(DexCacheProgress progress) {
              latest = progress;
              if (dialogOpen) {
                setDialogState(() {});
              }
            }

            _activeProgressDialog = pushProgress;
            final progressValue = dexProgressDisplayFraction(latest);
            final progressText = latest == null
                ? AppZh.companionLoading
                : AppZh.settingsDexOfflineProgress(
                    latest!.phase,
                    latest!.current,
                    latest!.total,
                  );

            return AlertDialog(
              title: Text(title ?? AppZh.progressDialogTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TitoProgressBar(value: progressValue, height: 10),
                  const SizedBox(height: 10),
                  Text(
                    '$progressText · ${(progressValue * 100).round()}%',
                    style: SecondaryTypography.onCard.small12.copyWith(
                      color: TitoColors.mutedInk,
                    ),
                  ),
                  if (latest?.label != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      latest!.label!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SecondaryTypography.onCard.small12.copyWith(
                        color: TitoColors.mutedInk,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (onMinimize != null)
                  TextButton(
                    onPressed: minimizing
                        ? null
                        : () async {
                            minimizing = true;
                            setDialogState(() {});
                            try {
                              await onMinimize(latest);
                              if (dialogContext.mounted && dialogOpen) {
                                dialogOpen = false;
                                _activeProgressDialog = null;
                                Navigator.pop(dialogContext);
                              }
                            } catch (_) {
                              minimizing = false;
                              if (dialogContext.mounted && dialogOpen) {
                                setDialogState(() {});
                              }
                            }
                          },
                    child: const Text(AppZh.settingsDexBackgroundDownload),
                  ),
                if (showCancel)
                  TextButton(
                    onPressed: () {
                      dialogOpen = false;
                      _activeProgressDialog = null;
                      onCancel();
                      Navigator.pop(dialogContext);
                    },
                    child: const Text(AppZh.cancel),
                  ),
              ],
            );
          },
        ),
      );
    },
  );

  DexCacheProgress? result;
  try {
    result = await download((progress) {
      latest = progress;
      _activeProgressDialog?.call(progress);
    });
  } finally {
    _activeProgressDialog = null;
    if (dialogOpen &&
        context.mounted &&
        Navigator.of(context, rootNavigator: true).canPop()) {
      dialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
    await dialogFuture;
  }

  return result ?? latest;
}

/// Continuous overall progress for both the CDN download and Offline APK seed.
/// Each multi-stage stream gets its own weights so a phase transition never
/// resets the visible percentage back to zero.
double dexProgressDisplayFraction(DexCacheProgress? progress) {
  if (progress == null) {
    return 0;
  }
  final phaseFraction = progress.fraction.clamp(0.0, 1.0);
  final value = switch (progress.phase) {
    'cdn_manifest' => 0.02 * phaseFraction,
    'cdn_download' => 0.02 + 0.68 * phaseFraction,
    'cdn_verify' => 0.70 + 0.08 * phaseFraction,
    'cdn_decompress' => 0.78 + 0.10 * phaseFraction,
    'cdn_extract' => 0.88 + 0.10 * phaseFraction,
    'cdn_index' => 0.98 + 0.01 * phaseFraction,
    'apk_seed_manifest' => 0.02 * phaseFraction,
    'apk_seed_read' => 0.02 + 0.08 * phaseFraction,
    'apk_seed_verify' => 0.10 + 0.10 * phaseFraction,
    'apk_seed_decompress' => 0.20 + 0.20 * phaseFraction,
    'apk_seed_extract' => 0.40 + 0.55 * phaseFraction,
    'apk_seed_index' => 0.95 + 0.04 * phaseFraction,
    'done' => 1.0,
    _ => phaseFraction,
  };
  return value.clamp(0.0, 1.0);
}

void Function(DexCacheProgress progress)? _activeProgressDialog;
