import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/app_update/app_release.dart';
import 'package:titodex/features/app_update/app_update_service.dart';
import 'package:titodex/l10n/app_locale.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/app_update_card.dart';

const lite = InstalledApp(
  version: '0.9.17',
  buildNumber: 202,
  packageName: 'com.tito.titodex',
  arm64: true,
);
const offline = InstalledApp(
  version: '0.9.17-offline',
  buildNumber: 203,
  packageName: 'com.tito.titodex',
  arm64: true,
);

Map<String, dynamic> releaseJson({String version = '0.9.18'}) => {
  'tag_name': 'v$version',
  'draft': false,
  'prerelease': false,
  'body': 'Changes',
  'assets': [
    for (final variant in ['lite', 'offline'])
      <String, dynamic>{
        'name': 'TitoDex-$version-$variant-rg-arm64.apk',
        'state': 'uploaded',
        'size': variant == 'lite' ? 29000000 : 95000000,
        'digest': 'sha256:${'a' * 64}',
        'browser_download_url':
            'https://github.com/Tito-XD/tito-dex/releases/download/v$version/TitoDex-$version-$variant-rg-arm64.apk',
      },
  ],
};

class FakePlatform extends AppUpdatePlatform {
  FakePlatform([this.info = lite]);
  final InstalledApp info;
  int installs = 0;
  String installResult = 'started';
  @override
  bool get supported => true;
  @override
  Future<InstalledApp?> installed() async => info;
  @override
  Future<String> install(
    File file,
    AppRelease release, {
    required bool offline,
  }) async {
    expect(await file.exists(), isTrue);
    installs++;
    return installResult;
  }
}

class ChunkClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream.fromIterable([List.filled(131072, 1), List.filled(131072, 2)]),
        200,
        contentLength: 262144,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'cancelled download cannot reach the installer or leave a partial file',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'titodex-update-cancel-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final platform = FakePlatform();
      final service = AppUpdateService(
        platform: platform,
        cacheDirectory: () async => dir,
        clientFactory: ChunkClient.new,
      );
      await service.load();
      service.release = AppRelease(
        version: '0.9.18',
        title: '',
        notes: '',
        page: Uri.parse(
          'https://github.com/Tito-XD/tito-dex/releases/tag/v0.9.18',
        ),
        download: Uri.parse(
          'https://github.com/Tito-XD/tito-dex/releases/download/v0.9.18/test.apk',
        ),
        sha256: 'a' * 64,
        bytes: 262144,
        assetName: 'test.apk',
      );
      service.addListener(() {
        if (service.phase == AppUpdatePhase.downloading &&
            service.receivedBytes > 0) {
          service.cancelDownload();
        }
      });
      await service.download();
      await service.install();
      expect(platform.installs, 0);
      expect(service.error, isNull);
      expect(await Directory('${dir.path}/app_updates').list().length, 0);
    },
  );

  for (final style in AppVisualStyle.values) {
    testWidgets(
      '${style.name}: update controls fit narrow layouts and large English text',
      (tester) async {
        await appVisualStyle.setStyle(style);
        AppLocale.instance.debugOverride(AppUiLanguage.en);
        addTearDown(() => appVisualStyle.setStyle(AppVisualStyle.classic));
        addTearDown(() => AppLocale.instance.debugOverride(AppUiLanguage.zh));
        final service = AppUpdateService(platform: FakePlatform());
        await service.load();
        service.release = AppRelease.newerThan(releaseJson(), lite);
        service.phase = AppUpdatePhase.available;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTitoTheme(style),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 280,
                    child: SingleChildScrollView(
                      child: AppUpdateCard(service: service),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('compares stable, preview and Offline versions numerically', () {
    expect(
      AppVersion.parse(
        '0.9.18',
      )!.compareTo(AppVersion.parse('0.9.17-offline')!),
      greaterThan(0),
    );
    expect(
      AppVersion.parse(
        '0.9.17',
      )!.compareTo(AppVersion.parse('0.9.17-preview.1-offline')!),
      greaterThan(0),
    );
    expect(
      AppVersion.parse(
        '0.9.17-preview.10',
      )!.compareTo(AppVersion.parse('0.9.17-preview.2')!),
      greaterThan(0),
    );
    expect(
      AppVersion.parse('0.10.0')!.compareTo(AppVersion.parse('0.9.99')!),
      greaterThan(0),
    );
    expect(AppVersion.parse('unknown'), isNull);
    expect(
      () => AppRelease.newerThan({'message': 'Invalid response'}, lite),
      throwsFormatException,
    );
  });

  test(
    'selects the installed variant and ignores up-to-date and draft releases',
    () {
      expect(
        AppRelease.newerThan(releaseJson(), lite)!.assetName,
        contains('-lite-'),
      );
      expect(
        AppRelease.newerThan(releaseJson(), offline)!.assetName,
        contains('-offline-'),
      );
      expect(
        AppRelease.newerThan(releaseJson(version: '0.9.17'), lite),
        isNull,
      );
      expect(
        AppRelease.newerThan(releaseJson()..['draft'] = true, lite),
        isNull,
      );
      expect(
        AppRelease.newerThan(releaseJson()..['prerelease'] = true, lite),
        isNull,
      );
      expect(
        AppRelease.newerThan(
          releaseJson(),
          const InstalledApp(
            version: '0.9.16',
            buildNumber: 198,
            packageName: 'com.tito.titodex.flatui',
            arm64: true,
          ),
        ),
        isNull,
      );
      expect(
        AppRelease.newerThan(
          releaseJson(),
          const InstalledApp(
            version: '0.9.16',
            buildNumber: 198,
            packageName: 'com.tito.titodex',
            arm64: false,
          ),
        ),
        isNull,
      );
    },
  );

  test(
    'rejects missing variant, unchecked digest and foreign download URL',
    () {
      for (final change in <void Function(Map<String, dynamic>)>[
        (j) => (j['assets'] as List).removeAt(0),
        (j) => (j['assets'] as List)[0]['digest'] = null,
        (j) => (j['assets'] as List)[0]['browser_download_url'] =
            'https://example.com/update.apk',
        (j) => (j['assets'] as List)[0]['size'] = 999999999,
      ]) {
        final json = releaseJson();
        change(json);
        expect(() => AppRelease.newerThan(json, lite), throwsFormatException);
      }
    },
  );

  test(
    'automatic checks are daily, shared and never download an APK',
    () async {
      var requests = 0;
      final service = AppUpdateService(
        platform: FakePlatform(),
        clientFactory: () => MockClient((request) async {
          requests++;
          expect(request.url, AppUpdateService.latestUrl);
          return http.Response(jsonEncode(releaseJson()), 200);
        }),
      );
      await Future.wait([
        service.check(automaticCheck: true),
        service.check(automaticCheck: true),
      ]);
      expect(requests, 1);
      expect(service.phase, AppUpdatePhase.available);
      await service.check(automaticCheck: true);
      expect(requests, 1);
      await service.check();
      expect(requests, 2);
      await service.setAutomatic(false);
      await service.check(automaticCheck: true);
      expect(requests, 2);
    },
  );

  test(
    'network failure remains retryable and is never marked up-to-date',
    () async {
      final service = AppUpdateService(
        platform: FakePlatform(),
        clientFactory: () => MockClient((_) async => http.Response('', 403)),
      );
      await service.check();
      expect(service.error, 'check');
      expect(service.checked, isFalse);
      expect(service.phase, AppUpdatePhase.idle);
    },
  );

  for (final corruption in ['none', 'digest', 'truncated']) {
    test(
      'download validates bytes before allowing install: $corruption',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'titodex-update-test-',
        );
        addTearDown(() => dir.delete(recursive: true));
        final platform = FakePlatform();
        final bytes = utf8.encode('verified APK fixture');
        final service = AppUpdateService(
          platform: platform,
          cacheDirectory: () async => dir,
          clientFactory: () => MockClient(
            (_) async => http.Response.bytes(
              corruption == 'truncated' ? bytes.sublist(1) : bytes,
              200,
            ),
          ),
        );
        await service.load();
        service.release = AppRelease(
          version: '0.9.18',
          title: '',
          notes: '',
          page: Uri.parse(
            'https://github.com/Tito-XD/tito-dex/releases/tag/v0.9.18',
          ),
          download: Uri.parse(
            'https://github.com/Tito-XD/tito-dex/releases/download/v0.9.18/test.apk',
          ),
          sha256: corruption == 'digest'
              ? 'b' * 64
              : sha256.convert(bytes).toString(),
          bytes: bytes.length,
          assetName: 'test.apk',
        );
        await service.download();
        expect(
          await File('${dir.path}/app_updates/update.part').exists(),
          isFalse,
        );
        await service.install();
        if (corruption == 'none') {
          expect(service.phase, AppUpdatePhase.ready);
          expect(platform.installs, 1);
          platform.installResult = 'permission_required';
          await service.install();
          expect(service.permissionRequired, isTrue);
          platform.installResult = 'failed';
          await service.install();
          expect(service.error, 'install');
          expect(service.permissionRequired, isFalse);
          expect(service.phase, AppUpdatePhase.available);
          await service.download();
          expect(service.phase, AppUpdatePhase.ready);
          expect(service.error, isNull);
          expect(
            await File('${dir.path}/app_updates/update.apk').exists(),
            isTrue,
          );
        } else {
          expect(service.error, 'download');
          expect(platform.installs, 0);
          expect(
            await File('${dir.path}/app_updates/update.apk').exists(),
            isFalse,
          );
        }
      },
    );
  }
}
