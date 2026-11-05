import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';

/// Asks the user to confirm an irreversible action (deleting downloads,
/// overwriting the journey) before it runs.
///
/// Resolves to `true` only when [confirmLabel] is pressed; cancel, a barrier
/// tap and system back all resolve to `false`. The cancel button takes initial
/// focus so a stray A press on a handheld D-pad backs out instead of
/// destroying data. With [destructive] the confirm button uses the theme's
/// error colours.
Future<bool> showTitoConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            key: const Key('tito-confirm-cancel'),
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppZh.cancel),
          ),
          FilledButton(
            key: const Key('tito-confirm-accept'),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
