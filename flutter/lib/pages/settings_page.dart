import 'package:flutter/material.dart';

import '../features/launcher/emulator_launcher_repository.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_offline_service.dart';
import '../features/dex/dex_repository.dart';
import '../features/dex/dex_scope.dart';
import '../features/game/game_edition.dart';
import '../features/game/game_edition_controller.dart';
import '../features/dex/dex_settings_repository.dart';
import '../features/dex/dex_sprite_codec.dart';
import '../features/save/save_types.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_font_scale.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';
import '../widgets/tito_progress_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.journey,
    required this.saveConfig,
    required this.emulatorChoice,
    required this.onImportFixture,
    required this.onResetMock,
    required this.onSaveJourney,
    required this.onPickSaveDirectory,
    required this.onClearSaveDirectory,
    required this.onToggleAutoLoad,
    required this.onSyncNow,
    required this.onExportJourney,
    required this.onImportJourney,
    required this.onPickEmulator,
    required this.onClearEmulator,
  });

  final CurrentJourney journey;
  final SaveDirectoryConfig saveConfig;
  final EmulatorAppChoice? emulatorChoice;
  final VoidCallback onImportFixture;
  final VoidCallback onResetMock;
  final ValueChanged<CurrentJourney> onSaveJourney;
  final VoidCallback onPickSaveDirectory;
  final VoidCallback onClearSaveDirectory;
  final ValueChanged<bool> onToggleAutoLoad;
  final VoidCallback onSyncNow;
  final VoidCallback onExportJourney;
  final VoidCallback onImportJourney;
  final VoidCallback onPickEmulator;
  final VoidCallback onClearEmulator;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _trainerController;
  late final TextEditingController _locationController;
  late final TextEditingController _playTimeController;
  late final TextEditingController _badgesController;
  late final TextEditingController _reminderController;
  bool _trainerDirty = false;
  bool _journeyDirty = false;
  DexCacheStatus? _dexCacheStatus;
  bool _dexDownloading = false;
  // v0.4.0 B2: Settings dropdown mirrors global GameEdition (23 items).
  GameEdition _globalEdition = GameEdition.hgss;

  @override
  void initState() {
    super.initState();
    _trainerController = TextEditingController(
      text: widget.journey.trainerName,
    );
    _locationController = TextEditingController(text: widget.journey.location);
    _playTimeController = TextEditingController(text: widget.journey.playTime);
    _badgesController = TextEditingController(
      text: widget.journey.badges.toString(),
    );
    _reminderController = TextEditingController(
      text: widget.journey.nextReminder ?? '',
    );
    _refreshDexCacheStatus();
    _loadDexSettings();
  }

  Future<void> _loadDexSettings() async {
    final edition = await dexSettingsRepository.loadGlobalEdition();
    if (!mounted) {
      return;
    }
    setState(() => _globalEdition = edition);
  }

  /// v0.4.0: Persist global edition + legacy DexGameVersion for CDN move keys.
  Future<void> _setGlobalEdition(GameEdition? edition) async {
    if (edition == null) {
      return;
    }
    await gameEditionController.setEdition(edition);
    final dexVersion = edition.toDexGameVersion();
    if (dexVersion != null) {
      await dexSettingsRepository.saveDefaultGameVersion(dexVersion);
    }
    if (!mounted) {
      return;
    }
    setState(() => _globalEdition = edition);
  }

  Future<void> _refreshDexCacheStatus() async {
    final status = await dexOfflineService.getStatus();
    if (!mounted) {
      return;
    }
    setState(() => _dexCacheStatus = status);
  }

  Future<void> _downloadDexCdnBundle() async {
    if (_dexDownloading) {
      return;
    }
    setState(() => _dexDownloading = true);

    try {
      DexCacheProgress? lastProgress;
      await for (final progress in dexOfflineService.downloadFromCdnBundle()) {
        lastProgress = progress;
        if (!mounted) {
          return;
        }
        setState(() {
          _dexCacheStatus = DexCacheStatus(
            manifest:
                _dexCacheStatus?.manifest ??
                const DexCacheManifest(
                  version: DexCacheManifest.currentVersion,
                  complete: false,
                  preferOffline: true,
                ),
            sizeBytes: _dexCacheStatus?.sizeBytes ?? 0,
            isDownloading: progress.phase != 'done',
            progress: progress,
          );
        });
      }
      dexRepository.clearMemoryCache();
      await _refreshDexCacheStatus();
      if (!mounted) {
        return;
      }
      if (lastProgress?.phase == 'done') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppZh.snackDexCdnDone)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppZh.snackDexCdnFailed)),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppZh.snackDexCdnFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _dexDownloading = false);
      }
    }
  }

  Future<void> _downloadDexOffline() async {
    if (_dexDownloading) {
      return;
    }
    setState(() => _dexDownloading = true);

    try {
      DexCacheProgress? lastProgress;
      await for (final progress in dexOfflineService.downloadAll()) {
        lastProgress = progress;
        if (!mounted) {
          return;
        }
        setState(() {
          _dexCacheStatus = DexCacheStatus(
            manifest:
                _dexCacheStatus?.manifest ??
                const DexCacheManifest(
                  version: DexCacheManifest.currentVersion,
                  complete: false,
                  preferOffline: true,
                ),
            sizeBytes: _dexCacheStatus?.sizeBytes ?? 0,
            isDownloading:
                progress.phase != 'done' && progress.phase != 'partial',
            progress: progress,
          );
        });
      }
      dexRepository.clearMemoryCache();
      await _refreshDexCacheStatus();
      if (!mounted) {
        return;
      }
      final cachedCount = _dexCacheStatus?.manifest.pokemonCount ?? 0;
      if (lastProgress?.phase == 'done') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppZh.snackDexOfflineDone)),
        );
      } else if (lastProgress?.phase == 'partial' && cachedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppZh.snackDexOfflinePartial(cachedCount))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppZh.snackDexOfflineFailed)),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppZh.snackDexOfflineFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _dexDownloading = false);
      }
    }
  }

  Future<void> _clearDexOffline() async {
    await dexOfflineService.clearAll();
    dexRepository.clearMemoryCache();
    await _refreshDexCacheStatus();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppZh.snackDexOfflineCleared)));
  }

  Future<void> _setDexPreferOffline(bool enabled) async {
    await dexOfflineService.setPreferOffline(enabled);
    await _refreshDexCacheStatus();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.journey.trainerName != widget.journey.trainerName &&
        !_trainerDirty) {
      _trainerController.text = widget.journey.trainerName;
    }
    if (oldWidget.journey != widget.journey && !_journeyDirty) {
      _locationController.text = widget.journey.location;
      _playTimeController.text = widget.journey.playTime;
      _badgesController.text = widget.journey.badges.toString();
      _reminderController.text = widget.journey.nextReminder ?? '';
    }
  }

  @override
  void dispose() {
    _trainerController.dispose();
    _locationController.dispose();
    _playTimeController.dispose();
    _badgesController.dispose();
    _reminderController.dispose();
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
    setState(() => _trainerDirty = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppZh.snackTrainerSaved)));
  }

  void _saveJourneyEdits() {
    final badges = int.tryParse(_badgesController.text.trim());
    if (badges == null || badges < 0) {
      return;
    }

    widget.onSaveJourney(
      widget.journey.copyWith(
        location: _locationController.text.trim(),
        playTime: _playTimeController.text.trim(),
        badges: badges,
        nextReminder: _reminderController.text.trim().isEmpty
            ? null
            : _reminderController.text.trim(),
      ),
    );
    setState(() => _journeyDirty = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppZh.snackJourneySaved)));
  }

  @override
  Widget build(BuildContext context) {
    final saveName = widget.journey.saveTrainerName;
    final config = widget.saveConfig;
    final directoryPath = config.directoryPath;
    final lastSynced = config.lastLoadedFileName;
    final emulator = widget.emulatorChoice;
    final dexCache = _dexCacheStatus;
    final dexManifest = dexCache?.manifest;
    final dexProgress = dexCache?.progress;

    return TitoFontScale(
      multiplier: 1.0,
      child: SecondaryPageScaffold(
        title: AppZh.navSettings,
        subtitle: localizeGame(widget.journey.game),
        children: [
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppZh.settingsGroupTrainer, style: SecondaryTypography.onCard.h15),
              const SizedBox(height: 12),
              TextField(
                controller: _trainerController,
                spellCheckConfiguration:
                    const SpellCheckConfiguration.disabled(),
                decoration: InputDecoration(
                  labelText: AppZh.settingsDisplayName,
                  hintText: AppZh.settingsDisplayNameHint,
                  helperText:
                      saveName != null && saveName != _trainerController.text
                      ? AppZh.settingsSaveDecodeHint(saveName)
                      : AppZh.settingsSaveTrainerHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _trainerDirty = true),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _trainerDirty ? _saveTrainerName : null,
                style: FilledButton.styleFrom(
                  backgroundColor: TitoColors.coral,
                  foregroundColor: TitoColors.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(TitoRadii.md),
                    side: const BorderSide(color: TitoColors.ink, width: 3),
                  ),
                ),
                child: const Text(AppZh.settingsSaveTrainerName),
              ),
              const SizedBox(height: 16),
              Text(
                AppZh.settingsEditJourney,
                style: SecondaryTypography.onCard.h15,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _locationController,
                spellCheckConfiguration:
                    const SpellCheckConfiguration.disabled(),
                decoration: const InputDecoration(
                  labelText: AppZh.settingsLocation,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _journeyDirty = true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _playTimeController,
                spellCheckConfiguration:
                    const SpellCheckConfiguration.disabled(),
                decoration: const InputDecoration(
                  labelText: AppZh.settingsPlayTime,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _journeyDirty = true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _badgesController,
                keyboardType: TextInputType.number,
                spellCheckConfiguration:
                    const SpellCheckConfiguration.disabled(),
                decoration: const InputDecoration(
                  labelText: AppZh.settingsBadges,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _journeyDirty = true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reminderController,
                spellCheckConfiguration:
                    const SpellCheckConfiguration.disabled(),
                decoration: const InputDecoration(
                  labelText: AppZh.settingsNextReminder,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _journeyDirty = true),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _journeyDirty ? _saveJourneyEdits : null,
                style: FilledButton.styleFrom(
                  backgroundColor: TitoColors.deepBlue,
                  foregroundColor: TitoColors.card,
                ),
                child: const Text(AppZh.settingsSaveJourneyEdits),
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
              Text(AppZh.settingsGroupSaveSync, style: SecondaryTypography.onCard.h15),
              const SizedBox(height: 8),
              Text(
                AppZh.settingsSaveDirectoryHint,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                directoryPath ?? AppZh.settingsSaveDirectoryUnset,
                style: SecondaryTypography.onCard.body14.copyWith(
                  color: directoryPath == null
                      ? TitoColors.mutedInk
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
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppZh.settingsAutoLoadOnStartup,
                      style: SecondaryTypography.onCard.body14,
                    ),
                  ),
                  Switch(
                    value: config.autoLoadOnStartup,
                    onChanged: widget.onToggleAutoLoad,
                  ),
                ],
              ),
              Text(
                lastSynced != null
                    ? AppZh.settingsLastSynced(lastSynced)
                    : AppZh.settingsLastSyncedNone,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: directoryPath != null ? widget.onSyncNow : null,
                child: const Text(AppZh.settingsSyncNow),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StickerCard(
          variant: StickerVariant.mint,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppZh.settingsDexOffline, style: SecondaryTypography.onCard.h15),
              const SizedBox(height: 8),
              Text(
                AppZh.settingsDexOfflineHint,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                dexManifest != null && dexManifest.complete
                    ? AppZh.settingsDexOfflineReady(
                        dexManifest.pokemonCount,
                        dexManifest.moveCount,
                        formatCacheSize(dexCache?.sizeBytes ?? 0),
                        dexManifest.downloadedAt?.split('T').first ?? '',
                      )
                    : dexManifest != null && dexManifest.pokemonCount > 0
                    ? AppZh.settingsDexOfflinePartial(dexManifest.pokemonCount)
                    : AppZh.settingsDexOfflineUnset,
                style: SecondaryTypography.onCard.body14.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_dexDownloading && dexProgress != null) ...[
                const SizedBox(height: 12),
                TitoProgressBar(value: dexProgress.fraction, height: 10),
                const SizedBox(height: 6),
                Text(
                  AppZh.settingsDexOfflineProgress(
                    dexProgress.phase,
                    dexProgress.current,
                    dexProgress.total,
                  ),
                  style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
                ),
                if (dexProgress.label != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    dexProgress.label!,
                    style: SecondaryTypography.onCard.small12.copyWith(
                      color: TitoColors.mutedInk,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              Text(
                AppZh.settingsDexDefaultGameVersion,
                style: SecondaryTypography.onCard.body14.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppZh.settingsDexDefaultGameVersionHint,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
              const SizedBox(height: 8),
              // v0.4.0 B2: 23-game global edition selector (single source of truth).
              DropdownButtonFormField<GameEdition>(
                value: _globalEdition,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final edition in GameEdition.values)
                    DropdownMenuItem(
                      value: edition,
                      child: Text(edition.labelZh),
                    ),
                ],
                onChanged: _dexDownloading ? null : _setGlobalEdition,
              ),
              const SizedBox(height: 12),
              Text(
                AppZh.settingsDexCdnDownloadHint,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _dexDownloading ? null : _downloadDexCdnBundle,
                style: FilledButton.styleFrom(
                  backgroundColor: TitoColors.coral,
                  foregroundColor: TitoColors.ink,
                ),
                child: const Text(AppZh.settingsDexCdnDownload),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _dexDownloading ? null : _downloadDexOffline,
                child: Text(
                  dexManifest != null &&
                          dexManifest.pokemonCount > 0 &&
                          !dexManifest.complete
                      ? AppZh.settingsDexOfflineResume
                      : AppZh.settingsDexOfflineDownloadPokeApi,
                ),
              ),
              if (dexManifest != null && dexManifest.pokemonCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppZh.settingsDexOfflinePrefer,
                        style: SecondaryTypography.onCard.body14,
                      ),
                    ),
                    Switch(
                      value: dexManifest.preferOffline,
                      onChanged: _dexDownloading ? null : _setDexPreferOffline,
                    ),
                  ],
                ),
                OutlinedButton(
                  onPressed: _dexDownloading ? null : _clearDexOffline,
                  child: const Text(AppZh.settingsDexOfflineClear),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        StickerCard(
          variant: StickerVariant.sky,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppZh.settingsEmulator, style: SecondaryTypography.onCard.h15),
              const SizedBox(height: 8),
              Text(
                AppZh.settingsEmulatorHint,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                emulator != null
                    ? AppZh.settingsEmulatorSelected(emulator.appName)
                    : AppZh.settingsEmulatorUnset,
                style: SecondaryTypography.onCard.body14.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: widget.onPickEmulator,
                style: FilledButton.styleFrom(
                  backgroundColor: TitoColors.coral,
                  foregroundColor: TitoColors.ink,
                ),
                child: const Text(AppZh.settingsPickEmulator),
              ),
              if (emulator != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: widget.onClearEmulator,
                  child: const Text(AppZh.settingsClearEmulator),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppZh.settingsGroupAdvanced, style: SecondaryTypography.onCard.h15),
              const SizedBox(height: 8),
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
              const SizedBox(height: 6),
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
                onPressed: widget.onExportJourney,
                child: const Text(AppZh.settingsExportJourney),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: widget.onImportJourney,
                child: const Text(AppZh.settingsImportJourney),
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
      ),
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
          Text(
            label,
            style: SecondaryTypography.onCard.team12.copyWith(
              color: TitoColors.mutedInk,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: SecondaryTypography.onCard.meta14,
            ),
          ),
        ],
      ),
    );
  }
}
