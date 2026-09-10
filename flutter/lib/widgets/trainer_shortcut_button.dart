import 'package:flutter/material.dart';
import '../features/app_shortcuts/app_shortcuts.dart';
import '../l10n/app_zh.dart';

class TrainerShortcutButton extends StatefulWidget {
  const TrainerShortcutButton({super.key, required this.trainerName});
  final String trainerName;
  @override
  State<TrainerShortcutButton> createState() => _TrainerShortcutButtonState();
}

class _TrainerShortcutButtonState extends State<TrainerShortcutButton> {
  final platform = AppShortcutsPlatform();
  late final supported = platform.trainerShortcutSupported();
  bool busy = false;
  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: supported,
    builder: (context, snapshot) => snapshot.data != true
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppZh.trainerShortcutHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          final result = await platform.pinTrainerShortcut(
                            widget.trainerName,
                          );
                          if (!context.mounted) return;
                          setState(() => busy = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(switch (result) {
                                'requested' => AppZh.trainerShortcutRequested,
                                'updated' => AppZh.trainerShortcutUpdated,
                                _ => AppZh.trainerShortcutUnsupported,
                              }),
                            ),
                          );
                        },
                  icon: const Icon(Icons.add_to_home_screen_rounded),
                  label: Text(
                    '${AppZh.trainerShortcutCreate} · ${AppZh.displayTitleForTrainer(widget.trainerName)}',
                  ),
                ),
              ],
            ),
          ),
  );
}
