import 'dart:async';

import 'package:flutter/material.dart';

import '../features/game/game_edition.dart';
import '../features/game/game_catalog.dart';
import '../features/game/game_edition_repository.dart';
import '../features/journey/journey_pack_models.dart';
import '../features/journey/journey_pack_repository.dart';
import '../features/journey/progression_hints.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';

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
      _showMessage('资料包已安装，可以用于问 TitoDex。');
    } else if (result != 'cancelled') {
      _showMessage(_errorLabel(result));
    }
  }

  Future<void> _delete(String family) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这份资料包？'),
        content: const Text('只会删除下载的问答资料，不会删除存档或问答记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await _repository.delete(family);
    if (!mounted) return;
    if (result == 'deleted') progressionHintRepository.invalidate();
    _showMessage(result == 'deleted' ? '资料包已删除。' : _errorLabel(result));
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
      title: 'Journey 资料包',
      subtitle: '按游戏安装，需要时再下载',
      children: [
        StickerCard(
          variant: StickerVariant.sky,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('当前游戏', style: SecondaryTypography.onCard.small12),
              const SizedBox(height: 4),
              Text(
                _edition.selectedLabelZh,
                key: const Key('journey-pack-current-game'),
                style: SecondaryTypography.onCard.h15,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('journey-pack-change-game'),
                onPressed: _pickEdition,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('切换游戏版本'),
              ),
              if (exactGame == null) ...[
                const SizedBox(height: 8),
                const Text('请先选择成对版本中的具体一款，再匹配对应资料包。'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        StickerCard(
          child: Text(
            '资料包只扩展问 TitoDex 的攻略上下文，保存在 App 私有目录。不会上传存档，也不会替换图鉴数据。',
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
                '可用资料包',
                style: SecondaryTypography.onCard.h15.copyWith(
                  color: TitoColors.card,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _repository.loadingCatalog
                  ? null
                  : _repository.refreshCatalog,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('刷新'),
            ),
          ],
        ),
        if (_repository.loadingCatalog && ordered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (!_repository.catalogConfigured)
          const _PackEmptyCard(
            key: Key('journey-pack-worker-unconfigured'),
            text: 'Journey Assistant Worker 尚未配置，已安装的旧资料仍可继续使用。',
          )
        else if (ordered.isEmpty && orphaned.isEmpty)
          _PackEmptyCard(
            key: const Key('journey-pack-empty'),
            text: _repository.errorCode == null
                ? '暂时没有可下载的资料包。'
                : '目录暂时无法读取，已安装的旧资料不会受影响。',
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
              if (currentGame) const Chip(label: Text('当前游戏')),
            ],
          ),
          if (descriptor.descriptionZh case final description?) ...[
            const SizedBox(height: 6),
            Text(description, style: SecondaryTypography.onCard.body14),
          ],
          const SizedBox(height: 8),
          Text(
            '${descriptor.entryCount} 条 · ${(descriptor.sizeBytes / 1024).toStringAsFixed(0)} KB · v${descriptor.version}',
            style: SecondaryTypography.onCard.small12.copyWith(
              color: TitoColors.mutedInk,
            ),
          ),
          if (busy) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress),
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
                  label: const Text('取消下载'),
                )
              else if (!installed && !incompatible)
                FilledButton.icon(
                  key: Key('journey-pack-install-${descriptor.gameFamily}'),
                  onPressed: onInstall,
                  icon: Icon(
                    update ? Icons.system_update_alt : Icons.download_rounded,
                  ),
                  label: Text(update ? '更新' : '安装'),
                ),
              if ((installed || update) && !busy)
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('删除'),
                ),
              if (installed) const Chip(label: Text('已安装')),
              if (incompatible) const Chip(label: Text('需要新版图鉴包')),
              if (availability == JourneyPackAvailability.corrupt)
                const Chip(label: Text('本地文件损坏，请重新安装')),
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
        const Text('已安装；当前目录未列出此版本，仍可安全使用。'),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('删除'),
          ),
        ),
      ],
    ),
  );
}

String _errorLabel(String code) => switch (code) {
  'worker_not_configured' => 'Journey Assistant Worker 尚未配置。',
  'network_timeout' => '连接超时，请稍后再试。',
  'pack_integrity_failed' ||
  'pack_size_mismatch' ||
  'pack_invalid' => '资料包校验失败，原有资料没有被替换。',
  'bundle_version_incompatible' => '需要先更新图鉴资料版本。',
  'disabled' => '请先在设置中启用问 TitoDex 助手。',
  _ => '操作没有完成，请稍后重试。',
};
