import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/extensions/journey_assistant_extension.dart';
import 'package:titodex/features/journey/ask_titodex_settings.dart';
import 'package:titodex/features/journey/journey_assistant.dart';
import 'package:titodex/features/journey/progression_hints.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/journey_page.dart';
import 'package:titodex/pages/search_page.dart';
import 'package:titodex/widgets/tito_page_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    askTitoDexSettings.resetForTest();
    await askTitoDexSettings.load();
  });

  test(
    'extension preferences default to enabled and compact search display',
    () {
      expect(askTitoDexSettings.extensionEnabled, isTrue);
      expect(
        askTitoDexSettings.searchDisplayMode,
        SearchAssistantDisplayMode.compact,
      );
    },
  );

  test('fake native state reports a verified installed pack', () async {
    final platform = _FakeExtensionPlatform(
      const JourneyAssistantExtensionInfo(
        installed: true,
        versionName: '0.1.0',
        versionCode: 1,
        contentVersion: 1,
        capabilities: ['progression_hints'],
      ),
    );
    final controller = JourneyAssistantExtensionController(platform: platform);

    await controller.refresh();

    expect(controller.installed, isTrue);
    expect(controller.info.contentVersion, 1);
    expect(controller.info.capabilities, contains('progression_hints'));
  });

  test('native resume or install status re-inspects the extension', () async {
    final platform = _FakeExtensionPlatform(
      JourneyAssistantExtensionInfo.notInstalled,
    );
    final controller = JourneyAssistantExtensionController(platform: platform);
    await controller.refresh();
    expect(controller.installed, isFalse);

    platform.info = const JourneyAssistantExtensionInfo(
      installed: true,
      versionName: '1.0.0',
      versionCode: 1,
      contentVersion: 1,
      capabilities: ['progression_hints'],
    );
    platform.emitStatusChanged();
    await pumpEventQueue();

    expect(controller.installed, isTrue);
    expect(platform.inspectCalls, 2);
    controller.dispose();
  });

  test('canonical catalog selects the journey assistant entry', () {
    final catalog = JourneyAssistantExtensionCatalog.fromJson({
      'schemaVersion': 1,
      'entries': [
        {
          'extensionId': 'journey_assistant',
          'packageId': JourneyAssistantExtensionContract.packageId,
          'versionName': '0.1.0',
          'versionCode': 1,
          'minHostVersion': '0.8.13',
          'displayNameZh': '旅程助手',
          'summaryZh': '测试扩展',
          'downloadPath': 'objects/journey-assistant-1.apk',
          'sizeBytes': 1234,
          'sha256': List.filled(64, 'a').join(),
          'capabilities': ['progression_hints'],
        },
      ],
    }, catalogUri: Uri.parse('https://example.test/extensions/catalog.json'));

    expect(catalog.packageId, JourneyAssistantExtensionContract.packageId);
    expect(
      catalog.apkUri,
      Uri.parse(
        'https://example.test/extensions/objects/journey-assistant-1.apk',
      ),
    );
    expect(catalog.versionCode, 1);
  });

  test('catalog endpoint accepts only the Journey Worker catalog path', () {
    final valid = JourneyAssistantExtensionController(
      platform: _FakeExtensionPlatform(
        JourneyAssistantExtensionInfo.notInstalled,
      ),
      catalogUrl:
          'https://worker.example.test/v1/extensions/journey_assistant/catalog',
    );
    final directR2 = JourneyAssistantExtensionController(
      platform: _FakeExtensionPlatform(
        JourneyAssistantExtensionInfo.notInstalled,
      ),
      catalogUrl: 'https://bucket.example.test/extension-catalog.json',
    );

    expect(valid.catalogConfigured, isTrue);
    expect(directR2.catalogConfigured, isFalse);
  });

  test('catalog cannot redirect an APK download away from its Worker origin', () {
    expect(
      () => JourneyAssistantExtensionCatalog.fromJson(
        {
          'schemaVersion': 1,
          'entries': [
            {
              'extensionId': 'journey_assistant',
              'packageId': JourneyAssistantExtensionContract.packageId,
              'versionCode': 1,
              'downloadUrl': 'https://r2.example.test/private.apk',
              'sizeBytes': 1234,
              'sha256': List.filled(64, 'a').join(),
            },
          ],
        },
        catalogUri: Uri.parse(
          'https://worker.example.test/v1/extensions/journey_assistant/catalog',
        ),
      ),
      throwsFormatException,
    );
  });

  test(
    'installed extension refuses same-version reinstall or downgrade',
    () async {
      final platform = _FakeExtensionPlatform(
        const JourneyAssistantExtensionInfo(
          installed: true,
          versionName: '1.0.0',
          versionCode: 2,
          contentVersion: 1,
          capabilities: ['progression_hints'],
        ),
      );
      final client = MockClient(
        (_) async => http.Response(
          '''{"schemaVersion":1,"entries":[{"extensionId":"journey_assistant","packageId":"${JourneyAssistantExtensionContract.packageId}","versionName":"1.0.0","versionCode":2,"minHostVersion":"0.8.13","displayNameZh":"旅程助手","summaryZh":"测试扩展","downloadPath":"objects/journey-assistant-2.apk","sizeBytes":1234,"sha256":"${List.filled(64, 'a').join()}","capabilities":["progression_hints"]}]}''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      final controller = JourneyAssistantExtensionController(
        platform: platform,
        client: client,
        catalogUrl:
            'https://example.test/v1/extensions/journey_assistant/catalog',
      );
      await controller.refresh();

      expect(await controller.installFromCatalog(), 'up_to_date');
      expect(platform.installCalls, 0);
    },
  );

  test(
    'installed extension data source takes priority over bundled preview',
    () async {
      final repository = ProgressionHintRepository(
        extensionDataSource: _FakeProgressionDataSource(
          '{"schemaVersion":1,"entries":[]}',
        ),
      );

      expect(await repository.load(), isEmpty);
    },
  );

  test('bundled HGSS hints load when no content APK is available', () async {
    final repository = ProgressionHintRepository(
      extensionDataSource: const _FakeProgressionDataSource(null),
    );

    final hints = await repository.load();

    expect(hints, hasLength(3));
    expect(hints.map((hint) => hint.id), contains('hgss-route36-sudowoodo'));
  });

  testWidgets('Journey exposes the built-in assistant without an install CTA', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/journey',
      routes: [
        GoRoute(
          path: '/journey',
          builder: (_, _) => TitoPageContainer(
            child: JourneyPage(
              journey: _journey,
              assistantFuture: Future.value(_snapshot),
              askTitoDexEnabled: true,
              onAskTitoDex: () {},
            ),
          ),
        ),
        GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    addTearDown(router.dispose);

    await tester.scrollUntilVisible(
      find.byKey(const Key('ask-titodex-entry')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('ask-titodex-entry')), findsOneWidget);
    expect(find.text('下载并安装'), findsNothing);
  });

  testWidgets('Search honors prominent, compact, and hidden display modes', (
    tester,
  ) async {
    Future<GoRouter> pump(SearchAssistantDisplayMode mode) async {
      final router = GoRouter(
        initialLocation: '/search',
        routes: [
          GoRoute(
            path: '/search',
            builder: (_, _) => TitoPageContainer(
              child: SearchPage(
                journey: _journey,
                assistantDisplayMode: mode,
                onAskTitoDex: () {},
              ),
            ),
          ),
          GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      return router;
    }

    var router = await pump(SearchAssistantDisplayMode.prominent);
    expect(find.byKey(const Key('search-assistant-prominent')), findsOneWidget);
    router.dispose();

    router = await pump(SearchAssistantDisplayMode.compact);
    await tester.tap(find.text('常用资料'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-assistant-compact')), findsOneWidget);
    router.dispose();

    router = await pump(SearchAssistantDisplayMode.hidden);
    expect(find.byKey(const Key('search-assistant-prominent')), findsNothing);
    await tester.tap(find.text('常用资料'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-assistant-compact')), findsNothing);
    router.dispose();
  });
}

class _FakeExtensionPlatform implements JourneyAssistantExtensionPlatform {
  _FakeExtensionPlatform(this.info);

  JourneyAssistantExtensionInfo info;
  int installCalls = 0;
  int inspectCalls = 0;
  VoidCallback? _statusChangedHandler;

  @override
  Future<JourneyAssistantExtensionInfo> inspect() async {
    inspectCalls += 1;
    return info;
  }

  @override
  Future<String> install(String apkPath) async {
    installCalls += 1;
    return 'started';
  }

  @override
  Future<String?> readTextFile(String path) async => null;

  @override
  void setStatusChangedHandler(VoidCallback handler) {
    _statusChangedHandler = handler;
  }

  void emitStatusChanged() => _statusChangedHandler?.call();

  @override
  Future<void> uninstall() async {}
}

class _FakeProgressionDataSource implements ProgressionHintDataSource {
  const _FakeProgressionDataSource(this.json);
  final String? json;

  @override
  Future<String?> loadJson() async => json;
}

const _journey = CurrentJourney(
  game: 'SoulSilver',
  trainerName: 'Tito',
  location: 'Route 36',
  badges: 3,
  maxBadges: 16,
  playTime: '18:42',
  party: [],
  timeline: [],
  companion: 'Cyndaquil',
);

const _snapshot = JourneyAssistantSnapshot(
  locationLabel: '36号道路',
  locationMatched: true,
  nearbyUncaught: [],
  nearbyUncaughtCount: 0,
  exactVersion: 'soulsilver',
  exactVersionLabel: '魂银',
  pairedVersionLabel: '心金',
  versionEncounterGaps: [],
  versionEncounterGapCount: 0,
  evolutionOrTradeMissing: [],
  evolutionOrTradeMissingCount: 0,
  partyEvolutions: [],
);
