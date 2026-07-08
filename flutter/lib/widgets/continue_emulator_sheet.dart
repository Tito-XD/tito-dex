import 'package:flutter/material.dart';

import '../features/launcher/emulator_launcher.dart';
import '../features/launcher/emulator_launcher_repository.dart';
import '../l10n/app_zh.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';

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
        child: Text(
          AppZh.continueSheetDesktopHint,
          style: context.tito.cardBody,
        ),
      ),
    );
    return null;
  }

  final appsFuture = launcher.listCandidateApps();

  return showModalBottomSheet<EmulatorAppChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FutureBuilder<List<EmulatorAppChoice>>(
            future: appsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.25,
                  child: const Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Text(
                  AppZh.continueSheetEmulatorLoadFailed,
                  style: context.tito.cardBody,
                );
              }

              final apps = snapshot.data ?? const [];
              if (apps.isEmpty) {
                return Text(
                  AppZh.continueSheetNoEmulators,
                  style: context.tito.cardBody,
                );
              }

              return _EmulatorPickerList(apps: apps);
            },
          ),
        ),
      );
    },
  );
}

class _EmulatorPickerList extends StatelessWidget {
  const _EmulatorPickerList({required this.apps});

  final List<EmulatorAppChoice> apps;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.55;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppZh.continueSheetPickEmulator,
          style: context.tito.cardTitle,
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
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
                            style: context.tito.cardBodyEmphasis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            app.packageName,
                            style: context.tito.caption,
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
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
    );
  }
}
