import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_zh.dart';

const _offlinePromptKey = 'titodex_offline_prompt_shown';

/// First-run dialog suggesting the user download the CDN offline bundle.
Future<void> showOfflineDataPrompt(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_offlinePromptKey) == true) {
    return;
  }

  if (!context.mounted) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(AppZh.offlinePromptTitle),
      content: Text(AppZh.offlinePromptBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(AppZh.offlinePromptLater),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            context.push('/settings');
          },
          child: Text(AppZh.offlinePromptGoSettings),
        ),
      ],
    ),
  );

  await prefs.setBool(_offlinePromptKey, true);
}

/// Dialog shown when a newer bundle or l10n slice is available on the CDN.
Future<void> showUpdateAvailableDialog(BuildContext context) async {
  if (!context.mounted) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(AppZh.updateAvailableTitle),
      content: Text(AppZh.updateAvailableBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(AppZh.updateAvailableLater),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            context.push('/settings');
          },
          child: Text(AppZh.updateAvailableGoSettings),
        ),
      ],
    ),
  );
}

/// Test-only reset for SharedPreferences prompt flag.
Future<void> resetOfflinePromptForTest() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_offlinePromptKey);
}
