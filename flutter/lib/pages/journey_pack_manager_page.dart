import 'dart:async';

import 'package:flutter/material.dart';

import '../features/game/game_edition.dart';
import '../features/game/game_catalog.dart';
import '../features/game/game_edition_repository.dart';
import '../features/journey/journey_pack_models.dart';
import '../features/journey/journey_pack_repository.dart';
import '../features/journey/progression_hints.dart';
import '../l10n/app_zh.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';
import '../widgets/tito_loading_panel.dart';
import '../widgets/tito_progress_bar.dart';

class JourneyPackManagerPage extends StatefulWidget {
  const JourneyPackManagerPage({
    super.key,
    required this.edition,
    this.repository,
    this.refreshCatalogOnOpen = true,
  });

  final GameEdition edition;
  final JourneyPackRepository? repository;
  @visibleForTesting
  final bool refreshCatalogOnOpen;

  @override
  State<JourneyPackManagerPage> createState() => _JourneyPackManagerPageState();
}

class _JourneyPackManagerPageState extends State<JourneyPackManagerPage> {
  late final JourneyPackRepository _repository;
  late GameEdition _edition;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? journeyPackRepository;
    _edition = widget.edition;
    _repository.addListener(_refresh);
    unawaited(_initialLoad());
  }

  Future<void> _initialLoad() async {
    await _repository.loadInstalled();
    if (!mounted ||
        !_repository.featureEnabled ||
        !widget.refreshCatalogOnOpen) {
      return;
    }
    await _repository.refreshCatalog();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _repository.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _pickEdition() async {
    final selected = await showGameEditionGridPicker(
      context,
      selected: _edition,
    );
    if (!mounted || selected == null) return;
    await gameEditionRepository.save(selected);
    if (mounted) setState(() => _edition = selected);
  }

  Future<void> _install(JourneyPackDescriptor descriptor) async {
    final result = await _repository.install(descriptor);
    if (!mounted) return;
    if (result == 'installed') {
      progressionHintRepository.invalidate();
      _showMessage(AppZh.journeyPackInstalled);
    } else if (result != 'cancelled') {
      _showMessage(_errorLabel(result));
    }
  }

  Future<void> _delete(String family) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(AppZh.journeyPackDeleteTitle),
          content: Text(AppZh.journeyPackDeleteBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppZh.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppZh.journeyPackDelete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final result = await _repository.delete(family);
    if (!mounted) return;
    if (result == 'deleted') progressionHintRepository.invalidate();
    _showMessage(
      result == 'deleted' ? AppZh.journeyPackDeleted : _errorLabel(result),
    );
  }

  void _showMessage(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final exactGame = _edition.assistantGameKey;
    final catalogPacks = _repository.catalog?.packs ?? const [];
    final ordered = [...catalogPacks]
      ..sort((left, right) {
        final leftCurrent = left.supportsGame(exactGame) ? 0 : 1;
        final rightCurrent = right.supportsGame(exactGame) ? 0 : 1;
        return leftCurrent != rightCurrent
            ? leftCurrent.compareTo(rightCurrent)
            : left.titleZh.compareTo(right.titleZh);
      });
    final knownFamilies = ordered.map((pack) => pack.gameFamily).toSet();
    final orphaned = _repository.installed.values
        .where((pack) => !knownFamilies.contains(pack.descriptor.gameFamily))
        .toList(growable: false);

    return SecondaryPageScaffold(
      title: AppZh.journeyPackTitle,
      subtitle: AppZh.journeyPackSubtitle,
      children: [
        StickerCard(
          variant: StickerVariant.sky,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppZh.settingsCurrentGame,
                style: SecondaryTypography.onCard.small12,
              ),
              const SizedBox(height: 4),
              Text(
                _edition.selectedLabel,
                key: const Key('journey-pack-current-game'),
                style: SecondaryTypography.onCard.h15,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('journey-pack-change-game'),
                onPressed: _pickEdition,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: Text(AppZh.journeyPackSwitchGame),
              ),
              if (exactGame == null) ...[
                const SizedBox(height: 8),
                Text(AppZh.journeyPackPickExactGame),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        StickerCard(
          child: Text(
            AppZh.journeyPackPrivacyNote,
            style: SecondaryTypography.onCard.body14.copyWith(
              color: TitoColors.mutedInk,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                AppZh.journeyPackAvailable,
                style: SecondaryTypography.onPage(context).h15,
              ),
            ),
            TextButton.icon(
              onPressed: _repository.loadingCatalog
                  ? null
                  : _repository.refreshCatalog,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppZh.journeyPackRefresh),
            ),
          ],
        ),
        if (_repository.loadingCatalog && ordered.isEmpty)
          const TitoLoadingPanel(compact: true)
        else if (!_repository.catalogConfigured)
          _PackEmptyCard(
            key: Key('journey-pack-worker-unconfigured'),
            text: AppZh.journeyPackWorkerUnconfigured,
          )
        else if (ordered.isEmpty && orphaned.isEmpty)
          _PackEmptyCard(
            key: const Key('journey-pack-empty'),
            text: _repository.errorCode == null
                ? AppZh.journeyPackCatalogEmpty
                : AppZh.journeyPackCatalogUnavailable,
          ),
        for (final descriptor in ordered) ...[
          _JourneyPackCard(
            descriptor: descriptor,
            availability: _repository.availabilityFor(descriptor),
            currentGame: descriptor.supportsGame(exactGame),
            busy: _repository.busyFamily == descriptor.gameFamily,
            progress: _repository.busyFamily == descriptor.gameFamily
                ? _repository.downloadProgress
                : null,
            onInstall: () => _install(descriptor),
            onCancel: _repository.cancelDownload,
            onDelete: () => _delete(descriptor.gameFamily),
          ),
          const SizedBox(height: 12),
        ],
        for (final installed in orphaned) ...[
          _LegacyInstalledPackCard(
            installed: installed,
            onDelete: () => _delete(installed.descriptor.gameFamily),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _PackEmptyCard extends StatelessWidget {
  const _PackEmptyCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => StickerCard(child: Text(text));
}

class _JourneyPackCard extends StatelessWidget {
  const _JourneyPackCard({
    required this.descriptor,
    required this.availability,
    required this.currentGame,
    required this.busy,
    required this.progress,
    required this.onInstall,
    required this.onCancel,
    required this.onDelete,
  });

  final JourneyPackDescriptor descriptor;
  final JourneyPackAvailability availability;
  final bool currentGame;
  final bool busy;
  final double? progress;
  final VoidCallback onInstall;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final installed = availability == JourneyPackAvailability.installed;
    final update = availability == JourneyPackAvailability.updateAvailable;
    final incompatible = availability == JourneyPackAvailability.incompatible;
    return StickerCard(
      key: Key('journey-pack-${descriptor.gameFamily}'),
      variant: currentGame ? StickerVariant.softYellow : StickerVariant.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  descriptor.titleZh,
                  style: SecondaryTypography.onCard.h15,
                ),
              ),
              if (currentGame)
                Chip(label: Text(AppZh.settingsCurrentGame)),
            ],
          ),
          if (descriptor.descriptionZh case final description?) ...[
            const SizedBox(height: 6),
            Text(description, style: SecondaryTypography.onCard.body14),
          ],
          const SizedBox(height: 8),
          Text(
            AppZh.journeyPackMeta(
              descriptor.entryCount,
              (descriptor.sizeBytes / 1024).toStringAsFixed(0),
              descriptor.version,
            ),
            style: SecondaryTypography.onCard.small12.copyWith(
              color: TitoColors.mutedInk,
            ),
          ),
          if (busy) ...[
            const SizedBox(height: 10),
            TitoProgressBar(value: progress ?? 0, height: 6),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (busy)
                OutlinedButton.icon(
                  key: const Key('journey-pack-cancel'),
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded),
                  label: Text(AppZh.settingsDexCancelDownload),
                )
              else if (!installed && !incompatible)
                FilledButton.icon(
                  key: Key('journey-pack-install-${descriptor.gameFamily}'),
                  onPressed: onInstall,
                  icon: Icon(
                    update ? Icons.system_update_alt : Icons.download_rounded,
                  ),
                  label: Text(
                    update ? AppZh.journeyPackUpdate : AppZh.journeyPackInstall,
                  ),
                ),
              if ((installed || update) && !busy)
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(AppZh.journeyPackDelete),
                ),
              if (installed) Chip(label: Text(AppZh.extensionInstalled)),
              if (incompatible)
                Chip(label: Text(AppZh.journeyPackIncompatible)),
              if (availability == JourneyPackAvailability.corrupt)
                Chip(label: Text(AppZh.journeyPackCorrupt)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegacyInstalledPackCard extends StatelessWidget {
  const _LegacyInstalledPackCard({
    required this.installed,
    required this.onDelete,
  });

  final InstalledJourneyPack installed;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => StickerCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          installed.descriptor.titleZh,
          style: SecondaryTypography.onCard.h15,
        ),
        const SizedBox(height: 6),
        Text(AppZh.journeyPackLegacyInstalled),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(AppZh.journeyPackDelete),
          ),
        ),
      ],
    ),
  );
}

String _errorLabel(String code) => switch (code) {
  'worker_not_configured' => AppZh.journeyPackErrorWorkerNotConfigured,
  'network_timeout' => AppZh.journeyPackErrorTimeout,
  'pack_integrity_failed' ||
  'pack_size_mismatch' ||
  'pack_invalid' => AppZh.journeyPackErrorInvalid,
  'bundle_version_incompatible' => AppZh.journeyPackErrorBundleIncompatible,
  'disabled' => AppZh.journeyPackErrorDisabled,
  _ => AppZh.journeyPackErrorGeneric,
};
