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
  ) download,
  required VoidCallback onCancel,
  String? title,
}) async {
  DexCacheProgress? latest;
  var dialogOpen = true;

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

            return AlertDialog(
              title: Text(title ?? AppZh.progressDialogTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TitoProgressBar(
                    value: (latest?.fraction ?? 0).clamp(0.0, 1.0),
                    height: 10,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    latest == null
                        ? AppZh.companionLoading
                        : AppZh.settingsDexOfflineProgress(
                            latest!.phase,
                            latest!.current,
                            latest!.total,
                          ),
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
                TextButton(
                  onPressed: () {
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
    dialogOpen = false;
    _activeProgressDialog = null;
    if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await dialogFuture;
  }

  return result ?? latest;
}

void Function(DexCacheProgress progress)? _activeProgressDialog;
