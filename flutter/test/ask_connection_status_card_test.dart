import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/game/game_edition.dart';
import 'package:titodex/features/journey/ask_titodex_service.dart';
import 'package:titodex/features/journey/progression_hints.dart';
import 'package:titodex/l10n/app_locale.dart';
import 'package:titodex/widgets/ask/ask_connection_status_card.dart';
import 'package:titodex/theme/tito_theme.dart';

const connected = AskTitoDexWorkerStatus(
  availability: AskTitoDexAvailability.online,
  qwenConfigured: true,
  textFallbackConfigured: true,
  aiSearchEnabled: true,
  dexBundleEnabled: true,
  curatedSourcesEnabled: false,
  webSearchEnabled: true,
  webSearchProviders: ['exa', 'exa'],
);
const longSessionTitle = '关于紫版利欧路捕捉地点进化条件培养和推荐招式的详细问答会话记录';
const saveContext = AskTitoDexContext(
  game: 'soulsilver',
  generation: 4,
  locationLabel: '桔梗市',
  locationId: 'violet-city',
  badgeIds: ['plain_badge', 'zephyr_badge'],
  milestoneIds: [],
  parserRevision: 2,
);

Future<void> pumpCard(
  WidgetTester tester, {
  AskTitoDexWorkerStatus status = connected,
  int historyCount = 7,
  AskTitoDexContext? contextValue,
  double width = 420,
  double scale = 1,
  GlobalKey? screenshotKey,
  String? sessionTitle,
  VoidCallback? onSessions,
  VoidCallback? onHistory,
  VoidCallback? onEdition,
  VoidCallback? onRefresh,
  VoidCallback? onRemoveLocation,
  VoidCallback? onRemoveBadges,
}) async {
  final theme = buildTitoTheme();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme.copyWith(
        chipTheme: theme.chipTheme.copyWith(
          labelStyle: theme.chipTheme.labelStyle?.copyWith(
            fontFamilyFallback: const ['Noto Sans CJK SC'],
          ),
        ),
      ),
      home: RepaintBoundary(
        key: screenshotKey,
        child: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: MediaQuery(
              data: MediaQueryData(
                size: tester.view.physicalSize / tester.view.devicePixelRatio,
                textScaler: TextScaler.linear(scale),
              ),
              child: SizedBox(
                width: width,
                child: AskConnectionStatusCard(
                  status: status,
                  historyCount: historyCount,
                  contextValue: contextValue,
                  edition: GameEdition.hgss.withFlavor('soulsilver'),
                  onRefresh: onRefresh ?? () {},
                  onShowHistory: onHistory ?? () {},
                  sessionTitle: sessionTitle,
                  onShowSessions: onSessions,
                  onChangeEdition: onEdition ?? () {},
                  onRemoveLocation: onRemoveLocation,
                  onRemoveBadges: onRemoveBadges,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final capture = Platform.environment['TITODEX_STATUS_CAPTURE'] == '1';
  setUpAll(() async {
    if (!capture) return;
    final nunito = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-Bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-ExtraBold.ttf'));
    await nunito.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final systemChinese = File('/System/Library/Fonts/Hiragino Sans GB.ttc');
    if (await systemChinese.exists()) {
      final chinese = FontLoader('Noto Sans CJK SC')
        ..addFont(
          Future.value(ByteData.sublistView(await systemChinese.readAsBytes())),
        );
      await chinese.load();
    }
  });
  setUp(() => AppLocale.instance.debugOverride(AppUiLanguage.zh));
  tearDown(() => AppLocale.instance.debugOverride(AppUiLanguage.zh));

  testWidgets(
    'legacy caller keeps two equal areas without connection or storage fractions',
    (tester) async {
      var histories = 0;
      await pumpCard(tester, onHistory: () => histories++);
      final left = tester.getRect(
        find.byKey(const Key('ask-titodex-connection-summary')),
      );
      final right = tester.getRect(
        find.byKey(const Key('ask-titodex-history-summary')),
      );
      expect(left.width, closeTo(right.width, .01));
      expect(left.top, right.top);
      expect(find.text('联网可用'), findsOneWidget);
      expect(find.text('历史 7 条'), findsOneWidget);
      expect(find.textContaining('/50'), findsNothing);
      expect(find.textContaining(RegExp(r'在线 \d+/\d+')), findsNothing);
      await tester.tap(find.byKey(const Key('ask-titodex-history-summary')));
      expect(histories, 1);
    },
  );

  testWidgets(
    'session mode shows current conversation switch and removes local game picker',
    (tester) async {
      var sessions = 0;
      var editions = 0;
      await pumpCard(
        tester,
        sessionTitle: '捕捉利欧路',
        onSessions: () => sessions++,
        onEdition: () => editions++,
        contextValue: saveContext,
      );
      final left = tester.getRect(
        find.byKey(const Key('ask-titodex-connection-summary')),
      );
      final right = tester.getRect(
        find.byKey(const Key('ask-titodex-session-summary')),
      );
      expect(left.width, closeTo(right.width, .01));
      expect(find.text('捕捉利欧路'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
      expect(
        find.byKey(const Key('ask-titodex-history-summary')),
        findsNothing,
      );
      expect(find.textContaining('历史'), findsNothing);
      expect(
        find.byKey(const Key('ask-titodex-edition-summary')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('ask-titodex-current-edition')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('ask-titodex-location-context')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ask-titodex-badge-context')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('ask-titodex-session-summary')));
      expect(sessions, 1);
      expect(editions, 0);
    },
  );

  testWidgets(
    'empty session title uses current conversation and removes an empty context row',
    (tester) async {
      await pumpCard(tester, sessionTitle: '  ', onSessions: () {});
      expect(find.text('当前会话'), findsOneWidget);
      expect(find.byKey(const Key('ask-titodex-context-row')), findsNothing);
      expect(
        find.byKey(const Key('ask-titodex-connection-status')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const Key('ask-titodex-connection-status')))
            .height,
        closeTo(44, 2),
      );
    },
  );

  testWidgets(
    'long session names remain readable single-line text at 320 wide with large text',
    (tester) async {
      await pumpCard(
        tester,
        width: 320,
        scale: 1.7,
        sessionTitle: longSessionTitle,
        onSessions: () {},
        contextValue: saveContext,
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('ask-titodex-edition-summary')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('ask-titodex-location-context')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ask-titodex-badge-context')),
        findsOneWidget,
      );
      final title = tester.widget<Text>(find.text(longSessionTitle));
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(longSessionTitle.length, greaterThanOrEqualTo(30));
      expect(find.byTooltip(longSessionTitle), findsOneWidget);
      final labels = find
          .descendant(
            of: find.byKey(const Key('ask-titodex-session-summary')),
            matching: find.byType(Semantics),
          )
          .evaluate()
          .map((element) => (element.widget as Semantics).properties.label);
      expect(
        labels.any((label) => label?.contains(longSessionTitle) == true),
        isTrue,
      );
    },
  );

  testWidgets(
    'edition lives below capsule alongside verified context and preserves callbacks',
    (tester) async {
      var editions = 0;
      var locations = 0;
      var badges = 0;
      await pumpCard(
        tester,
        contextValue: saveContext,
        onEdition: () => editions++,
        onRemoveLocation: () => locations++,
        onRemoveBadges: () => badges++,
      );
      final capsule = tester.getRect(
        find.byKey(const Key('ask-titodex-status-segments')),
      );
      final edition = tester.getRect(
        find.byKey(const Key('ask-titodex-edition-summary')),
      );
      expect(edition.top, greaterThanOrEqualTo(capsule.bottom));
      expect(
        find.descendant(
          of: find.byKey(const Key('ask-titodex-context-row')),
          matching: find.byKey(const Key('ask-titodex-current-edition')),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('ask-titodex-edition-summary')));
      expect(editions, 1);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('ask-titodex-location-context')),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('ask-titodex-badge-context')),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      expect(locations, 1);
      expect(badges, 1);
    },
  );

  testWidgets('game selector remains available when no save context exists', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(
      find.byKey(const Key('ask-titodex-edition-summary')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ask-titodex-location-context')), findsNothing);
    expect(find.byKey(const Key('ask-titodex-badge-context')), findsNothing);
  });

  testWidgets(
    'small layout wraps long context at large text size without overflowing',
    (tester) async {
      await pumpCard(
        tester,
        width: 270,
        scale: 1.7,
        contextValue: const AskTitoDexContext(
          game: 'soulsilver',
          generation: 4,
          locationLabel: '城都地区非常长的存档地点名称用于检查小屏换行布局',
          locationId: 'long-location',
          badgeIds: ['plain_badge', 'zephyr_badge'],
          milestoneIds: [],
          parserRevision: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      final edition = tester.getRect(
        find.byKey(const Key('ask-titodex-edition-summary')),
      );
      final location = tester.getRect(
        find.byKey(const Key('ask-titodex-location-context')),
      );
      expect(location.top, greaterThan(edition.top));
      expect(
        find.byKey(const Key('ask-titodex-badge-context')),
        findsOneWidget,
      );
    },
  );

  for (final state in [
    AskTitoDexAvailability.disabled,
    AskTitoDexAvailability.unavailable,
  ]) {
    testWidgets('$state reads local-only without configuration counts', (
      tester,
    ) async {
      await pumpCard(
        tester,
        status: AskTitoDexWorkerStatus(availability: state),
      );
      expect(find.text('仅本地'), findsOneWidget);
      expect(find.text('历史 7 条'), findsOneWidget);
    });
  }

  testWidgets(
    'checking remains explicit and refresh cannot start overlapping checks',
    (tester) async {
      await pumpCard(tester, status: const AskTitoDexWorkerStatus.checking());
      expect(find.text('检查中'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ask-titodex-connection-summary')));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('ask-titodex-refresh-connection')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'details contain five service responsibilities and deduplicate search providers',
    (tester) async {
      var refreshes = 0;
      await pumpCard(tester, onRefresh: () => refreshes++);
      await tester.tap(find.byKey(const Key('ask-titodex-connection-summary')));
      await tester.pumpAndSettle();
      expect(find.text('联网连接'), findsOneWidget);
      expect(find.text('联网服务 · Journey Worker'), findsOneWidget);
      expect(find.text('回答整理与核验 · Qwen · DeepSeek 文本备用'), findsOneWidget);
      expect(find.text('网页检索 · Exa'), findsOneWidget);
      expect(find.text('图鉴资料 · TitoDex Bundle'), findsOneWidget);
      expect(find.text('审核提示 · AI Search'), findsOneWidget);
      expect(find.text('可用'), findsNWidgets(5));
      expect(find.textContaining('百科资料'), findsNothing);
      expect(find.textContaining('Tavily'), findsNothing);
      expect(find.text('联网搜索'), findsNothing);
      await tester.tap(find.byKey(const Key('ask-titodex-refresh-connection')));
      await tester.pumpAndSettle();
      expect(refreshes, 1);
    },
  );

  testWidgets(
    'explicit Tavily opt-in joins Exa within one web search responsibility',
    (tester) async {
      await pumpCard(
        tester,
        status: const AskTitoDexWorkerStatus(
          availability: AskTitoDexAvailability.online,
          qwenConfigured: true,
          webSearchEnabled: true,
          webSearchProviders: ['exa', 'tavily', 'exa'],
        ),
      );
      await tester.tap(find.byKey(const Key('ask-titodex-connection-summary')));
      await tester.pumpAndSettle();
      expect(find.text('网页检索 · Exa · Tavily'), findsOneWidget);
      expect(find.textContaining('网页检索'), findsOneWidget);
      expect(find.textContaining('DeepSeek'), findsNothing);
    },
  );

  testWidgets('English status and service roles follow the system language', (
    tester,
  ) async {
    AppLocale.instance.debugOverride(AppUiLanguage.en);
    await pumpCard(tester, onSessions: () {});
    expect(find.text('Online available'), findsOneWidget);
    expect(find.text('Current conversation'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ask-titodex-connection-summary')));
    await tester.pumpAndSettle();
    expect(find.text('Online connections'), findsOneWidget);
    expect(find.text('Online service · Journey Worker'), findsOneWidget);
    expect(
      find.text('Answer composition · Qwen · DeepSeek text fallback'),
      findsOneWidget,
    );
    expect(find.text('Web search · Exa'), findsOneWidget);
    expect(find.text('Dex data · TitoDex Bundle'), findsOneWidget);
    expect(find.text('Reviewed hints · AI Search'), findsOneWidget);
  });
  if (capture) {
    for (final scenario in [
      (name: 'status-390x844', size: const Size(390, 844), scale: 1.0),
      (name: 'status-640x480', size: const Size(640, 480), scale: 1.0),
      (name: 'status-320-large', size: const Size(320, 640), scale: 1.7),
    ]) {
      testWidgets('capture real status component ${scenario.name}', (
        tester,
      ) async {
        tester.view.physicalSize = scenario.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        await pumpCard(
          tester,
          width: scenario.size.width - 24,
          scale: scenario.scale,
          contextValue: saveContext,
          screenshotKey: boundaryKey,
          sessionTitle: scenario.name == 'status-320-large'
              ? longSessionTitle
              : '捕捉与进化',
          onSessions: () {},
          onRemoveLocation: () {},
          onRemoveBadges: () {},
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('/tmp/titodex-ask-status-evidence');
          await dir.create(recursive: true);
          await File(
            '${dir.path}/${scenario.name}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          expect(image.width, scenario.size.width.toInt());
          expect(image.height, scenario.size.height.toInt());
          image.dispose();
        });
      });
    }
  }
}
