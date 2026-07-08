import 'package:flutter/material.dart';

import '../features/launcher/emulator_launcher.dart';
import '../features/launcher/emulator_launcher_repository.dart';
import '../l10n/app_zh.dart';
import '../theme/tito_colors.dart';

Future<EmulatorAppChoice?> showEmulatorPickerSheet(
  BuildContext context,
  EmulatorLauncher launcher,
) async {
  if (!launcher.isLaunchSupported) {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(AppZh.continueSheetDesktopHint),
      ),
    );
    return null;
  }

  final apps = await launcher.listCandidateApps();
  if (!context.mounted) {
    return null;
  }

  if (apps.isEmpty) {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(AppZh.continueSheetNoEmulators),
      ),
    );
    return null;
  }

  return showModalBottomSheet<EmulatorAppChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppZh.continueSheetPickEmulator,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: apps.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    return Material(
                      color: TitoColors.card,
                      borderRadius: BorderRadius.circular(TitoRadii.md),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(TitoRadii.md),
                        onTap: () => Navigator.pop(context, app),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  app.appName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                app.packageName,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: TitoColors.mutedInk),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
