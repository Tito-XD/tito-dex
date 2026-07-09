import 'package:flutter/material.dart';

import '../features/launcher/emulator_launcher.dart';
import '../features/launcher/emulator_launcher_repository.dart';
import '../l10n/app_zh.dart';
import '../navigation/tito_page_transition.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'tito_skeleton.dart';

Future<EmulatorAppChoice?> showEmulatorPickerSheet(
  BuildContext context,
  EmulatorLauncher launcher,
) {
  if (!launcher.isLaunchSupported) {
    return showTitoModalBottomSheet<EmulatorAppChoice>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          AppZh.continueSheetDesktopHint,
          style: context.tito.cardBody,
        ),
      ),
    );
  }

  return showTitoModalBottomSheet<EmulatorAppChoice>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _EmulatorPickerSheet(launcher: launcher),
  );
}

class _EmulatorPickerSheet extends StatefulWidget {
  const _EmulatorPickerSheet({required this.launcher});

  final EmulatorLauncher launcher;

  @override
  State<_EmulatorPickerSheet> createState() => _EmulatorPickerSheetState();
}

class _EmulatorPickerSheetState extends State<_EmulatorPickerSheet>
    with WidgetsBindingObserver {
  late Future<List<EmulatorAppChoice>> _appsFuture;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reload();
    }
  }

  void _reload() {
    setState(() {
      _error = null;
      _appsFuture = widget.launcher.listCandidateApps().catchError((error) {
        _error = error;
        return <EmulatorAppChoice>[];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FutureBuilder<List<EmulatorAppChoice>>(
          future: _appsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.25,
                child: const Center(
                  child: TitoSkeletonBox(height: 14, width: 160),
                ),
              );
            }

            if (_error != null) {
              return _EmulatorPickerMessage(
                message: AppZh.continueSheetEmulatorLoadFailed,
                onRetry: _reload,
              );
            }

            final apps = snapshot.data ?? const [];
            if (apps.isEmpty) {
              return _EmulatorPickerMessage(
                message: AppZh.continueSheetNoEmulators,
                onRetry: _reload,
              );
            }

            return _EmulatorPickerList(apps: apps);
          },
        ),
      ),
    );
  }
}

class _EmulatorPickerMessage extends StatelessWidget {
  const _EmulatorPickerMessage({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: context.tito.cardBody),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onRetry,
          child: const Text(AppZh.dexRetry),
        ),
      ],
    );
  }
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
