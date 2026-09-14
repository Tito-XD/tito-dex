import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_offline_service.dart';
import 'package:titodex/features/save/save_types.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/settings_page.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/widgets/tito_progress_bar.dart';

void main() {
  late AppVisualStyle originalStyle;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    originalStyle = appVisualStyle.style;
    await appVisualStyle.setStyle(AppVisualStyle.flatUi);
  });
  tearDown(() => appVisualStyle.setStyle(originalStyle));

  for (final cancelled in [false, true]) {
    testWidgets(
      'returning to settings observes a download then ${cancelled ? 'cancellation' : 'completion'}',
      (tester) async {
        final service = _DownloadService();
        final router = _router(service);
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(find.text(AppZh.settingsDexCdnDownload), findsOneWidget);

        router.push('/settings/data');
        await tester.pumpAndSettle();
        // Another mounted settings page starts the shared service download.
        service.start();
        router.pop();
        await tester.pumpAndSettle();
        expect(find.text(AppZh.settingsDexCancelDownload), findsOneWidget);
        expect(find.byType(TitoProgressBar), findsOneWidget);
        expect(find.text(AppZh.settingsDexCdnDownload), findsNothing);

        if (cancelled) {
          await tester.tap(find.text(AppZh.settingsDexCancelDownload));
        } else {
          service.finish();
        }
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pumpAndSettle();
        expect(find.text(AppZh.settingsDexCancelDownload), findsNothing);
        expect(find.byType(TitoProgressBar), findsNothing);
        expect(
          find.text(AppZh.settingsDexCdnDownload),
          cancelled ? findsOneWidget : findsNothing,
        );

        final idleReads = service.progressReads;
        await tester.pump(const Duration(seconds: 3));
        expect(service.progressReads, idleReads);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('returning after a completed download refreshes the cache', (
    tester,
  ) async {
    final service = _DownloadService();
    final router = _router(service);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text(AppZh.settingsDexCdnDownload), findsOneWidget);

    router.push('/settings/data');
    await tester.pumpAndSettle();
    service.start();
    service.finish();
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text(AppZh.settingsDexCdnDownload), findsNothing);
    expect(find.text(AppZh.settingsDexCancelDownload), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

GoRouter _router(DexOfflineService service) => GoRouter(
  initialLocation: '/settings',
  routes: [
    GoRoute(
      path: '/settings',
      builder: (_, _) => Scaffold(body: _settings(service)),
      routes: [
        GoRoute(
          path: 'data',
          builder: (_, _) =>
              Scaffold(body: _settings(service, section: SettingsSection.data)),
        ),
      ],
    ),
  ],
);

SettingsPage _settings(
  DexOfflineService service, {
  SettingsSection section = SettingsSection.overview,
}) => SettingsPage(
  journey: CurrentJourney.mock(),
  saveConfig: const SaveFileConfig(),
  emulatorChoice: null,
  onImportFixture: () {},
  onResetMock: () {},
  onSaveJourney: (_) {},
  onPickSaveFile: () {},
  onClearSaveFile: () {},
  onToggleAutoLoad: (_) {},
  onSyncNow: () {},
  onExportJourney: () {},
  onImportJourney: () {},
  onPickEmulator: () {},
  onClearEmulator: () {},
  offlineService: service,
  section: section,
);

class _DownloadService extends DexOfflineService {
  bool downloading = false;
  bool complete = false;
  int progressReads = 0;

  void start() => downloading = true;

  void finish() {
    downloading = false;
    complete = true;
  }

  @override
  bool get isDownloading => downloading;

  @override
  DexCacheProgress? get progress {
    progressReads += 1;
    return downloading
        ? const DexCacheProgress(phase: 'cdn_download', current: 1, total: 2)
        : null;
  }

  @override
  Future<DexCacheStatus> getStatus() async => DexCacheStatus(
    manifest: DexCacheManifest(
      version: DexCacheManifest.currentVersion,
      complete: complete,
      preferOffline: true,
      pokemonCount: complete ? 1025 : 0,
    ),
    sizeBytes: 0,
    isDownloading: downloading,
    progress: progress,
  );

  @override
  void requestCancelDownload() => downloading = false;
}
