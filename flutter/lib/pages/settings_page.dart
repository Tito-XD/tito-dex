import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/companion/companion_art.dart';
import '../features/app_shortcuts/app_shortcuts.dart';
import '../features/companion/companion_media.dart';
import '../features/companion/companion_repository.dart';
import '../features/dex/sprite_generation_catalog.dart';
import '../features/game/game_edition_repository.dart';
import '../features/game/journey_capability.dart';
import '../features/extensions/journey_assistant_extension.dart';
import '../features/journey/ask_titodex_settings.dart';
import '../features/launcher/emulator_launcher_repository.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_download_notification.dart';
import '../features/dex/dex_offline_service.dart';
import '../features/dex/dex_repository.dart';
import '../features/game/game_edition.dart';
import '../features/game/game_catalog.dart';
import '../features/dex/dex_settings_repository.dart';
import '../features/dex/dex_sprite_codec.dart';
import '../features/save/save_types.dart';
import '../features/parser/hgss_format.dart';
import '../features/trainer/trainer_avatar_service.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/motion_preferences.dart';
import '../widgets/retro_forms.dart';
import '../theme/retro_style.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../widgets/companion_picker_sheet.dart';
import '../widgets/fallback_sprite_image.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/settings_expandable_section.dart';
import '../widgets/sticker_card.dart';
import '../widgets/tito_progress_dialog.dart';
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
    required this.onPickSaveFile,
    required this.onClearSaveFile,
    required this.onToggleAutoLoad,
    required this.onSyncNow,
    required this.onExportJourney,
    required this.onImportJourney,
    required this.onPickEmulator,
    required this.onClearEmulator,
    this.onChangeGameEdition,
  });

  final CurrentJourney journey;
  final SaveFileConfig saveConfig;
  final EmulatorAppChoice? emulatorChoice;
  final VoidCallback onImportFixture;
  final VoidCallback onResetMock;
  final ValueChanged<CurrentJourney> onSaveJourney;
  final VoidCallback onPickSaveFile;
  final VoidCallback onClearSaveFile;
  final ValueChanged<bool> onToggleAutoLoad;
  final VoidCallback onSyncNow;
  final VoidCallback onExportJourney;
  final VoidCallback onImportJourney;
  final VoidCallback onPickEmulator;
  final VoidCallback onClearEmulator;

  /// Opens the game edition picker (same flow as the home header badge).
  final Future<void> Function(BuildContext context)? onChangeGameEdition;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _trainerController;
  bool _trainerDirty = false;
  bool _avatarChanging = false;
  DexCacheStatus? _dexCacheStatus;
  bool _dexDownloading = false;
  bool _dexDownloadBackgrounded = false;
  bool _dexVerifying = false;
  Timer? _dexStatusTimer;
  final _dexDownloadNotification = DexDownloadNotification();
  GameEdition _defaultGameEdition = defaultGameEdition;

  @override
  void initState() {
    super.initState();
    _trainerController = TextEditingController(
      text: widget.journey.trainerName,
    );
    _refreshDexCacheStatus();
    _loadDexSettings();
    _dexStatusTimer = Timer.periodic(const Duration(milliseconds: 750), (_) {
      if (_dexDownloading || dexOfflineService.isDownloading) {
        _syncDexDownloadStatus();
      }
    });
  }

  void _syncDexDownloadStatus() {
    if (!mounted) {
      return;
    }
    final isDownloading = dexOfflineService.isDownloading;
    final progress = dexOfflineService.progress;
    if (!isDownloading) {
      if (_dexDownloading) {
        setState(() => _dexDownloading = false);
        unawaited(_refreshDexCacheStatus());
      }
      return;
    }
    setState(() {
      _dexDownloading = true;
      _dexCacheStatus = DexCacheStatus(
        manifest:
            _dexCacheStatus?.manifest ??
            const DexCacheManifest(
              version: DexCacheManifest.currentVersion,
              complete: false,
              preferOffline: true,
            ),
        sizeBytes: _dexCacheStatus?.sizeBytes ?? 0,
        isDownloading: true,
        progress: progress,
      );
    });
  }

  Future<void> _loadDexSettings() async {
    final edition = await dexSettingsRepository.loadDefaultGameEdition();
    if (!mounted) {
      return;
    }
    setState(() => _defaultGameEdition = edition);
  }

  Future<void> _setDefaultGameEdition(GameEdition? edition) async {
    if (edition == null) {
      return;
    }
    await dexSettingsRepository.saveDefaultGameEdition(edition);
    if (!mounted) {
      return;
    }
    setState(() => _defaultGameEdition = edition);
  }

  Future<void> _toggleAskTitoDex(bool enabled) async {
    if (!enabled) {
      await askTitoDexSettings.setEnabled(false);
      return;
    }
    final accepted =
        askTitoDexSettings.noticeAcknowledged ||
        await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                title: const Text(AppZh.askTitoDexNoticeTitle),
                content: const Text(AppZh.askTitoDexNoticeBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text(AppZh.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text(AppZh.askTitoDexNoticeAccept),
                  ),
                ],
              ),
            ) ==
            true;
    if (!accepted) return;
    await askTitoDexSettings.acknowledgeNotice();
    await askTitoDexSettings.setEnabled(true);
  }

  Future<void> _installJourneyAssistantExtension() async {
    final result = await journeyAssistantExtension.installFromCatalog();
    if (!mounted) return;
    final message = result == 'started' || result == 'permission_required'
        ? AppZh.extensionInstallStarted
        : result == 'up_to_date'
        ? AppZh.extensionUpToDate
        : result == 'catalog_not_configured'
        ? AppZh.extensionCatalogUnavailable
        : AppZh.extensionInstallFailed;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDefaultGameEdition() async {
    final edition = await showGameEditionGridPicker(
      context,
      selected: _defaultGameEdition,
    );
    if (edition != null && mounted) {
      await _setDefaultGameEdition(edition);
    }
  }

  Future<void> _refreshDexCacheStatus() async {
    final status = await dexOfflineService.getStatus();
    if (!mounted) {
      return;
    }
    setState(() {
      _dexCacheStatus = status;
      _dexDownloading = status.isDownloading;
    });
  }

  Future<void> _downloadDexCdnBundle() async {
    if (_dexDownloading) {
      return;
    }
    setState(() => _dexDownloading = true);

    try {
      final lastProgress = await trackWhileDownloading(
        context: context,
        title: AppZh.settingsDexCdnDownload,
        onCancel: dexOfflineService.requestCancelDownload,
        onMinimize: Platform.isAndroid ? _minimizeDexDownload : null,
        download: (onProgress) => _consumeDexDownload(
          dexOfflineService.downloadFromCdnBundle(),
          onProgress,
        ),
      );
      await _finishDexBackgroundNotification(lastProgress);
      dexRepository.clearMemoryCache();
      await dexRepository.warmUp();
      await _refreshDexCacheStatus();
      if (!mounted) {
        return;
      }
      _showDexDownloadResult(lastProgress);
    } catch (_) {
      await _finishDexBackgroundNotification(null, failed: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppZh.snackDexCdnFailed)));
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
      final lastProgress = await trackWhileDownloading(
        context: context,
        title: AppZh.settingsDexOfflineDownloadPokeApi,
        onCancel: dexOfflineService.requestCancelDownload,
        onMinimize: Platform.isAndroid ? _minimizeDexDownload : null,
        download: (onProgress) =>
            _consumeDexDownload(dexOfflineService.downloadAll(), onProgress),
      );
      await _finishDexBackgroundNotification(lastProgress);
      dexRepository.clearMemoryCache();
      await dexRepository.warmUp();
      await _refreshDexCacheStatus();
      if (!mounted) {
        return;
      }
      _showDexOfflineDownloadResult(lastProgress);
    } catch (_) {
      await _finishDexBackgroundNotification(null, failed: true);
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

  Future<DexCacheProgress?> _consumeDexDownload(
    Stream<DexCacheProgress> stream,
    void Function(DexCacheProgress progress) onProgress,
  ) async {
    DexCacheProgress? lastProgress;
    await for (final progress in stream) {
      lastProgress = progress;
      onProgress(progress);
      if (mounted) {
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
                progress.phase != 'done' &&
                progress.phase != 'partial' &&
                progress.phase != 'cancelled',
            progress: progress,
          );
        });
      }
      if (_dexDownloadBackgrounded) {
        await _dexDownloadNotification.update(
          progress: _dexProgressPercent(progress),
          text: _dexNotificationText(progress),
        );
      }
      if (progress.phase == 'cancelled') {
        return lastProgress;
      }
    }
    return lastProgress;
  }

  Future<void> _minimizeDexDownload(DexCacheProgress? progress) async {
    _dexDownloadBackgrounded = true;
    final current = dexOfflineService.progress ?? progress;
    final notificationsGranted = await _dexDownloadNotification.start(
      progress: _dexProgressPercent(current),
      title: AppZh.dexDownloadNotificationTitle,
      text: _dexNotificationText(current),
    );
    if (!_dexDownloadNotification.active) {
      _dexDownloadBackgrounded = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppZh.snackDexBackgroundDownloadFailed)),
        );
      }
      throw StateError('Android foreground download service did not start');
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          notificationsGranted
              ? AppZh.snackDexBackgroundDownload
              : AppZh.snackDexBackgroundDownloadNoNotification,
        ),
      ),
    );
  }

  int _dexProgressPercent(DexCacheProgress? progress) =>
      (dexProgressDisplayFraction(progress) * 100).round().clamp(0, 100);

  String _dexNotificationText(DexCacheProgress? progress) {
    if (progress == null) {
      return '${AppZh.companionLoading} · 0%';
    }
    final percent = _dexProgressPercent(progress);
    final status = AppZh.settingsDexOfflineProgress(
      progress.phase,
      progress.current,
      progress.total,
    );
    final label = progress.label;
    return label == null || label.isEmpty
        ? '$status · $percent%'
        : '$status · $percent% · $label';
  }

  Future<void> _finishDexBackgroundNotification(
    DexCacheProgress? progress, {
    bool failed = false,
  }) async {
    if (!_dexDownloadBackgrounded) {
      return;
    }
    _dexDownloadBackgrounded = false;
    if (progress?.phase == 'cancelled') {
      await _dexDownloadNotification.cancel();
    } else if (!failed && progress?.phase == 'done') {
      await _dexDownloadNotification.complete(
        title: AppZh.dexDownloadNotificationDoneTitle,
        text: AppZh.dexDownloadNotificationDoneBody,
      );
    } else if (!failed && progress?.phase == 'partial') {
      await _dexDownloadNotification.complete(
        title: AppZh.dexDownloadNotificationPartialTitle,
        text: AppZh.dexDownloadNotificationPartialBody,
      );
    } else {
      await _dexDownloadNotification.fail(
        title: AppZh.dexDownloadNotificationFailedTitle,
        text: AppZh.dexDownloadNotificationFailedBody,
      );
    }
  }

  void _showDexDownloadResult(DexCacheProgress? lastProgress) {
    if (lastProgress?.phase == 'cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppZh.snackDownloadCancelled)),
      );
      return;
    }
    if (lastProgress?.phase == 'done') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppZh.snackDexCdnDone)));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppZh.snackDexCdnFailed)));
    }
  }

  void _showDexOfflineDownloadResult(DexCacheProgress? lastProgress) {
    if (lastProgress?.phase == 'cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppZh.snackDownloadCancelled)),
      );
      return;
    }
    final cachedCount = _dexCacheStatus?.manifest.pokemonCount ?? 0;
    if (lastProgress?.phase == 'done') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppZh.snackDexOfflineDone)));
    } else if (lastProgress?.phase == 'partial' && cachedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppZh.snackDexOfflinePartial(cachedCount))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppZh.snackDexOfflineFailed)),
      );
    }
  }

  Future<void> _verifyDexOffline() async {
    setState(() => _dexVerifying = true);
    final result = await dexOfflineService.verifyOfflineData();
    if (!mounted) {
      return;
    }
    setState(() => _dexVerifying = false);
    final String message;
    if (!result.hasData) {
      message = AppZh.settingsDexVerifyNoData;
    } else if (result.healthy) {
      message = result.missingSprites > 0
          ? '${AppZh.settingsDexVerifyOk(result.summaryCount)}'
                '${AppZh.settingsDexVerifySpriteNote(result.missingSprites)}'
          : AppZh.settingsDexVerifyOk(result.summaryCount);
    } else if (result.missingDetails > 0) {
      message = AppZh.settingsDexVerifyProblems(result.missingDetails);
    } else {
      message = AppZh.settingsDexVerifyIncomplete;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
  }

  @override
  void dispose() {
    _dexStatusTimer?.cancel();
    _trainerController.dispose();
    super.dispose();
  }

  Future<void> _changeAvatar() async {
    if (_avatarChanging) {
      return;
    }
    setState(() => _avatarChanging = true);

    try {
      final path = await TrainerAvatarService.pickAndCropSquare();
      if (!mounted) {
        return;
      }
      if (path == null) {
        return;
      }
      widget.onSaveJourney(
        widget.journey.copyWith(
          trainerAvatarPath: path,
          trainerAvatarCustomized: true,
        ),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppZh.snackAvatarUpdated)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppZh.snackAvatarFailed)));
    } finally {
      if (mounted) {
        setState(() => _avatarChanging = false);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final saveName = widget.journey.saveTrainerName;
    final config = widget.saveConfig;
    final selectedFileUri = config.selectedFileUri;
    final selectedFileName = config.selectedFileName;
    final hasSaveFile = selectedFileUri != null;
    final lastSynced = config.lastLoadedFileName;
    final emulator = widget.emulatorChoice;
    final dexCache = _dexCacheStatus;
    final dexManifest = dexCache?.manifest;
    final dexProgress = dexCache?.progress;
    final dexDisplayProgress = dexProgressDisplayFraction(dexProgress);
    final saveLinked = gameEditionRepository.edition.isSaveLinked;

    return SecondaryPageScaffold(
      title: AppZh.navSettings,
      children: [
        _CurrentGameSection(
          onChangeGameEdition: widget.onChangeGameEdition == null
              ? null
              : () => widget.onChangeGameEdition!(context).then((_) {
                  if (mounted) {
                    setState(() {});
                  }
                }),
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: AppZh.extensionOnlineTitle,
          child: StickerCard(
            variant: StickerVariant.softYellow,
            child: ListenableBuilder(
              listenable: Listenable.merge([
                askTitoDexSettings,
                journeyAssistantExtension,
              ]),
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${AppZh.extensionJourneyTitle} · '
                    '${journeyAssistantExtension.installed ? AppZh.extensionInstalled : AppZh.extensionNotInstalled}',
                    style: SecondaryTypography.onCard.h15,
                  ),
                  if (journeyAssistantExtension.info.versionName != null)
                    Text(
                      'v${journeyAssistantExtension.info.versionName}',
                      style: SecondaryTypography.onCard.small12.copyWith(
                        color: TitoColors.mutedInk,
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (!journeyAssistantExtension.installed)
                    FilledButton.icon(
                      key: const Key('settings-install-extension'),
                      onPressed:
                          journeyAssistantExtension.catalogConfigured &&
                              !journeyAssistantExtension.busy
                          ? _installJourneyAssistantExtension
                          : null,
                      icon: const Icon(Icons.download_rounded),
                      label: Text(
                        journeyAssistantExtension.busy
                            ? AppZh.extensionInstalling
                            : AppZh.extensionInstall,
                      ),
                    )
                  else ...[
                    _SettingsToggleRow(
                      icon: Icons.extension_outlined,
                      plateColor: TitoColors.softYellow,
                      label: AppZh.extensionEnabled,
                      hint: AppZh.settingsAskTitoDexHint,
                      value: askTitoDexSettings.extensionEnabled,
                      onChanged: askTitoDexSettings.setExtensionEnabled,
                    ),
                    _SettingsToggleRow(
                      icon: Icons.auto_awesome_outlined,
                      plateColor: TitoColors.skyBlue,
                      label: AppZh.settingsAskTitoDex,
                      hint: AppZh.askTitoDexNoticeBody,
                      value: askTitoDexSettings.enabled,
                      onChanged: _toggleAskTitoDex,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppZh.extensionSearchDisplay,
                      style: SecondaryTypography.onCard.body14,
                    ),
                    DropdownButton<SearchAssistantDisplayMode>(
                      key: const Key('extension-search-display-mode'),
                      isExpanded: true,
                      value: askTitoDexSettings.searchDisplayMode,
                      items: const [
                        DropdownMenuItem(
                          value: SearchAssistantDisplayMode.prominent,
                          child: Text(AppZh.extensionSearchProminent),
                        ),
                        DropdownMenuItem(
                          value: SearchAssistantDisplayMode.compact,
                          child: Text(AppZh.extensionSearchCompact),
                        ),
                        DropdownMenuItem(
                          value: SearchAssistantDisplayMode.hidden,
                          child: Text(AppZh.extensionSearchHidden),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          askTitoDexSettings.setSearchDisplayMode(value);
                        }
                      },
                    ),
                    if (journeyAssistantExtension.catalogConfigured)
                      OutlinedButton.icon(
                        key: const Key('settings-update-extension'),
                        onPressed: journeyAssistantExtension.busy
                            ? null
                            : _installJourneyAssistantExtension,
                        icon: const Icon(Icons.system_update_alt_rounded),
                        label: Text(
                          journeyAssistantExtension.busy
                              ? AppZh.extensionInstalling
                              : AppZh.extensionCheckUpdate,
                        ),
                      ),
                    OutlinedButton(
                      onPressed: journeyAssistantExtension.uninstall,
                      child: const Text(AppZh.extensionUninstall),
                    ),
                    Text(
                      AppZh.extensionUninstallHint,
                      style: SecondaryTypography.onCard.small12.copyWith(
                        color: TitoColors.mutedInk,
                      ),
                    ),
                  ],
                  if (!journeyAssistantExtension.catalogConfigured &&
                      !journeyAssistantExtension.installed) ...[
                    const SizedBox(height: 6),
                    Text(
                      AppZh.extensionCatalogUnavailable,
                      style: SecondaryTypography.onCard.small12.copyWith(
                        color: TitoColors.mutedInk,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: AppZh.settingsGroupTrainer,
          child: StickerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _SettingsAvatarPreview(journey: widget.journey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _avatarChanging ? null : _changeAvatar,
                        child: const Text(AppZh.settingsChangeAvatar),
                      ),
                    ),
                  ],
                ),
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
                      side: const BorderSide(
                        color: TitoColors.ink,
                        width: TitoBorders.card,
                      ),
                    ),
                  ),
                  child: const Text(AppZh.settingsSaveTrainerName),
                ),
                if (saveLinked) ...[
                  const SizedBox(height: 16),
                  Text(
                    AppZh.settingsJourneyReadOnly,
                    style: SecondaryTypography.onCard.h15,
                  ),
                  const SizedBox(height: 10),
                  _Row(
                    label: AppZh.settingsLocation,
                    value: localizeLocation(widget.journey.location),
                  ),
                  if (widget.journey.saveTrainerId != null)
                    _Row(
                      label: AppZh.settingsTrainerId,
                      value: widget.journey.saveTrainerId!.toString().padLeft(
                        5,
                        '0',
                      ),
                    ),
                  if (widget.journey.saveTrainerSecretId != null)
                    _Row(
                      label: AppZh.settingsTrainerSecretId,
                      value: widget.journey.saveTrainerSecretId!
                          .toString()
                          .padLeft(5, '0'),
                    ),
                  if (widget.journey.saveTrainerGender != null)
                    _Row(
                      label: AppZh.settingsTrainerGender,
                      value: widget.journey.saveTrainerGender!,
                    ),
                  if (widget.journey.saveLanguage != null)
                    _Row(
                      label: AppZh.settingsSaveLanguage,
                      value: widget.journey.saveLanguage!,
                    ),
                  if (widget.journey.saveMoney != null)
                    _Row(
                      label: AppZh.settingsSaveMoney,
                      value: '₽ ${widget.journey.saveMoney}',
                    ),
                  if (widget.journey.saveMotherMoney != null)
                    _Row(
                      label: AppZh.settingsMotherMoney,
                      value: '₽ ${widget.journey.saveMotherMoney}',
                    ),
                  if (widget.journey.saveStarterSpeciesId != null)
                    _Row(
                      label: AppZh.settingsStarter,
                      value: localizeSpecies(
                        speciesNameFor(widget.journey.saveStarterSpeciesId!),
                      ),
                    ),
                  if (widget.journey.saveDexSeenIds.isNotEmpty ||
                      widget.journey.saveDexCaughtIds.isNotEmpty)
                    _Row(
                      label: AppZh.settingsDexProgress,
                      value:
                          '已见 ${widget.journey.saveDexSeenIds.length} · 已捕 ${widget.journey.saveDexCaughtIds.length}',
                    ),
                  if (widget.journey.saveMapCoordinates.length == 3)
                    _Row(
                      label: AppZh.settingsMapCoordinates,
                      value: widget.journey.saveMapCoordinates.join(' / '),
                    ),
                  _Row(
                    label: AppZh.settingsPlayTime,
                    value: widget.journey.playTime,
                  ),
                  _Row(
                    label: AppZh.settingsBadges,
                    value: widget.journey.badgeProgressLabel,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _CompanionSection(journey: widget.journey),
        const SizedBox(height: 16),
        const _InterfaceSection(),
        const SizedBox(height: 16),
        const _AppShortcutsSection(),
        const SizedBox(height: 16),
        if (saveLinked)
          _SettingsGroup(
            title: AppZh.settingsGroupSaveSync,
            child: StickerCard(
              variant: StickerVariant.cream,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppZh.settingsSaveFileHint,
                    style: SecondaryTypography.onCard.small12.copyWith(
                      color: TitoColors.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selectedFileUri != null
                        ? AppZh.settingsSelectedSaveFile(
                            selectedFileName ?? selectedFileUri,
                          )
                        : AppZh.settingsSaveFileUnset,
                    style: SecondaryTypography.onCard.body14.copyWith(
                      color: !hasSaveFile
                          ? TitoColors.mutedInk
                          : TitoColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: widget.onPickSaveFile,
                    style: FilledButton.styleFrom(
                      backgroundColor: TitoColors.deepBlue,
                      foregroundColor: TitoColors.card,
                    ),
                    child: const Text(AppZh.settingsPickSaveFile),
                  ),
                  if (hasSaveFile) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: widget.onClearSaveFile,
                      child: const Text(AppZh.settingsClearSaveFile),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const StickerIconPlate(
                        icon: Icons.refresh_rounded,
                        color: TitoColors.skyBlue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppZh.settingsAutoLoadOnStartup,
                          style: SecondaryTypography.onCard.body14,
                        ),
                      ),
                      StickerSwitch(
                        value: config.autoLoadOnStartup,
                        onChanged: widget.onToggleAutoLoad,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                    onPressed: hasSaveFile ? widget.onSyncNow : null,
                    child: const Text(AppZh.settingsSyncNow),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: AppZh.settingsDexOffline,
          child: StickerCard(
            variant: StickerVariant.mint,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      ? AppZh.settingsDexOfflinePartial(
                          dexManifest.pokemonCount,
                        )
                      : AppZh.settingsDexOfflineUnset,
                  style: SecondaryTypography.onCard.body14.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_dexDownloading && dexProgress != null) ...[
                  const SizedBox(height: 12),
                  TitoProgressBar(value: dexDisplayProgress, height: 10),
                  const SizedBox(height: 6),
                  Text(
                    '${AppZh.settingsDexOfflineProgress(dexProgress.phase, dexProgress.current, dexProgress.total)} · ${(dexDisplayProgress * 100).round()}%',
                    style: SecondaryTypography.onCard.small12.copyWith(
                      color: TitoColors.mutedInk,
                    ),
                  ),
                  if (dexProgress.label != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      dexProgress.label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SecondaryTypography.onCard.small12.copyWith(
                        color: TitoColors.mutedInk,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                Text(
                  AppZh.settingsDexCdnDownloadHint,
                  style: SecondaryTypography.onCard.small12.copyWith(
                    color: TitoColors.mutedInk,
                  ),
                ),
                const SizedBox(height: 12),
                if (_dexDownloading)
                  OutlinedButton(
                    onPressed: dexOfflineService.requestCancelDownload,
                    child: const Text(AppZh.settingsDexCancelDownload),
                  )
                else
                  FilledButton(
                    onPressed: _downloadDexCdnBundle,
                    style: FilledButton.styleFrom(
                      backgroundColor: TitoColors.coral,
                      foregroundColor: TitoColors.ink,
                    ),
                    child: const Text(AppZh.settingsDexCdnDownload),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        StickerCard(
          variant: StickerVariant.mint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppZh.settingsDexAdvancedOptions,
                style: SecondaryTypography.onCard.body14.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _defaultGameEdition.labelZh,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
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
              OutlinedButton(
                onPressed: _dexDownloading ? null : _pickDefaultGameEdition,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(58),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _defaultGameEdition.labelZh,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SecondaryTypography.onCard.body14.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.expand_more_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                    StickerSwitch(
                      value: dexManifest.preferOffline,
                      onChanged: _dexDownloading ? null : _setDexPreferOffline,
                    ),
                  ],
                ),
                OutlinedButton(
                  onPressed: (_dexDownloading || _dexVerifying)
                      ? null
                      : _verifyDexOffline,
                  child: Text(
                    _dexVerifying
                        ? AppZh.settingsDexVerifyRunning
                        : AppZh.settingsDexVerify,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _dexDownloading ? null : _clearDexOffline,
                  child: const Text(AppZh.settingsDexOfflineClear),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: AppZh.settingsEmulator,
          child: StickerCard(
            variant: StickerVariant.sky,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
        ),
        const SizedBox(height: 16),
        StickerCard(
          variant: StickerVariant.cream,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: TitoColors.deepBlue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppZh.settingsUnofficialNotice,
                  style: SecondaryTypography.onCard.small12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SettingsExpandableSection(
          title: AppZh.settingsAttributionTitle,
          subtitle: AppZh.settingsAttributionHint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                AppZh.settingsAttributionBody,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'TitoDex',
                  applicationLegalese: AppZh.settingsUnofficialNotice,
                ),
                icon: const Icon(Icons.description_outlined),
                label: const Text(AppZh.settingsOpenSourceLicenses),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SettingsExpandableSection(
          title: AppZh.settingsGroupAdvanced,
          subtitle: AppZh.settingsGroupAdvancedHint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onImportFixture,
                      child: const Text(AppZh.settingsImportSave),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onExportJourney,
                      child: const Text(AppZh.settingsExportJourney),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onImportJourney,
                      child: const Text(AppZh.settingsImportJourney),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onResetMock,
                      child: const Text(AppZh.settingsResetMock),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// v0.6.7 preview grouping: a soft-yellow pill label floats above each
/// settings card instead of a heading inside it.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StickerGroupLabel(text: title),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// Template-style settings row: colored icon plate + label/hint column +
/// a [StickerSwitch]. Matches the mock's `.row` pattern.
class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.icon,
    required this.plateColor,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color plateColor;
  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          StickerIconPlate(icon: icon, color: plateColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: SecondaryTypography.onCard.body14),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: SecondaryTypography.onCard.small12.copyWith(
                    color: TitoColors.mutedInk,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          StickerSwitch(value: value, onChanged: onChanged),
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

/// Settings → 当前游戏: prominent edition card with the official icon and a
/// direct switch entry — previously the edition only appeared as the page
/// subtitle and the switcher sat three levels deep in dex advanced options.
class _CurrentGameSection extends StatelessWidget {
  const _CurrentGameSection({this.onChangeGameEdition});

  final VoidCallback? onChangeGameEdition;

  @override
  Widget build(BuildContext context) {
    final edition = gameEditionRepository.edition;

    return StickerCard(
      variant: StickerVariant.softYellow,
      child: Row(
        children: [
          GameEditionIcon(edition: edition, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppZh.settingsCurrentGame,
                  style: SecondaryTypography.onCard.small12.copyWith(
                    color: TitoColors.mutedInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  edition.labelZh,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SecondaryTypography.onCard.h15,
                ),
              ],
            ),
          ),
          if (onChangeGameEdition != null) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onChangeGameEdition,
              style: FilledButton.styleFrom(
                backgroundColor: TitoColors.deepBlue,
                foregroundColor: TitoColors.card,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              child: const Text(AppZh.settingsSwitchGame),
            ),
          ],
        ],
      ),
    );
  }
}

/// Settings → 界面风格: Retro sticker feel plus the list reveal animations.
class _InterfaceSection extends StatelessWidget {
  const _InterfaceSection();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([motionPreferences, retroStyle]),
      builder: (context, _) {
        return _SettingsGroup(
          title: AppZh.settingsGroupInterface,
          child: StickerCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SettingsToggleRow(
                  icon: Icons.auto_awesome_rounded,
                  plateColor: TitoColors.mint,
                  label: AppZh.settingsRetroStyle,
                  hint: AppZh.settingsRetroStyleHint,
                  value: retroStyle.enabled,
                  onChanged: retroStyle.setEnabled,
                ),
                const StickerRowDivider(),
                _SettingsToggleRow(
                  icon: Icons.view_carousel_rounded,
                  plateColor: TitoColors.skyBlue,
                  label: AppZh.settingsListAnimations,
                  hint: AppZh.settingsListAnimationsHint,
                  value: motionPreferences.listAnimationsEnabled,
                  onChanged: motionPreferences.setListAnimationsEnabled,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AppShortcutsSection extends StatelessWidget {
  const _AppShortcutsSection();

  Future<void> _showCustomizer(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TitoColors.card,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.86,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: appShortcutPreferences,
            builder: (context, _) {
              final selected = appShortcutPreferences.selected;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppZh.settingsAppShortcutsCustomize,
                            style: SecondaryTypography.onCard.h15,
                          ),
                        ),
                        TextButton(
                          onPressed: () => appShortcutPreferences.setSelected(
                            AppShortcutOption.defaults,
                          ),
                          child: const Text(AppZh.settingsAppShortcutsReset),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                      children: [
                        Text(
                          AppZh.settingsAppShortcutsHint,
                          style: SecondaryTypography.onCard.small12.copyWith(
                            color: TitoColors.mutedInk,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final section in AppShortcutSection.values) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 2),
                            child: Text(
                              section.labelZh,
                              style: SecondaryTypography.onCard.small12
                                  .copyWith(
                                    color: TitoColors.mutedInk,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          for (final option in AppShortcutOption.all.where(
                            (option) => option.section == section,
                          ))
                            CheckboxListTile(
                              key: ValueKey('app-shortcut-${option.id}'),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                option.labelZh,
                                style: SecondaryTypography.onCard.body14,
                              ),
                              value: selected.any(
                                (item) => item.id == option.id,
                              ),
                              onChanged: (_) async {
                                final changed = await appShortcutPreferences
                                    .toggle(option);
                                if (!changed && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        AppZh.settingsAppShortcutsLimit,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appShortcutPreferences,
      builder: (context, _) {
        final selected = appShortcutPreferences.selected;
        return _SettingsGroup(
          title: AppZh.settingsAppShortcuts,
          child: StickerCard(
            variant: StickerVariant.sky,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppZh.settingsAppShortcutsHint,
                  style: SecondaryTypography.onCard.small12.copyWith(
                    color: TitoColors.mutedInk,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  selected.isEmpty
                      ? AppZh.settingsAppShortcutsNone
                      : selected.map((item) => item.labelZh).join('、'),
                  style: SecondaryTypography.onCard.body14.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _showCustomizer(context),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text(AppZh.settingsAppShortcutsCustomize),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Settings → 同行宝可梦: current standby preview (animated, fetched on
/// demand) plus picker and reset-to-starter actions.
class _CompanionSection extends StatelessWidget {
  const _CompanionSection({required this.journey});

  final CurrentJourney journey;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: companionRepository,
      builder: (context, _) {
        final choice = companionRepository.choice;
        final speciesId =
            choice?.pokemonId ??
            speciesIdForName(journey.companion) ??
            companionSpeciesIds[hgssDefaultCompanion]!;
        final nameZh = choice?.nameZh ?? localizeSpecies(journey.companion);

        return _SettingsGroup(
          title: AppZh.companionSettingsTitle,
          child: StickerCard(
            variant: StickerVariant.sky,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SettingsToggleRow(
                  icon: Icons.cruelty_free_rounded,
                  plateColor: TitoColors.softYellow,
                  label: AppZh.companionSettingsToggle,
                  hint: AppZh.companionSettingsHint,
                  value: companionRepository.enabled,
                  onChanged: companionRepository.setEnabled,
                ),
                const StickerRowDivider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        AppZh.companionSettingsSize,
                        style: SecondaryTypography.onCard.body14,
                      ),
                      Expanded(
                        child: Slider(
                          value: companionRepository.sizeScale,
                          min: CompanionRepository.minSizeScale,
                          max: CompanionRepository.maxSizeScale,
                          divisions: 15,
                          label:
                              '×${companionRepository.sizeScale.toStringAsFixed(2)}',
                          onChanged: companionRepository.enabled
                              ? companionRepository.setSizeScale
                              : null,
                        ),
                      ),
                      Text(
                        '×${companionRepository.sizeScale.toStringAsFixed(2)}',
                        style: SecondaryTypography.onCard.small12.copyWith(
                          color: TitoColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const StickerRowDivider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: TitoColors.card,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: TitoColors.ink,
                            width: TitoBorders.element,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        padding: const EdgeInsets.all(4),
                        child: FallbackSpriteImage(
                          sources: [
                            if (choice?.animationSourceUrl != null)
                              choice!.animationSourceUrl!,
                            if (bundledCompanionGifAsset(speciesId) != null)
                              bundledCompanionGifAsset(speciesId)!,
                            ...animatedSpriteCandidatesFor(speciesId),
                          ],
                          showLoadingProgress: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nameZh,
                              style: SecondaryTypography.onCard.body14.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (choice?.animationLabel != null ||
                                choice?.cryLabel != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                [
                                  if (choice?.animationLabel != null)
                                    '动图：${choice!.animationLabel}',
                                  if (choice?.cryLabel != null)
                                    '叫声：${choice!.cryLabel}',
                                ].join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: SecondaryTypography.onCard.small12
                                    .copyWith(color: TitoColors.mutedInk),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const StickerRowDivider(),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: () =>
                            context.push('/settings/companion-position'),
                        style: FilledButton.styleFrom(
                          backgroundColor: TitoColors.skyBlue,
                          foregroundColor: TitoColors.ink,
                        ),
                        child: const Text(AppZh.companionSettingsPosition),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () async {
                          final picked = await showCompanionPickerSheet(
                            context,
                          );
                          if (picked != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppZh.companionPicked(picked.nameZh),
                                ),
                              ),
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: TitoColors.coral,
                          foregroundColor: TitoColors.ink,
                        ),
                        child: const Text(AppZh.companionSettingsPick),
                      ),
                      if (choice != null) ...[
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: companionRepository.clear,
                          child: const Text(AppZh.companionSettingsReset),
                        ),
                      ],
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/settings/media-resources'),
                        icon: const Icon(Icons.folder_zip_outlined, size: 18),
                        label: const Text('媒体资源管理'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsAvatarPreview extends StatelessWidget {
  const _SettingsAvatarPreview({required this.journey});

  final CurrentJourney journey;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    final avatarPath = journey.trainerAvatarPath;
    final hasImage =
        avatarPath != null &&
        avatarPath.isNotEmpty &&
        File(avatarPath).existsSync();

    final child = hasImage
        ? ClipOval(
            child: Image.file(
              File(avatarPath),
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          )
        : Text(
            journey.trainerName.isNotEmpty
                ? journey.trainerName[0].toUpperCase()
                : 'T',
            style: SecondaryTypography.onCard.h15.copyWith(
              fontWeight: FontWeight.w900,
              color: TitoColors.deepBlue,
            ),
          );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: hasImage
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [TitoColors.softYellow, TitoColors.coral],
              ),
        shape: BoxShape.circle,
        border: Border.all(color: TitoColors.ink, width: TitoBorders.element),
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
