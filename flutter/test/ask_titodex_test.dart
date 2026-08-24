import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:titodex/features/companion/companion_repository.dart';
import 'package:titodex/features/game/game_edition.dart';
import 'package:titodex/features/journey/ask_titodex_entity_links.dart';
import 'package:titodex/features/journey/ask_titodex_history.dart';
import 'package:titodex/features/journey/ask_titodex_service.dart';
import 'package:titodex/features/journey/ask_titodex_settings.dart';
import 'package:titodex/features/journey/journey_assistant.dart';
import 'package:titodex/features/journey/progression_hints.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/models/parsed_save.dart';
import 'package:titodex/pages/ask_titodex_page.dart';
import 'package:titodex/pages/journey_page.dart';
import 'package:titodex/widgets/assistant_surface.dart';
import 'package:titodex/widgets/tito_page_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await companionRepository.clear();
    askTitoDexSettings.resetForTest();
    await askTitoDexSettings.load();
  });

  test(
    'feature is opt-in and creates only an anonymous random rate-limit key',
    () async {
      expect(askTitoDexSettings.enabled, isFalse);
      expect(askTitoDexSettings.noticeAcknowledged, isFalse);
      expect(askTitoDexSettings.extensionEnabled, isFalse);

      final first = await askTitoDexSettings.anonymousDeviceKey();
      final second = await askTitoDexSettings.anonymousDeviceKey();
      expect(first, second);
      expect(first, matches(RegExp(r'^[A-Za-z0-9_-]{20,}$')));
      expect(first, isNot(contains('Tito')));
    },
  );

  test('request context omits save, trainer, party and unselected context', () {
    final context = AskTitoDexContext.fromJourney(
      _journey,
      GameEdition.hgss.withFlavor('soulsilver'),
      locationId: 'johto-route-36-area',
    ).copyWith(includeLocation: false, includeBadges: false);
    final encoded = jsonEncode(context.toRequestJson());

    expect(encoded, contains('soulsilver'));
    expect(encoded, isNot(contains('locationId')));
    expect(context.toRequestJson()['badgeIds'], isEmpty);
    expect(context.toRequestJson()['parserRevision'], saveParserRevision);
    expect(context.toRequestJson()['contextReliability'], {
      'game': 'save_verified',
      'location': 'unknown',
      'badges': 'unknown',
      'milestones': 'unsupported',
    });
    for (final forbidden in [
      'trainer',
      'Tito',
      'party',
      'saveTrainerId',
      'rawSave',
    ]) {
      expect(encoded, isNot(contains(forbidden)));
    }
  });

  test('entry support is limited to exact HeartGold or SoulSilver context', () {
    expect(
      isAskTitoDexSupported(
        _journey,
        GameEdition.hgss.withFlavor('soulsilver'),
      ),
      isTrue,
    );
    expect(
      isAskTitoDexSupported(
        _journey.copyWith(game: 'Platinum'),
        GameEdition.all.firstWhere((edition) => edition.slug == 'pt'),
      ),
      isFalse,
    );
  });

  test(
    'recognized non-HGSS save sends only badge count, never guessed IDs',
    () {
      final context = AskTitoDexContext.fromJourney(
        _journey.copyWith(
          game: 'Platinum',
          badges: 5,
          verifiedBadgeIds: const [],
        ),
        GameEdition.all.firstWhere((edition) => edition.slug == 'pt'),
        locationId: 'sinnoh-route-203-area',
      );
      final request = context.toRequestJson();

      expect(request['badgeIds'], isEmpty);
      expect(request['badgeCount'], 5);
      expect(
        (request['contextReliability'] as Map<String, dynamic>)['badges'],
        'count_only',
      );
    },
  );

  test('manual modern version sends an exact user-selected game context', () {
    final context = AskTitoDexContext.fromJourney(
      _journey,
      gameEditionFromSlug('sv')!.withFlavor('violet'),
    );
    final request = context.toRequestJson();

    expect(request['game'], 'violet');
    expect(request['generation'], 9);
    expect(request['badgeIds'], isEmpty);
    expect(request['milestoneIds'], isEmpty);
    expect(request['contextReliability'], {
      'game': 'user_selected',
      'location': 'unknown',
      'badges': 'unknown',
      'milestones': 'unsupported',
    });
  });

  test(
    'online client sends the bounded contract and anonymous abuse key',
    () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'status': 'no_match',
            'answer': null,
            'confidence': 'low',
            'followUp': '补充地点',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final online = HttpAskTitoDexOnlineClient(
        client: client,
        endpoint: 'https://example.test/v1/ask',
        deviceKeyProvider: () async => 'anonymous-test-key-123',
      );

      await online.ask(
        '那它呢？',
        _context,
        history: const [
          {'role': 'user', 'content': '太阳伊布怎么进化？'},
          {'role': 'assistant', 'content': '白天高亲密度升级。'},
        ],
      );
      expect(
        captured.headers['x-titodex-device-key'],
        'anonymous-test-key-123',
      );
      expect(captured.body, isNot(contains('Tito')));
      expect(captured.body, isNot(contains('rawSave')));
      expect(captured.body, contains('太阳伊布怎么进化'));
      expect(captured.body, contains('白天高亲密度升级'));
    },
  );
  test(
    'online client streams verified answer chunks and final metadata',
    () async {
      final client = MockClient((request) async {
        expect(request.headers['accept'], contains('application/x-ndjson'));
        return http.Response.bytes(
          utf8.encode(
            [
              jsonEncode({'type': 'progress', 'stage': 'retrieving'}),
              jsonEncode({'type': 'progress', 'stage': 'writing'}),
              jsonEncode({'type': 'answer_delta', 'delta': '白天、'}),
              jsonEncode({'type': 'answer_delta', 'delta': '高亲密度升级。'}),
              jsonEncode({
                'type': 'result',
                'result': {
                  'status': 'answered',
                  'answer': '白天、高亲密度升级。',
                  'confidence': 'medium',
                  'followUp': null,
                  'answerMode': 'curated_sources_qwen',
                  'modelUsed': true,
                },
              }),
            ].join('\n'),
          ),
          200,
          headers: {'content-type': 'application/x-ndjson'},
        );
      });
      final online = HttpAskTitoDexOnlineClient(
        client: client,
        endpoint: 'https://example.test/v1/ask',
        deviceKeyProvider: () async => 'anonymous-test-key-123',
      );

      final events = await online.askStream('太阳伊布怎么进化？', _context).toList();

      expect(
        events.map((event) => event.progress).whereType<AskTitoDexProgress>(),
        contains(AskTitoDexProgress.revealingAnswer),
      );
      expect(
        events.map((event) => event.answerDelta).whereType<String>().join(),
        '白天、高亲密度升级。',
      );
      expect(events.last.result?.answer, '白天、高亲密度升级。');
    },
  );

  test(
    'online client trims oldest history pairs to the Worker byte budget',
    () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'status': 'no_match',
            'answer': null,
            'confidence': 'low',
            'followUp': null,
          }),
          200,
        );
      });
      final online = HttpAskTitoDexOnlineClient(
        client: client,
        endpoint: 'https://example.test/v1/ask',
        deviceKeyProvider: () async => 'anonymous-test-key-123',
      );
      final history = <Map<String, String>>[];
      for (var index = 0; index < 6; index += 1) {
        history.add({
          'role': 'user',
          'content': '${List.filled(237, '问').join()}用户$index',
        });
        history.add({
          'role': 'assistant',
          'content': '${List.filled(597, '答').join()}回复$index',
        });
      }

      await online.ask('继续追问', _context, history: history);

      expect(utf8.encode(captured.body).length, lessThanOrEqualTo(10 * 1024));
      final payload = jsonDecode(captured.body) as Map<String, dynamic>;
      final sent = payload['history'] as List<dynamic>;
      expect(sent.length.isEven, isTrue);
      expect(sent.length, lessThan(history.length));
      expect((sent.last as Map<String, dynamic>)['content'], endsWith('回复5'));
    },
  );

  test('online client accepts only the Journey Worker ask path', () {
    expect(
      HttpAskTitoDexOnlineClient(
        endpoint: 'https://worker.example.test/v1/ask',
      ).isConfigured,
      isTrue,
    );
    expect(
      HttpAskTitoDexOnlineClient(
        endpoint: 'https://api.cloudflare.example/client/v4/ai/run',
      ).isConfigured,
      isFalse,
    );
  });

  test('health check exposes only sanitized Worker capabilities', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/health');
      return http.Response(
        jsonEncode({
          'ok': true,
          'schemaVersion': 2,
          'capabilities': {
            'worker': true,
            'publicModel': 'workers-ai-qwen',
            'aiSearch': true,
            'curatedSources': true,
            'sourceProviders': [
              'pokeapi',
              'strategywiki',
              'wikidata',
              'unexpected-provider',
            ],
            'braveSearch': false,
            'webSearch': true,
            'webSearchProviders': [
              'tavily',
              'deepseek-native',
              'unexpected-provider',
            ],
            'externalProvider': false,
          },
        }),
        200,
      );
    });
    final online = HttpAskTitoDexOnlineClient(
      client: client,
      endpoint: 'https://example.test/v1/ask',
    );

    final status = await online.checkStatus();

    expect(status.availability, AskTitoDexAvailability.online);
    expect(status.qwenConfigured, isTrue);
    expect(status.aiSearchEnabled, isTrue);
    expect(status.curatedSourcesEnabled, isTrue);
    expect(status.braveSearchEnabled, isFalse);
    expect(status.webSearchEnabled, isTrue);
    expect(status.webSearchProviders, ['tavily', 'deepseek-native']);
    expect(status.sourceProviders, ['pokeapi', 'strategywiki', 'wikidata']);
  });

  test('client preserves DeepSeek and dual-source execution traces', () {
    final result = AskTitoDexResult.fromJson({
      'status': 'answered',
      'answer': '悖谬宝可梦说明',
      'confidence': 'medium',
      'followUp': null,
      'onlineComposed': true,
      'answerMode': 'deepseek_native_search',
      'modelUsed': true,
      'aiSearchUsed': false,
      'sourceKinds': ['deepseek-native'],
    });

    expect(result.answerMode, AskTitoDexAnswerMode.deepseekNativeSearch);
    expect(result.modelUsed, isTrue);
    expect(result.sourceKinds, ['deepseek-native']);

    final dual = AskTitoDexResult.fromJson({
      'status': 'answered',
      'answer': '交叉核对说明',
      'confidence': 'medium',
      'followUp': null,
      'onlineComposed': true,
      'answerMode': 'multi_source_qwen',
      'modelUsed': true,
      'sourceKinds': ['tavily', 'deepseek-native'],
    });
    expect(dual.answerMode, AskTitoDexAnswerMode.multiSourceQwen);
    expect(dual.sourceKinds, ['tavily', 'deepseek-native']);
  });

  group('HGSS deterministic progression hints', () {
    final repository = ProgressionHintRepository(
      extensionDataSource: const _CanonicalProgressionDataSource(),
    );

    test(
      'golden case uses verified Plain Badge and marks key item unknown',
      () async {
        final result = await repository.answer('36号道路这棵树怎么过？', _context);
        expect(result.status, AskTitoDexStatus.answered);
        expect(result.answer, contains('杰尼龟喷壶'));
        expect(result.answer, contains('已取得标准徽章'));
        expect(result.unknowns, contains('当前解析器无法确认是否已完成／取得杰尼龟喷壶'));
      },
    );

    test(
      'works for synonyms, absent badge and direct key-item questions',
      () async {
        final absentBadge = await repository.answer(
          '挡路的树怎么办',
          _context.copyWith(includeBadges: true),
        );
        final keyItem = await repository.answer('杰尼龟水壶在哪', _context);
        expect(absentBadge.status, AskTitoDexStatus.answered);
        expect(keyItem.status, AskTitoDexStatus.answered);
        expect(keyItem.answer, contains('满金市'));

        final noBadgeContext = AskTitoDexContext(
          game: 'heartgold',
          generation: 4,
          locationLabel: 'Route 36',
          locationId: 'johto-route-36-area',
          badgeIds: const [],
          milestoneIds: const [],
          parserRevision: 2,
        );
        final noBadge = await repository.answer('这棵树怎么过', noBadgeContext);
        expect(noBadge.answer, contains('尚未显示标准徽章'));
      },
    );

    test('wrong game and unknown location cannot borrow HGSS facts', () async {
      const platinum = AskTitoDexContext(
        game: 'platinum',
        generation: 4,
        locationLabel: 'Route 36',
        locationId: 'johto-route-36-area',
        badgeIds: [],
        milestoneIds: [],
        parserRevision: 2,
      );
      final wrongGame = await repository.answer('这棵树怎么过', platinum);
      final unknown = await repository.answer(
        '我现在该做什么',
        _context.copyWith(includeLocation: false),
      );
      expect(wrongGame.status, AskTitoDexStatus.noMatch);
      expect(unknown.status, AskTitoDexStatus.noMatch);
    });

    test(
      'Espeon mechanics miss the local blocker pack and require online lookup',
      () async {
        final result = await repository.answer(
          '魂银里伊布白天怎么进化成太阳伊布？',
          _context.copyWith(includeLocation: false),
        );

        expect(result.status, AskTitoDexStatus.noMatch);
        expect(result.onlineComposed, isFalse);
      },
    );

    test(
      'verified save location cannot answer an unrelated question alone',
      () async {
        final result = await repository.answer('魂银里太阳伊布值不值得培养？', _context);

        expect(result.status, AskTitoDexStatus.noMatch);
        expect(result.answer, isNull);
        expect(result.matchedHintIds, isEmpty);
      },
    );

    test(
      'online resource failure returns the local deterministic result',
      () async {
        await askTitoDexSettings.enableWithConsent();
        final service = AskTitoDexService(
          hints: repository,
          online: _ThrowingOnlineClient(),
        );
        final result = await service.ask(
          '这里完全没有可识别的信息',
          _context.copyWith(includeLocation: false),
        );

        expect(result.status, AskTitoDexStatus.noMatch);
        expect(result.onlineComposed, isFalse);
        expect(result.onlineAttempted, isTrue);
        expect(result.errorCode, 'online_resource_unavailable_fallback');
      },
    );
  });

  testWidgets(
    'loading scene uses the home companion and answer shows the actual online path',
    (tester) async {
      await askTitoDexSettings.enableWithConsent();
      final service = _CompleterService();
      Uri? openedSource;
      final router = GoRouter(
        initialLocation: '/journey/ask',
        routes: [
          GoRoute(
            path: '/journey/ask',
            builder: (_, _) => TitoPageContainer(
              child: AskTitoDexPage(
                journey: _journey,
                edition: GameEdition.hgss.withFlavor('soulsilver'),
                service: service,
                sourceOpener: (uri) async {
                  openedSource = uri;
                  return true;
                },
              ),
            ),
          ),
          GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('在线 4/6'), findsOneWidget);
      expect(find.text('问答 0/50'), findsOneWidget);
      expect(find.text('魂银 · HGSS'), findsOneWidget);
      expect(find.text('Journey Worker'), findsNothing);
      expect(
        find.byKey(const Key('ask-titodex-companion-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ask-titodex-companion-idle')),
        findsOneWidget,
      );
      final statusSurface = tester.widget<AssistantSurface>(
        find.byKey(const Key('ask-titodex-connection-status')),
      );
      expect(statusSurface.borderWidth, 1.5);
      expect(find.byKey(const Key('ask-titodex-save-context')), findsOneWidget);
      expect(
        find.byKey(const Key('ask-titodex-companion-card')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ask-titodex-loading-card')), findsNothing);

      await tester.tap(find.byKey(const Key('ask-titodex-connection-summary')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ask-titodex-connection-dialog')),
        findsOneWidget,
      );
      expect(find.text('Journey Worker'), findsOneWidget);
      expect(find.textContaining('Qwen ·'), findsOneWidget);
      expect(find.textContaining('AI Search ·'), findsOneWidget);
      expect(find.text('百科资料 · 多个限定来源'), findsOneWidget);
      expect(find.text('联网搜索'), findsOneWidget);
      expect(find.text('可用'), findsNWidgets(4));
      expect(find.text('未连接'), findsNWidgets(2));
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('ask-titodex-question')),
        '魂银里伊布白天怎么进化成太阳伊布？',
      );
      await tester.tap(find.byKey(const Key('ask-titodex-submit')));
      await tester.pump();

      expect(find.byKey(const Key('ask-titodex-loading-card')), findsOneWidget);
      expect(find.textContaining('火球鼠'), findsWidgets);
      expect(find.text('正在连接 Journey Assistant'), findsOneWidget);
      expect(
        find.byKey(const Key('ask-titodex-question-bubble')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ask-titodex-generating-answer')),
        findsOneWidget,
      );
      expect(find.text('正在交叉核对资料与联网来源'), findsOneWidget);

      service.addAnswerDelta('白天、');
      await tester.pump();
      expect(
        find.byKey(const Key('ask-titodex-streaming-answer')),
        findsOneWidget,
      );
      expect(find.text('白天、▍'), findsOneWidget);
      service.addAnswerDelta('亲密度较高时升级。');
      await tester.pump();
      expect(find.text('白天、亲密度较高时升级。▍'), findsOneWidget);

      service.complete(
        const AskTitoDexResult(
          status: AskTitoDexStatus.answered,
          answer: '''DeepSeek 原生联网参考（未经 TitoDex 人工审核）：
## 升级习得

**白天、亲密度较高时升级。**

| 等级 | 招式 |
| --- | --- |
| 1 | 看穿 |

来源：
[1] PokeAPI · 路卡利欧：https://pokeapi.co/api/v2/pokemon-species/448/''',
          onlineComposed: true,
          answerMode: AskTitoDexAnswerMode.curatedSourcesQwen,
          modelUsed: true,
          confidence: 'medium',
          sourceKinds: ['pokeapi', 'tavily', 'pokeapi'],
          sources: [
            ProgressionSource(
              title: 'PokeAPI · 路卡利欧',
              url: 'https://pokeapi.co/api/v2/pokemon-species/448/',
              accessedAt: '2026-08-17T00:00:00Z',
            ),
            ProgressionSource(
              title: '重复的 PokeAPI 引用',
              url: 'https://pokeapi.co/api/v2/pokemon-species/448/',
              accessedAt: '2026-08-17T00:00:00Z',
            ),
            ProgressionSource(
              title: '神奇宝贝百科 · 路卡利欧',
              url:
                  'https://wiki.52poke.com/wiki/%E8%B7%AF%E5%8D%A1%E5%88%A9%E6%AC%A7',
              accessedAt: '2026-08-16T00:00:00Z',
            ),
            ProgressionSource(
              title: 'StrategyWiki · Pokémon Scarlet and Violet',
              url:
                  'https://strategywiki.org/wiki/Pok%C3%A9mon_Scarlet_and_Violet',
              accessedAt: '2026-08-15T00:00:00Z',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppZh.askTitoDexRouteCuratedQwen), findsOneWidget);
      expect(find.text(AppZh.askTitoDexTraceModel), findsOneWidget);
      expect(find.text('检索 2 路'), findsOneWidget);
      expect(find.text('已核验 · 参考 3 个来源'), findsOneWidget);
      expect(find.text('参考 3 个来源'), findsNothing);
      expect(find.text('升级习得'), findsOneWidget);
      expect(find.text('## 升级习得'), findsNothing);
      expect(find.text('等级'), findsOneWidget);
      expect(find.text('招式'), findsOneWidget);
      expect(find.text('看穿'), findsOneWidget);
      expect(find.text('来源：'), findsNothing);
      expect(find.textContaining('https://pokeapi.co/'), findsNothing);
      expect(find.textContaining('DeepSeek 原生联网参考'), findsNothing);
      expect(find.text('PokeAPI · 路卡利欧'), findsNothing);
      expect(find.text('神奇宝贝百科 · 路卡利欧'), findsNothing);
      expect(find.byKey(const Key('ask-titodex-answer-card')), findsOneWidget);
      expect(find.byIcon(Icons.fact_check_outlined), findsNothing);
      expect(find.text('在线 4/6'), findsOneWidget);
      expect(find.text('问答 1/50'), findsOneWidget);
      expect(find.text('魂银 · HGSS'), findsOneWidget);
      expect(find.byKey(const Key('ask-titodex-loading-card')), findsNothing);
      expect(
        find.byKey(const Key('ask-titodex-generating-answer')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('ask-titodex-companion-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ask-titodex-companion-idle')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('ask-titodex-source-summary')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ask-titodex-source-sheet')), findsOneWidget);
      expect(find.text('回答引用 · 3'), findsOneWidget);
      expect(find.text('PokeAPI'), findsOneWidget);
      expect(find.text('Tavily'), findsOneWidget);
      expect(find.text('PokeAPI · 路卡利欧'), findsOneWidget);
      expect(find.text('神奇宝贝百科 · 路卡利欧'), findsOneWidget);
      expect(find.text('重复的 PokeAPI 引用'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('ask-titodex-source-0')));
      await tester.pump();
      expect(
        openedSource,
        Uri.parse('https://pokeapi.co/api/v2/pokemon-species/448/'),
      );
    },
  );

  testWidgets('reduced motion keeps loading and answer transitions immediate', (
    tester,
  ) async {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await askTitoDexSettings.enableWithConsent();
    final service = _CompleterService();
    final router = GoRouter(
      initialLocation: '/journey/ask',
      routes: [
        GoRoute(
          path: '/journey/ask',
          builder: (_, _) => TitoPageContainer(
            child: AskTitoDexPage(
              journey: _journey,
              edition: GameEdition.hgss.withFlavor('soulsilver'),
              service: service,
            ),
          ),
        ),
        GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('ask-titodex-question')),
      '关闭动画后也要回答',
    );
    await tester.tap(find.byKey(const Key('ask-titodex-submit')));
    await tester.pump();

    expect(
      find.byKey(const Key('ask-titodex-generating-answer')),
      findsOneWidget,
    );
    expect(
      tester
          .widgetList<Shimmer>(find.byType(Shimmer))
          .every((shimmer) => !shimmer.enabled),
      isTrue,
    );

    service.complete(
      const AskTitoDexResult(
        status: AskTitoDexStatus.answered,
        answer: '回答会直接完整显示。',
        confidence: 'medium',
        sources: [
          ProgressionSource(
            title: '测试引用',
            url: 'https://example.com/pokemon',
            accessedAt: '2026-08-21T00:00:00Z',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('回答会直接完整显示。'), findsOneWidget);
    expect(find.text('已核验 · 参考 1 个来源'), findsOneWidget);
  });

  testWidgets('newest question and completed answer stay in view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await askTitoDexSettings.enableWithConsent();
    final service = _CompleterService();
    final historyStore = _MemoryHistoryStore(
      List.generate(
        5,
        (index) => AskTitoDexHistoryEntry(
          game: 'soulsilver',
          question: '之前的问题 ${index + 1}',
          result: AskTitoDexResult(
            status: AskTitoDexStatus.answered,
            answer: '这是之前回答 ${index + 1}，用来确保对话区域可以独立滚动。',
          ),
          createdAt: DateTime.utc(2026, 8, 16, 0, index),
        ),
      ),
    );
    final router = GoRouter(
      initialLocation: '/journey/ask',
      routes: [
        GoRoute(
          path: '/journey/ask',
          builder: (_, _) => TitoPageContainer(
            child: AskTitoDexPage(
              journey: _journey,
              edition: GameEdition.hgss.withFlavor('soulsilver'),
              service: service,
              historyStore: historyStore,
            ),
          ),
        ),
        GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    ScrollPosition answerPosition() => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const Key('ask-titodex-answer-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;

    expect(answerPosition().maxScrollExtent, greaterThan(0));
    answerPosition().jumpTo(0);
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('ask-titodex-question')),
      '最新的问题',
    );
    await tester.tap(find.byKey(const Key('ask-titodex-submit')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    expect(answerPosition().extentAfter, lessThanOrEqualTo(1));

    service.complete(
      const AskTitoDexResult(
        status: AskTitoDexStatus.answered,
        answer: '这是最新的回答，完成后也应该自动停留在最下面。',
        onlineComposed: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('这是最新的回答，完成后也应该自动停留在最下面。'), findsOneWidget);
    expect(answerPosition().extentAfter, lessThanOrEqualTo(1));
  });

  testWidgets('compact connection summary expands grouped provider details', (
    tester,
  ) async {
    await askTitoDexSettings.acknowledgeNotice();
    final router = GoRouter(
      initialLocation: '/journey/ask',
      routes: [
        GoRoute(
          path: '/journey/ask',
          builder: (_, _) => TitoPageContainer(
            child: AskTitoDexPage(
              journey: _journey,
              edition: GameEdition.hgss.withFlavor('soulsilver'),
              service: _CompleterService(webSearchEnabled: true),
            ),
          ),
        ),
        GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('在线 5/6'), findsOneWidget);
    expect(find.text('问答 0/50'), findsOneWidget);
    expect(find.text('魂银 · HGSS'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ask-titodex-connection-summary')));
    await tester.pumpAndSettle();
    expect(find.text('联网 · Tavily'), findsOneWidget);
    expect(find.text('可用'), findsNWidgets(5));
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ask-titodex-history-summary')));
    await tester.pumpAndSettle();
    expect(find.text('问答记录 · 0/50'), findsOneWidget);
    expect(find.text('还没有问答记录'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('ask-titodex-compact-history')),
          )
          .onPressed,
      isNull,
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ask-titodex-edition-summary')));
    await tester.pumpAndSettle();
    expect(find.text('选择游戏版本'), findsOneWidget);
  });

  testWidgets('manual Violet context never displays HGSS save badges', (
    tester,
  ) async {
    await askTitoDexSettings.acknowledgeNotice();
    final router = GoRouter(
      initialLocation: '/journey/ask',
      routes: [
        GoRoute(
          path: '/journey/ask',
          builder: (_, _) => TitoPageContainer(
            child: AskTitoDexPage(
              journey: _journey,
              edition: gameEditionFromSlug('sv')!.withFlavor('violet'),
              service: _FakeService(const []),
            ),
          ),
        ),
        GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.textContaining('紫 · SV'), findsOneWidget);
    expect(find.byKey(const Key('ask-titodex-save-context')), findsNothing);
    expect(find.text(AppZh.askTitoDexBadgeContext(3)), findsNothing);
    expect(find.byKey(const Key('ask-titodex-location-context')), findsNothing);
    expect(find.byKey(const Key('ask-titodex-badge-context')), findsNothing);
  });

  testWidgets('late context result cannot overwrite a newer selected game', (
    tester,
  ) async {
    await askTitoDexSettings.acknowledgeNotice();
    final service = _DelayedContextService();
    var selected = GameEdition.hgss.withFlavor('soulsilver');
    late void Function(GameEdition edition) changeEdition;

    final router = GoRouter(
      initialLocation: '/journey/ask',
      routes: [
        GoRoute(
          path: '/journey/ask',
          builder: (_, _) => StatefulBuilder(
            builder: (context, setState) {
              changeEdition = (edition) => setState(() => selected = edition);
              return TitoPageContainer(
                child: AskTitoDexPage(
                  journey: _journey,
                  edition: selected,
                  service: service,
                ),
              );
            },
          ),
        ),
        GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    expect(service.contextRequests, hasLength(1));

    changeEdition(gameEditionFromSlug('sv')!.withFlavor('violet'));
    await tester.pump();
    expect(service.contextRequests, hasLength(2));

    service.completeContext(1);
    await tester.pump();
    service.completeContext(0);
    await tester.pumpAndSettle();

    expect(find.text('紫 · SV'), findsOneWidget);
    expect(find.byKey(const Key('ask-titodex-save-context')), findsNothing);
    expect(find.byKey(const Key('ask-titodex-location-context')), findsNothing);
    expect(find.byKey(const Key('ask-titodex-badge-context')), findsNothing);
  });

  testWidgets('entity deep links keep ball and sparkle ActionChip icons', (
    tester,
  ) async {
    await askTitoDexSettings.acknowledgeNotice();
    final historyStore = _MemoryHistoryStore([
      AskTitoDexHistoryEntry(
        game: 'soulsilver',
        question: '利欧路能学电光一闪吗？',
        result: const AskTitoDexResult(
          status: AskTitoDexStatus.answered,
          answer: '可以继续查看对应图鉴与招式资料。',
        ),
        createdAt: DateTime.utc(2026, 8, 21, 8),
      ),
    ]);
    final router = GoRouter(
      initialLocation: '/journey/ask',
      routes: [
        GoRoute(
          path: '/journey/ask',
          builder: (_, _) => TitoPageContainer(
            child: AskTitoDexPage(
              journey: _journey,
              edition: GameEdition.hgss.withFlavor('soulsilver'),
              service: _FakeService(const []),
              historyStore: historyStore,
              entityResolver: const _FixedEntityResolver(),
            ),
          ),
        ),
        GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ask-titodex-entity-links')), findsOneWidget);
    expect(find.byType(ActionChip), findsNWidgets(2));
    expect(find.byIcon(Icons.catching_pokemon_rounded), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
  });

  testWidgets(
    'journey entry is hidden by default and visible only when enabled',
    (tester) async {
      Future<void> pump(bool enabled) async {
        final router = GoRouter(
          initialLocation: '/journey',
          routes: [
            GoRoute(
              path: '/journey',
              builder: (_, _) => TitoPageContainer(
                child: JourneyPage(
                  journey: _journey,
                  askTitoDexEnabled: enabled,
                  onAskTitoDex: () {},
                  onManageJourneyPacks: () {},
                  assistantFuture: Future.value(_snapshot),
                ),
              ),
            ),
            GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
          ],
        );
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pump();
        router.dispose();
      }

      await pump(false);
      expect(find.byKey(const Key('ask-titodex-entry')), findsNothing);
      expect(find.byKey(const Key('journey-pack-manager-entry')), findsNothing);
      await pump(true);
      await tester.scrollUntilVisible(
        find.byKey(const Key('ask-titodex-entry')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('ask-titodex-entry')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(
          const Key('journey-pack-manager-entry'),
          skipOffstage: false,
        ),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const Key('journey-pack-manager-entry')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'small-screen clarification and timeout retry remain recoverable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await askTitoDexSettings.acknowledgeNotice();
      final service = _FakeService([
        const AskTitoDexResult(
          status: AskTitoDexStatus.needsClarification,
          followUp: '请补充你所在地点。',
        ),
        const AskTitoDexResult(
          status: AskTitoDexStatus.failed,
          errorCode: 'upstream_timeout',
        ),
        const AskTitoDexResult(
          status: AskTitoDexStatus.answered,
          answer: '已恢复并返回审核事实。',
          onlineComposed: true,
        ),
      ]);
      final router = GoRouter(
        initialLocation: '/journey/ask',
        routes: [
          GoRoute(
            path: '/journey/ask',
            builder: (_, _) => TitoPageContainer(
              child: AskTitoDexPage(
                journey: _journey,
                edition: GameEdition.hgss.withFlavor('soulsilver'),
                service: service,
              ),
            ),
          ),
          GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final composerTop = tester.getTopLeft(
        find.byKey(const Key('ask-titodex-composer')),
      );
      expect(
        tester.getBottomRight(find.byKey(const Key('ask-titodex-composer'))).dy,
        lessThanOrEqualTo(568),
      );
      expect(
        find.byKey(const Key('ask-titodex-answer-scroll')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('ask-titodex-question')),
        '帮帮我',
      );
      await tester.ensureVisible(find.byKey(const Key('ask-titodex-submit')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ask-titodex-submit')));
      await tester.pumpAndSettle();
      expect(find.text('请补充你所在地点。'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('ask-titodex-composer'))).dy,
        composerTop.dy,
      );

      await tester.ensureVisible(find.byKey(const Key('ask-titodex-submit')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ask-titodex-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ask-titodex-retry')), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('ask-titodex-answer-scroll')),
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ask-titodex-retry')));
      await tester.pumpAndSettle();
      expect(find.text('已恢复并返回审核事实。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _FakeService extends AskTitoDexService {
  _FakeService(this.results);

  final List<AskTitoDexResult> results;

  @override
  Future<AskTitoDexContext> buildContext(AskTitoDexContext context) async =>
      context.copyWith(locationId: 'johto-route-36-area');

  @override
  Future<AskTitoDexResult> ask(
    String question,
    AskTitoDexContext context, {
    List<Map<String, String>> history = const [],
    void Function(AskTitoDexProgress progress)? onProgress,
    void Function(String delta)? onAnswerDelta,
  }) async => results.removeAt(0);
}

class _CompleterService extends AskTitoDexService {
  _CompleterService({this.webSearchEnabled = false});

  final bool webSearchEnabled;
  final Completer<AskTitoDexResult> _answer = Completer<AskTitoDexResult>();
  void Function(String delta)? _onAnswerDelta;

  @override
  Future<AskTitoDexWorkerStatus> checkConnection() async =>
      AskTitoDexWorkerStatus(
        availability: AskTitoDexAvailability.online,
        qwenConfigured: true,
        aiSearchEnabled: true,
        curatedSourcesEnabled: true,
        sourceProviders: const ['pokeapi', 'strategywiki', 'wikidata'],
        webSearchEnabled: webSearchEnabled,
        webSearchProviders: webSearchEnabled ? const ['tavily'] : const [],
      );

  @override
  Future<AskTitoDexContext> buildContext(AskTitoDexContext context) async =>
      context.copyWith(locationId: 'johto-route-36-area');

  @override
  Future<AskTitoDexResult> ask(
    String question,
    AskTitoDexContext context, {
    List<Map<String, String>> history = const [],
    void Function(AskTitoDexProgress progress)? onProgress,
    void Function(String delta)? onAnswerDelta,
  }) {
    _onAnswerDelta = onAnswerDelta;
    onProgress?.call(AskTitoDexProgress.checkingLocal);
    onProgress?.call(AskTitoDexProgress.contactingWorker);
    return _answer.future;
  }

  void complete(AskTitoDexResult result) => _answer.complete(result);

  void addAnswerDelta(String delta) => _onAnswerDelta?.call(delta);
}

class _FixedEntityResolver implements AskTitoDexEntityResolver {
  const _FixedEntityResolver();

  @override
  Future<List<AskTitoDexEntityLink>> resolve({
    required String question,
    required String answer,
  }) async => const [
    AskTitoDexEntityLink(
      kind: AskTitoDexEntityKind.pokemon,
      id: 447,
      nameZh: '利欧路',
      nameEn: 'Riolu',
      route: '/dex/447',
    ),
    AskTitoDexEntityLink(
      kind: AskTitoDexEntityKind.move,
      id: 98,
      nameZh: '电光一闪',
      nameEn: 'Quick Attack',
      route: '/dex/moves?q=%E7%94%B5%E5%85%89%E4%B8%80%E9%97%AA',
    ),
  ];
}

class _DelayedContextService extends AskTitoDexService {
  final List<(AskTitoDexContext, Completer<AskTitoDexContext>)>
  contextRequests = [];

  @override
  Future<AskTitoDexContext> buildContext(AskTitoDexContext context) {
    final completer = Completer<AskTitoDexContext>();
    contextRequests.add((context, completer));
    return completer.future;
  }

  void completeContext(int index) {
    final request = contextRequests[index];
    request.$2.complete(request.$1);
  }
}

class _MemoryHistoryStore implements AskTitoDexHistoryStore {
  _MemoryHistoryStore(List<AskTitoDexHistoryEntry> entries)
    : _entries = List.of(entries);

  List<AskTitoDexHistoryEntry> _entries;

  @override
  Future<List<AskTitoDexHistoryEntry>> load() async =>
      List.unmodifiable(_entries);

  @override
  Future<List<AskTitoDexHistoryEntry>> append(
    AskTitoDexHistoryEntry entry,
  ) async {
    _entries = [..._entries, entry];
    if (_entries.length > askTitoDexHistoryLimit) {
      _entries = _entries.sublist(_entries.length - askTitoDexHistoryLimit);
    }
    return List.unmodifiable(_entries);
  }

  @override
  Future<List<AskTitoDexHistoryEntry>> compact({int keep = 10}) async {
    if (_entries.length > keep) {
      _entries = _entries.sublist(_entries.length - keep);
    }
    return List.unmodifiable(_entries);
  }

  @override
  Future<void> clear() async => _entries = [];
}

class _ThrowingOnlineClient implements AskTitoDexOnlineClient {
  @override
  Future<AskTitoDexWorkerStatus> checkStatus() async =>
      const AskTitoDexWorkerStatus.unavailable('resource_unavailable');

  @override
  Future<AskTitoDexResult> ask(
    String question,
    AskTitoDexContext context, {
    List<Map<String, String>> history = const [],
  }) async {
    throw const AskTitoDexOnlineException('resource_unavailable');
  }
}

const _journey = CurrentJourney(
  game: 'SoulSilver',
  trainerName: 'Tito',
  location: 'Route 36',
  badges: 3,
  maxBadges: 16,
  playTime: '18:42',
  party: [PartyMember(species: 'Quilava', nickname: 'PrivateName')],
  timeline: [],
  companion: 'Cyndaquil',
  saveTrainerId: 12345,
  saveTrainerSecretId: 54321,
  saveDexHash: 'private-save-hash',
  verifiedBadgeIds: ['zephyr_badge', 'hive_badge', 'plain_badge'],
);

const _context = AskTitoDexContext(
  game: 'soulsilver',
  generation: 4,
  locationLabel: 'Route 36',
  locationId: 'johto-route-36-area',
  badgeIds: ['zephyr_badge', 'hive_badge', 'plain_badge'],
  milestoneIds: [],
  parserRevision: 2,
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

class _CanonicalProgressionDataSource implements ProgressionHintDataSource {
  const _CanonicalProgressionDataSource();

  @override
  Future<String?> loadJson() =>
      File('../data/journey/progression_hints.json').readAsString();
}
