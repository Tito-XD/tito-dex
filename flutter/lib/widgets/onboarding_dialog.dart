import 'package:flutter/material.dart';

import '../features/app_shortcuts/app_shortcuts.dart';
import '../features/onboarding/onboarding_preferences.dart';
import '../features/trainer/trainer_avatar_service.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import 'trainer_card.dart';

Future<bool> showTrainerOnboarding(
  BuildContext context, {
  required CurrentJourney journey,
  required Future<void> Function(CurrentJourney) onSave,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OnboardingDialog(journey: journey, onSave: onSave),
    ) ??
    false;

class OnboardingDialog extends StatefulWidget {
  const OnboardingDialog({
    super.key,
    required this.journey,
    required this.onSave,
    this.pickAvatar,
    this.preferences,
  });
  final CurrentJourney journey;
  final Future<void> Function(CurrentJourney) onSave;
  final Future<String?> Function()? pickAvatar;
  final OnboardingPreferences? preferences;
  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  late final name = TextEditingController(
    text: widget.journey.trainerNameCustomized
        ? widget.journey.trainerName
        : '',
  );
  late CurrentJourney journey = widget.journey;
  final scroll = ScrollController();
  final shortcuts = AppShortcutsPlatform();
  int step = 0;
  bool busy = false;
  bool pin = false;
  bool pinSupported = false;
  String? error;

  @override
  void initState() {
    super.initState();
    shortcuts.trainerShortcutSupported().then((value) {
      if (mounted) setState(() => pinSupported = value);
    });
  }

  Future<void> _avatar() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final path =
          await (widget.pickAvatar ?? TrainerAvatarService.pickAndCropSquare)();
      if (path != null && mounted) {
        setState(
          () => journey = journey.copyWith(
            trainerAvatarPath: path,
            trainerAvatarCustomized: true,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => error = AppZh.snackAvatarFailed);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  CurrentJourney _profile() {
    final trimmed = name.text.trim();
    return trimmed.isEmpty
        ? journey
        : journey.copyWith(trainerName: trimmed, trainerNameCustomized: true);
  }

  Future<void> _finish({bool openData = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final profile = _profile();
      await widget.onSave(profile);
      await (widget.preferences ?? OnboardingPreferences()).complete();
      if (!mounted) return;
      if (pin) {
        final result = await shortcuts.pinTrainerShortcut(profile.trainerName);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(switch (result) {
              'requested' => AppZh.trainerShortcutRequested,
              'updated' => AppZh.trainerShortcutUpdated,
              _ => AppZh.trainerShortcutUnsupported,
            }),
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(openData);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = AppZh.onboardingSaveFailed;
        });
      }
    }
  }

  void _setStep(int next) {
    FocusScope.of(context).unfocus();
    setState(() {
      step = next;
      error = null;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  @override
  void dispose() {
    name.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      AppZh.onboardingProfileTitle,
      AppZh.onboardingFeaturesTitle,
      AppZh.onboardingReadyTitle,
    ];
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.catching_pokemon_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'TitoDex · ${step + 1}/3',
                        style: SecondaryTypography.onCard.h15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    controller: scroll,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          titles[step],
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        if (step == 0) ...[
                          Text(AppZh.onboardingProfileHint),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              TrainerAvatar(journey: _profile(), size: 64),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: busy ? null : _avatar,
                                  icon: const Icon(Icons.photo_outlined),
                                  label: Text(AppZh.settingsChangeAvatar),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            key: const Key('onboarding-name'),
                            controller: name,
                            enabled: !busy,
                            maxLength: 20,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: AppZh.settingsDisplayName,
                              hintText: AppZh.settingsDisplayNameHint,
                              helperText: AppZh.onboardingNameHint,
                              helperMaxLines: 3,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                        if (step == 1) ...[
                          _feature(
                            Icons.explore_outlined,
                            AppZh.navJourney,
                            AppZh.onboardingJourney,
                          ),
                          _feature(
                            Icons.groups_outlined,
                            AppZh.navTeam,
                            AppZh.onboardingTeam,
                          ),
                          _feature(
                            Icons.catching_pokemon_outlined,
                            AppZh.navDex,
                            AppZh.onboardingDex,
                          ),
                          _feature(
                            Icons.search_rounded,
                            AppZh.navSearch,
                            AppZh.onboardingSearch,
                          ),
                          _feature(
                            Icons.auto_awesome_outlined,
                            AppZh.onboardingAskTitle,
                            AppZh.onboardingAsk,
                          ),
                        ],
                        if (step == 2) ...[
                          Text(AppZh.onboardingDataHint),
                          const SizedBox(height: 12),
                          Text(AppZh.onboardingSettingsHint),
                          if (pinSupported) ...[
                            const SizedBox(height: 12),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: pin,
                              onChanged: busy
                                  ? null
                                  : (value) =>
                                        setState(() => pin = value ?? false),
                              title: Text(
                                '${AppZh.trainerShortcutCreate} · ${AppZh.displayTitleForTrainer(_profile().trainerName)}',
                              ),
                              subtitle: Text(AppZh.trainerShortcutHint),
                            ),
                          ],
                        ],
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (step == 0)
                      TextButton(
                        onPressed: busy ? null : _finish,
                        child: Text(AppZh.onboardingLater),
                      )
                    else
                      TextButton(
                        onPressed: busy ? null : () => _setStep(step - 1),
                        child: Text(AppZh.onboardingBack),
                      ),
                    if (step == 2)
                      OutlinedButton(
                        onPressed: busy ? null : () => _finish(openData: true),
                        child: Text(AppZh.onboardingData),
                      ),
                    FilledButton(
                      key: const Key('onboarding-next'),
                      onPressed: busy
                          ? null
                          : step == 2
                          ? _finish
                          : () => _setStep(step + 1),
                      child: Text(
                        step == 2
                            ? AppZh.onboardingStart
                            : AppZh.onboardingNext,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _feature(IconData icon, String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SecondaryTypography.onCard.h15),
              const SizedBox(height: 4),
              Text(body),
            ],
          ),
        ),
      ],
    ),
  );
}
