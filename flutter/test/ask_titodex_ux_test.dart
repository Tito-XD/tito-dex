import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/companion/companion_repository.dart';
import 'package:titodex/features/game/game_edition.dart';
import 'package:titodex/features/journey/ask_titodex_answer_copy.dart';
import 'package:titodex/features/journey/ask_titodex_history.dart';
import 'package:titodex/features/journey/ask_titodex_sessions.dart';
import 'package:titodex/features/journey/ask_titodex_service.dart';
import 'package:titodex/features/journey/ask_titodex_settings.dart';
import 'package:titodex/features/journey/progression_hints.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/ask_titodex_page.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/tito_page_container.dart';
import 'ask_motion_test_images.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_ASK_UX')) return;
    final nunito = FontLoader('Nunito');
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      nunito.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
    }
    await nunito.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('Noto Sans CJK SC')..addFont(
          File(
            '/System/Library/Fonts/Hiragino Sans GB.ttc',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await companionRepository.clear();
    askTitoDexSettings.resetForTest();
    await askTitoDexSettings.load();
    await askTitoDexSettings.enableWithConsent();
  });

  Future<void> mount(
    WidgetTester tester,
    _PendingService service, {
    GlobalKey? captureKey,
    GameEdition? edition,
  }) async {
    final router = GoRouter(
      initialLocation: '/journey/ask',
      routes: [
        GoRoute(
          path: '/journey/ask',
          builder: (_, _) => TitoPageContainer(
            child: AskTitoDexPage(
              journey: _journey,
              edition: edition ?? GameEdition.hgss.withFlavor('soulsilver'),
              service: service,
              motionImagePreparer: prepareTestAskMotionImages,
            ),
          ),
        ),
        GoRoute(path: '/settings', builder: (_, _) => const Scaffold()),
      ],
    );
    addTearDown(router.dispose);
    var theme = buildTitoTheme();
    if (const bool.fromEnvironment('CAPTURE_ASK_UX')) {
      ButtonStyle withCjk(ButtonStyle? style) =>
          (style ?? const ButtonStyle()).copyWith(
            textStyle: WidgetStatePropertyAll(
              (style?.textStyle?.resolve({}) ??
                      theme.textTheme.labelLarge ??
                      const TextStyle())
                  .copyWith(fontFamilyFallback: const ['Noto Sans CJK SC']),
            ),
          );
      theme = theme.copyWith(
        textButtonTheme: TextButtonThemeData(
          style: withCjk(theme.textButtonTheme.style),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: withCjk(theme.filledButtonTheme.style),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: withCjk(theme.outlinedButtonTheme.style),
        ),
        textTheme: theme.textTheme.apply(
          fontFamilyFallback: const ['Noto Sans CJK SC'],
        ),
        chipTheme: theme.chipTheme.copyWith(
          labelStyle: theme.chipTheme.labelStyle?.copyWith(
            fontFamilyFallback: const ['Noto Sans CJK SC'],
          ),
        ),
      );
    }
    final app = MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: router,
    );
    await tester.pumpWidget(
      captureKey == null ? app : RepaintBoundary(key: captureKey, child: app),
    );
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String question) async {
    await tester.enterText(
      find.byKey(const Key('ask-titodex-question')),
      question,
    );
    await tester.tap(find.byKey(const Key('ask-titodex-submit')));
    await tester.pump();
  }

  Future<void> newConversation(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('ask-titodex-session-summary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ask-titodex-session-create')));
    await tester.pumpAndSettle();
  }

  test(
    'global unsupported and combined editions keep their title without selecting a local version',
    () {
      final emerald = AskTitoDexContext.fromJourney(
        _journey,
        gameEditionFromSlug('emerald')!,
      );
      expect(emerald.toRequestJson()['game'], 'general');
      expect(emerald.toRequestJson()['referenceGameTitle'], contains('绿宝石'));
      expect(
        emerald.copyWith(includeLocation: false).referenceGameTitle,
        emerald.referenceGameTitle,
      );
      final combined = AskTitoDexContext.fromJourney(
        _journey,
        gameEditionFromSlug('sv')!,
      );
      expect(combined.toRequestJson()['referenceGameTitle'], contains('朱/紫'));
      expect(
        AskTitoDexContext.fromJourney(
          _journey,
          GameEdition.general,
        ).toRequestJson().containsKey('referenceGameTitle'),
        isFalse,
      );
    },
  );

  testWidgets(
    'editing the next draft during a request preserves it on success',
    (tester) async {
      final service = _PendingService();
      await mount(tester, service);
      await send(tester, '第一个问题');
      await tester.enterText(
        find.byKey(const Key('ask-titodex-question')),
        '正在准备的下一问题',
      );
      service.pending[0].complete(_reply('第一个回答'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ask-titodex-question')))
            .controller!
            .text,
        '正在准备的下一问题',
      );
      expect(find.text('第一个回答'), findsOneWidget);
    },
  );

  testWidgets('stopping allows another question and rejects the late result', (
    tester,
  ) async {
    final service = _PendingService();
    await mount(tester, service);
    await send(tester, '旧的问题');
    await tester.enterText(
      find.byKey(const Key('ask-titodex-question')),
      '新的草稿',
    );
    await tester.tap(find.byKey(const Key('ask-titodex-stop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ask-titodex-submit')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ask-titodex-question')))
          .controller!
          .text,
      '新的草稿',
    );
    await send(tester, '新的问题');
    service.pending[0].complete(_reply('迟到的旧回答'));
    await tester.pump();
    service.pending[1].complete(_reply('新的回答'));
    await tester.pumpAndSettle();
    expect(find.text('迟到的旧回答'), findsNothing);
    expect(find.text('新的回答'), findsOneWidget);
    expect(
      (await AskTitoDexSessionStore().load()).active.entries.map(
        (entry) => entry.question,
      ),
      ['新的问题'],
    );
  });

  testWidgets('new topic keeps history and its boundary survives reopening', (
    tester,
  ) async {
    final service = _PendingService();
    await mount(tester, service);
    await send(tester, '旧话题问题');
    service.pending[0].complete(_reply('旧话题回答'));
    await tester.pumpAndSettle();
    await newConversation(tester);
    await tester.pumpAndSettle();
    expect((await AskTitoDexSessionStore().load()).sessions, hasLength(2));
    expect(
      (await AskTitoDexSessionStore().load()).sessions.first.entries,
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    final reopened = _PendingService();
    await mount(tester, reopened);
    expect(
      find.byKey(const ValueKey('ask-titodex-suggestion-0')),
      findsOneWidget,
    );
    await send(tester, '新话题问题');
    expect(reopened.histories.single, isEmpty);
    reopened.pending[0].complete(_reply('新话题回答'));
    await tester.pumpAndSettle();
    expect((await AskTitoDexSessionStore().load()).sessions, hasLength(2));
  });

  testWidgets('suggestions fill an editable draft without sending', (
    tester,
  ) async {
    final service = _PendingService();
    await mount(tester, service);
    await tester.tap(find.byKey(const ValueKey('ask-titodex-suggestion-0')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ask-titodex-question')))
          .controller!
          .text,
      contains('魂银'),
    );
    expect(service.pending, isEmpty);
    await tester.enterText(
      find.byKey(const Key('ask-titodex-question')),
      '修改后的问题',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ask-titodex-question')))
          .controller!
          .text,
      '修改后的问题',
    );
  });

  testWidgets(
    'copy includes original citations; model routes live in details',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final service = _PendingService();
      await mount(tester, service);
      await send(tester, '复制这个问题');
      service.pending[0].complete(_reply('回答正文'));
      await tester.pumpAndSettle();
      expect(find.text(AppZh.askTitoDexTraceModel), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('ask-titodex-copy-answer')),
      );
      await tester.tap(find.byKey(const Key('ask-titodex-copy-answer')));
      await tester.pump();
      expect(copied, contains('回答正文'));
      expect(copied, contains('https://wiki.52poke.com/wiki/Eevee'));
      await tester.ensureVisible(
        find.byKey(const Key('ask-titodex-source-summary')),
      );
      await tester.tap(find.byKey(const Key('ask-titodex-source-summary')));
      await tester.pumpAndSettle();
      expect(find.text(AppZh.askTitoDexTraceModel), findsOneWidget);
    },
  );

  testWidgets(
    'switching conversations restores their answers and separate drafts',
    (tester) async {
      final service = _PendingService();
      await mount(tester, service);
      await send(tester, '会话甲的问题');
      service.pending[0].complete(_reply('会话甲的回答'));
      await tester.pumpAndSettle();
      final firstId = (await AskTitoDexSessionStore().load()).activeId;
      await tester.enterText(
        find.byKey(const Key('ask-titodex-question')),
        '会话甲的草稿',
      );
      await newConversation(tester);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ask-titodex-question')))
            .controller!
            .text,
        isEmpty,
      );
      await send(tester, '会话乙的问题');
      service.pending[1].complete(_reply('会话乙的回答'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('ask-titodex-question')),
        '会话乙的草稿',
      );
      await tester.tap(find.byKey(const Key('ask-titodex-session-summary')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('ask-session-$firstId')));
      await tester.pumpAndSettle();
      expect(find.text('会话甲的回答'), findsOneWidget);
      expect(find.text('会话乙的回答'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ask-titodex-question')))
            .controller!
            .text,
        '会话甲的草稿',
      );
    },
  );

  test(
    'HTTP cancellation aborts one request without closing the reusable client',
    () async {
      final started = Completer<void>();
      final transport = _AbortTransport(started);
      final online = HttpAskTitoDexOnlineClient(
        client: transport,
        endpoint:
            'https://titodex-journey-assistant.example.workers.dev/v1/ask',
        deviceKeyProvider: () async => 'anonymous-device-test-key',
      );
      const context = AskTitoDexContext(
        game: 'soulsilver',
        generation: 4,
        locationLabel: null,
        locationId: null,
        badgeIds: [],
        milestoneIds: [],
        parserRevision: 2,
      );
      final pending = online.ask('第一个请求', context);
      final assertion = expectLater(
        pending,
        throwsA(isA<http.RequestAbortedException>()),
      );
      await started.future;
      online.cancelActiveQuestion();
      await assertion;
      expect((await online.ask('第二个请求', context)).answer, '再次请求成功');
    },
  );

  test(
    'copied answer deduplicates citation variants and skips unsafe links',
    () {
      final value = AskTitoDexResult(
        status: AskTitoDexStatus.answered,
        answer: '正文',
        sources: [
          const ProgressionSource(
            title: '资料',
            url: 'https://example.org/reference#one',
            accessedAt: '',
          ),
          const ProgressionSource(
            title: '重复',
            url: 'https://example.org/reference#two',
            accessedAt: '',
          ),
          const ProgressionSource(
            title: '私网',
            url: 'https://127.0.0.1/',
            accessedAt: '',
          ),
        ],
      );
      final text = askTitoDexAnswerCopyText('问题', value);
      expect(text, contains('#one'));
      expect(text, isNot(contains('#two')));
      expect(text, isNot(contains('127.0.0.1')));
    },
  );

  test(
    'concurrent stores preserve both replies in the same conversation',
    () async {
      final first = AskTitoDexSessionStore();
      final second = AskTitoDexSessionStore();
      final initial = await first.load();
      await Future.wait([
        first.append(
          initial.activeId,
          AskTitoDexHistoryEntry(
            game: 'soulsilver',
            question: '回复甲',
            result: _reply('甲'),
            createdAt: DateTime(2026, 10, 1),
          ),
        ),
        second.append(
          initial.activeId,
          AskTitoDexHistoryEntry(
            game: 'soulsilver',
            question: '回复乙',
            result: _reply('乙'),
            createdAt: DateTime(2026, 10, 2),
          ),
        ),
      ]);
      expect(
        (await first.load()).active.entries.map((entry) => entry.question),
        ['回复甲', '回复乙'],
      );
    },
  );

  test(
    'capacity refuses a twenty-first conversation without deleting anything',
    () async {
      final store = AskTitoDexSessionStore();
      final full = await _fillSessions(store);
      expect(full.sessions, hasLength(20));
      await expectLater(
        store.create(),
        throwsA(isA<AskTitoDexSessionLimitException>()),
      );
      final after = await store.load();
      expect(
        after.sessions.map((session) => session.id),
        full.sessions.map((session) => session.id),
      );
      final replacement = await store.create(replaceId: full.sessions.first.id);
      expect(replacement.sessions, hasLength(20));
      expect(
        replacement.sessions.any(
          (session) => session.id == full.sessions.first.id,
        ),
        isFalse,
      );
      expect(replacement.active.entries, isEmpty);
    },
  );

  test(
    'legacy messages migrate intact once and sessions keep separate context',
    () async {
      final entry = AskTitoDexHistoryEntry(
        game: 'soulsilver',
        question: '旧记录',
        result: _reply('旧回答'),
        createdAt: DateTime(2026, 10, 1),
      );
      await askTitoDexHistoryStore.append(entry);
      final store = AskTitoDexSessionStore();
      final migrated = await store.load();
      expect(migrated.sessions, hasLength(1));
      expect(migrated.active.entries.single.question, '旧记录');
      final fresh = await store.create();
      expect(fresh.active.entries, isEmpty);
      final selected = await store.select(migrated.activeId);
      expect(selected.active.entries.single.result.answer, '旧回答');
      final reopened = await AskTitoDexSessionStore().load();
      expect(reopened.sessions, hasLength(2));
      expect(reopened.activeId, migrated.activeId);
    },
  );

  testWidgets(
    'capacity prompt can cancel and delete oldest only after confirmation',
    (tester) async {
      final store = AskTitoDexSessionStore();
      final full = await _fillSessions(store);
      await mount(tester, _PendingService());
      await newConversation(tester);
      await tester.pumpAndSettle();
      expect(find.text(AppZh.askTitoDexSessionLimitTitle), findsOneWidget);
      await tester.tap(find.text(AppZh.cancel));
      await tester.pumpAndSettle();
      expect((await store.load()).sessions, hasLength(20));
      await newConversation(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ask-session-limit-oldest')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ask-session-delete-confirm')),
        findsOneWidget,
      );
      expect((await store.load()).sessions, hasLength(20));
      await tester.tap(find.byKey(const Key('ask-session-delete-confirm')));
      await tester.pumpAndSettle();
      final changed = await store.load();
      expect(changed.sessions, hasLength(20));
      expect(
        changed.sessions.any((session) => session.id == full.sessions.first.id),
        isFalse,
      );
      expect(changed.active.entries, isEmpty);
      expect(
        find.byKey(const ValueKey('ask-titodex-suggestion-0')),
        findsOneWidget,
      );
    },
  );

  testWidgets('render current page at phone size', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final service = _PendingService();
    await mount(tester, service, captureKey: key, edition: GameEdition.general);
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (!const bool.fromEnvironment('CAPTURE_ASK_UX')) return;
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          '/Users/tito/.codex/visualizations/2026/09/27/01a0e32d-d247-7a21-90ad-e2a1402e33e6/ask-ui-2026-10-08/$name.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    expect(find.byKey(const Key('ask-titodex-new-topic')), findsNothing);
    await capture('phone-idle');
    await send(tester, '伊布怎么进化？');
    const fixture = String.fromEnvironment('BASIC_ANSWER_FIXTURE_PATH');
    final preview =
        const bool.fromEnvironment('CAPTURE_ASK_UX') && fixture.isNotEmpty
        ? AskTitoDexResult.fromJson(
            Map<String, dynamic>.from(
              jsonDecode(File(fixture).readAsStringSync()) as Map,
            ),
          )
        : _reply('伊布有多种进化分支，常见方式包括使用进化石，以及满足亲密度和升级等条件。部分条件随游戏版本变化。');
    service.pending[0].complete(preview);
    await tester.pumpAndSettle();
    await capture('phone-answer');
    await tester.tap(find.byKey(const Key('ask-titodex-session-summary')));
    await tester.pumpAndSettle();
    await capture('phone-sessions');
  });
}

class _PendingService extends AskTitoDexService {
  final pending = <Completer<AskTitoDexResult>>[];
  final histories = <List<Map<String, String>>>[];
  @override
  Future<AskTitoDexWorkerStatus> checkConnection() async =>
      const AskTitoDexWorkerStatus(
        availability: AskTitoDexAvailability.online,
        qwenConfigured: true,
        textFallbackConfigured: true,
        dexBundleEnabled: true,
        aiSearchEnabled: true,
        curatedSourcesEnabled: true,
        webSearchEnabled: true,
        webSearchProviders: ['exa'],
      );
  @override
  Future<AskTitoDexContext> buildContext(AskTitoDexContext context) async =>
      context.copyWith(includeLocation: false, includeBadges: false);
  @override
  Future<AskTitoDexResult> ask(
    String question,
    AskTitoDexContext context, {
    List<Map<String, String>> history = const [],
    void Function(AskTitoDexProgress)? onProgress,
    AskTitoDexStreamEventCallback? onStreamEvent,
  }) {
    histories.add(history);
    final value = Completer<AskTitoDexResult>();
    pending.add(value);
    return value.future;
  }
}

AskTitoDexResult _reply(String answer) => AskTitoDexResult(
  status: AskTitoDexStatus.answered,
  answer: answer,
  onlineComposed: true,
  modelUsed: true,
  answerMode: AskTitoDexAnswerMode.curatedSourcesQwen,
  sourceKinds: const ['exa'],
  sources: const [
    ProgressionSource(
      title: '神奇宝贝百科 · 伊布',
      url: 'https://wiki.52poke.com/wiki/Eevee',
      accessedAt: '2026-10-08',
    ),
  ],
);
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

Future<AskTitoDexSessions> _fillSessions(AskTitoDexSessionStore store) async {
  var current = await store.load();
  for (var index = 0; index < askTitoDexSessionLimit; index++) {
    await store.append(
      current.activeId,
      AskTitoDexHistoryEntry(
        game: 'soulsilver',
        question: '会话 $index',
        result: _reply('回答 $index'),
        createdAt: DateTime(2026, 10, 1).add(Duration(minutes: index)),
      ),
    );
    if (index < askTitoDexSessionLimit - 1) current = await store.create();
  }
  return store.load();
}

class _AbortTransport extends http.BaseClient {
  _AbortTransport(this.started);
  final Completer<void> started;
  int calls = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls += 1;
    if (calls == 1) {
      started.complete();
      await (request as http.Abortable).abortTrigger;
      throw http.RequestAbortedException();
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(_reply('再次请求成功').toJson()))),
      200,
    );
  }
}
