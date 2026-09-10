import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/app_update/app_update_service.dart';
import '../l10n/app_zh.dart';
import '../theme/secondary_typography.dart';
import 'sticker_card.dart';
import 'tito_progress_bar.dart';

class AppUpdateCard extends StatefulWidget {
  const AppUpdateCard({super.key, this.service});
  final AppUpdateService? service;
  @override
  State<AppUpdateCard> createState() => _AppUpdateCardState();
}

class _AppUpdateCardState extends State<AppUpdateCard> {
  late final service = widget.service ?? appUpdateService;
  @override
  void initState() {
    super.initState();
    service.load();
  }

  Future<void> _downloadAndInstall() async {
    await service.download();
    if (mounted &&
        ModalRoute.of(context)?.isCurrent == true &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
        service.phase == AppUpdatePhase.ready) {
      await service.install();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) {
      final installed = service.installed;
      final release = service.release;
      final downloading = service.phase == AppUpdatePhase.downloading;
      return StickerCard(
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppZh.appUpdateTitle, style: SecondaryTypography.onCard.h15),
              const SizedBox(height: 6),
              Text(
                installed == null
                    ? AppZh.appUpdateReading
                    : '${installed.version} · ${installed.offline ? 'Offline' : 'Lite'} (${installed.buildNumber})',
                style: SecondaryTypography.onCard.body14,
              ),
              if (service.loaded && installed?.canUpdate != true)
                Text(
                  AppZh.appUpdateUnsupported,
                  style: SecondaryTypography.onCard.small12,
                )
              else ...[
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(AppZh.appUpdateAutomatic),
                  subtitle: Text(AppZh.appUpdateAutomaticHint),
                  value: service.automatic,
                  onChanged: service.setAutomatic,
                ),
                if (release != null) ...[
                  const Divider(),
                  Text(
                    '${AppZh.appUpdateAvailable} · ${release.version}',
                    style: SecondaryTypography.onCard.h15,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${release.title} · ${(release.bytes / 1000000).toStringAsFixed(2)} MB',
                  ),
                  if (release.notes.isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(AppZh.appUpdateNotes),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            release.notes.length > 8000
                                ? '${release.notes.substring(0, 8000)}…'
                                : release.notes,
                            style: SecondaryTypography.onCard.small12,
                          ),
                        ),
                      ],
                    ),
                  if (downloading ||
                      service.phase == AppUpdatePhase.verifying) ...[
                    TitoProgressBar(value: service.progress, height: 10),
                    const SizedBox(height: 6),
                    Text(
                      downloading
                          ? '${AppZh.appUpdateDownloading} ${(service.progress * 100).round()}%'
                          : AppZh.appUpdateVerifying,
                    ),
                    Text(
                      AppZh.appUpdateKeepOpen,
                      style: SecondaryTypography.onCard.small12,
                    ),
                    if (downloading)
                      TextButton(
                        onPressed: service.cancelDownload,
                        child: Text(AppZh.cancel),
                      ),
                  ],
                  if (service.permissionRequired)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(AppZh.appUpdatePermission),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: service.busy
                        ? null
                        : service.phase == AppUpdatePhase.ready
                        ? service.install
                        : _downloadAndInstall,
                    icon: Icon(
                      service.phase == AppUpdatePhase.ready
                          ? Icons.install_mobile_outlined
                          : Icons.download_rounded,
                    ),
                    label: Text(
                      service.phase == AppUpdatePhase.installing
                          ? AppZh.appUpdateVerifying
                          : service.phase == AppUpdatePhase.ready
                          ? AppZh.appUpdateInstall
                          : AppZh.appUpdateDownload,
                    ),
                  ),
                ] else if (service.checked && service.error == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(AppZh.appUpdateLatest),
                  ),
                if (service.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      switch (service.error) {
                        'download' => AppZh.appUpdateDownloadFailed,
                        'install' => AppZh.appUpdateInstallFailed,
                        _ => AppZh.appUpdateCheckFailed,
                      },
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: service.busy ? null : () => service.check(),
                      child: Text(
                        service.phase == AppUpdatePhase.checking
                            ? AppZh.appUpdateChecking
                            : AppZh.appUpdateCheck,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final uri =
                            release?.page ??
                            Uri.parse(
                              'https://github.com/Tito-XD/tito-dex/releases/latest',
                            );
                        try {
                          if (await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          )) {
                            return;
                          }
                        } catch (_) {
                          /* Report unsupported browser below. */
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppZh.appUpdateBrowserFailed),
                            ),
                          );
                        }
                      },
                      child: Text(AppZh.appUpdateReleasePage),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
