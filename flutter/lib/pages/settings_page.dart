import 'package:flutter/material.dart';

import '../features/save/save_types.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/tito_colors.dart';
import '../widgets/sticker_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.journey,
    required this.saveConfig,
    required this.onImportFixture,
    required this.onResetMock,
    required this.onSaveJourney,
    required this.onPickSaveDirectory,
    required this.onClearSaveDirectory,
    required this.onToggleAutoLoad,
    required this.onSyncNow,
  });

  final CurrentJourney journey;
  final SaveDirectoryConfig saveConfig;
  final VoidCallback onImportFixture;
  final VoidCallback onResetMock;
  final ValueChanged<CurrentJourney> onSaveJourney;
  final VoidCallback onPickSaveDirectory;
  final VoidCallback onClearSaveDirectory;
  final ValueChanged<bool> onToggleAutoLoad;
  final VoidCallback onSyncNow;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _trainerController;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _trainerController = TextEditingController(text: widget.journey.trainerName);
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.journey.trainerName != widget.journey.trainerName &&
        !_dirty) {
      _trainerController.text = widget.journey.trainerName;
    }
  }

  @override
  void dispose() {
    _trainerController.dispose();
    super.dispose();
  }

  void _saveTrainerName() {
    final trimmed = _trainerController.text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final customized = trimmed != (widget.journey.saveTrainerName ?? trimmed);
    widget.onSaveJourney(
      widget.journey.copyWith(
        trainerName: trimmed,
        trainerNameCustomized: customized,
      ),
    );
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppZh.snackTrainerSaved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saveName = widget.journey.saveTrainerName;
    final config = widget.saveConfig;
    final directoryPath = config.directoryPath;
    final lastSynced = config.lastLoadedFileName;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppZh.settingsTrainerProfile,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _trainerController,
                decoration: InputDecoration(
                  labelText: AppZh.settingsDisplayName,
                  hintText: AppZh.settingsDisplayNameHint,
                  helperText: saveName != null &&
                          saveName != _trainerController.text
                      ? AppZh.settingsSaveDecodeHint(saveName)
                      : AppZh.settingsSaveTrainerHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _dirty ? _saveTrainerName : null,
                style: FilledButton.styleFrom(
                  backgroundColor: TitoColors.coral,
                  foregroundColor: TitoColors.ink,
                ),
                child: const Text(AppZh.settingsSaveTrainerName),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StickerCard(
          variant: StickerVariant.cream,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppZh.settingsSaveDirectory,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppZh.settingsSaveDirectoryHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                directoryPath ?? AppZh.settingsSaveDirectoryUnset,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: directoryPath == null
                      ? Theme.of(context).colorScheme.outline
                      : TitoColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: widget.onPickSaveDirectory,
                style: FilledButton.styleFrom(
                  backgroundColor: TitoColors.deepBlue,
                  foregroundColor: TitoColors.card,
                ),
                child: const Text(AppZh.settingsPickSaveDirectory),
              ),
              if (directoryPath != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: widget.onClearSaveDirectory,
                  child: const Text(AppZh.settingsClearSaveDirectory),
                ),
              ],
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(AppZh.settingsAutoLoadOnStartup),
                value: config.autoLoadOnStartup,
                onChanged: widget.onToggleAutoLoad,
              ),
              Text(
                lastSynced != null
                    ? AppZh.settingsLastSynced(lastSynced)
                    : AppZh.settingsLastSyncedNone,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed:
                    directoryPath != null ? widget.onSyncNow : null,
                child: const Text(AppZh.settingsSyncNow),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StickerCard(
          child: Column(
            children: [
              _Row(
                label: AppZh.settingsCurrentGame,
                value: localizeGame(widget.journey.game),
              ),
              _Row(
                label: AppZh.settingsLocation,
                value: localizeLocation(widget.journey.location),
              ),
              _Row(
                label: AppZh.settingsPlayTime,
                value: widget.journey.playTime,
              ),
              _Row(
                label: AppZh.settingsBadges,
                value: '${widget.journey.badges}/${widget.journey.maxBadges}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StickerCard(
          variant: StickerVariant.sky,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppZh.settingsJourneyData,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: widget.onImportFixture,
                style: FilledButton.styleFrom(
                  backgroundColor: TitoColors.deepBlue,
                  foregroundColor: TitoColors.card,
                ),
                child: const Text(AppZh.settingsImportSave),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: widget.onResetMock,
                child: const Text(AppZh.settingsResetMock),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: StickerCard(
        child: Text(
          AppZh.placeholderScreen(title),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}
