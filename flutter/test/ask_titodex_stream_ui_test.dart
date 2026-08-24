import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/game/game_edition.dart';
import 'package:titodex/features/journey/ask_titodex_answer_blocks.dart';
import 'package:titodex/features/journey/ask_titodex_service.dart';
import 'package:titodex/features/journey/ask_titodex_settings.dart';
import 'package:titodex/features/journey/progression_hints.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/ask_titodex_page.dart';
import 'package:titodex/widgets/tito_page_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    askTitoDexSettings.resetForTest();
    await askTitoDexSettings.load();
    await askTitoDexSettings.enableWithConsent();
  });

  test('clarification follow-up preserves the original intent and bound', () {
    final original = '${List.filled(225, '蓝').join()}在哪里抓？';
    final question = buildAskTitoDexClarificationQuestion(
      originalQuestion: original,
      candidateLabel: '利欧路',
    );

    expect(question, startsWith('已确认对象是“利欧路”。原问题：'));
    expect(question, contains('在哪里抓？'));
    expect(question, contains('…'));
    expect(question.length, lessThanOrEqualTo(240));
  });

  testWidgets('semantic blocks stream and finish inside the same answer card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _SemanticStreamService();
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
      '紫里哪里可以抓到利欧路？',
    );
    await tester.tap(find.byKey(const Key('ask-titodex-submit')));
    await tester.pump();

    final activeSurface = tester.element(
      find.byKey(const Key('ask-titodex-active-answer-surface')),
    );
    var pacingFinished = false;
    final pacing = service
        .emitBlock(
          const AskTitoDexAnswerBlock(
            id: 'summary',
            turnId: 'turn-ui-test',
            kind: AskTitoDexAnswerBlockKind.summary,
            text: '利欧路可以在南第4区遇到。',
            isComplete: false,
          ),
        )
        .then((_) => pacingFinished = true);
    await tester.pump();

    expect(
      find.byKey(const Key('ask-titodex-streaming-answer')),
      findsOneWidget,
    );
    expect(find.text('利欧路可以在南第4区遇到。▍'), findsOneWidget);
    final liveAnswerSemantics = tester.widget<Semantics>(
      find.byKey(const Key('ask-titodex-live-answer-semantics')),
    );
    expect(liveAnswerSemantics.properties.liveRegion, isTrue);
    expect(liveAnswerSemantics.properties.label, contains('利欧路可以在南第4区遇到。'));
    expect(pacingFinished, isFalse);
    await tester.pump(const Duration(milliseconds: 36));
    await pacing;
    expect(pacingFinished, isTrue);

    const blocks = [
      AskTitoDexAnswerBlock(
        id: 'summary',
        kind: AskTitoDexAnswerBlockKind.summary,
        text: '利欧路可以在南第4区遇到。',
      ),
      AskTitoDexAnswerBlock(
        id: 'tips',
        kind: AskTitoDexAnswerBlockKind.bullets,
        title: '捕捉建议',
        text: '- 白天前往\n- 带上合适的精灵球',
        items: ['白天前往', '带上合适的精灵球'],
      ),
      AskTitoDexAnswerBlock(
        id: 'levels',
        kind: AskTitoDexAnswerBlockKind.table,
        title: '出现信息',
        text: '| 地点 | 等级 |\n| --- | --- |\n| 南第4区 | 18–22 |',
        rows: [
          ['地点', '等级'],
          ['南第4区', '18–22'],
        ],
      ),
      AskTitoDexAnswerBlock(
        id: 'warning',
        kind: AskTitoDexAnswerBlockKind.warning,
        text: '提醒：不同天气下出现率可能变化。',
      ),
    ];
    service.complete(
      const AskTitoDexResult(
        status: AskTitoDexStatus.answered,
        answer: '利欧路可以在南第4区遇到。',
        answerBlocks: blocks,
        onlineComposed: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.element(
        find.byKey(const Key('ask-titodex-active-answer-surface')),
      ),
      same(activeSurface),
    );
    expect(find.byKey(const ValueKey('ask-answer-block-summary')), findsOne);
    expect(find.byKey(const ValueKey('ask-answer-block-tips')), findsOne);
    expect(find.byKey(const ValueKey('ask-answer-block-levels')), findsOne);
    expect(find.byKey(const ValueKey('ask-answer-block-warning')), findsOne);
    expect(find.text('捕捉建议'), findsOneWidget);
    expect(find.text('南第4区'), findsOneWidget);
    expect(find.text('18–22'), findsOneWidget);
    expect(
      find.byKey(const Key('ask-titodex-generating-answer')),
      findsNothing,
    );
  });

  testWidgets('semantic reset clears stale blocks until final result', (
    tester,
  ) async {
    final service = _SemanticStreamService();
    await _pumpAskPage(tester, service);
    await tester.enterText(
      find.byKey(const Key('ask-titodex-question')),
      '测试语义降级。',
    );
    await tester.tap(find.byKey(const Key('ask-titodex-submit')));
    await tester.pump();

    final reveal = service.emitBlock(
      const AskTitoDexAnswerBlock(
        id: 'stale-summary',
        turnId: 'turn-reset-ui',
        kind: AskTitoDexAnswerBlockKind.summary,
        text: '不完整的旧语义内容。',
        isComplete: false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 36));
    await reveal;
    expect(find.text('不完整的旧语义内容。▍'), findsOneWidget);

    await service.emitReset(turnId: 'turn-reset-ui');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('不完整的旧语义内容'), findsNothing);

    service.complete(
      const AskTitoDexResult(
        status: AskTitoDexStatus.answered,
        answer: '最终权威答案。',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('最终权威答案。', findRichText: true), findsOneWidget);
  });

  testWidgets('reduced motion skips semantic reveal pacing', (tester) async {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final service = _SemanticStreamService();
    await _pumpAskPage(tester, service);
    await tester.enterText(
      find.byKey(const Key('ask-titodex-question')),
      '利欧路在哪里？',
    );
    await tester.tap(find.byKey(const Key('ask-titodex-submit')));
    await tester.pump();

    var finished = false;
    final reveal = service
        .emitBlock(
          const AskTitoDexAnswerBlock(
            id: 'summary',
            turnId: 'turn-reduced-motion',
            kind: AskTitoDexAnswerBlockKind.summary,
            text: '立即显示。',
            isComplete: false,
          ),
        )
        .then((_) => finished = true);
    await tester.pump();
    await reveal;

    expect(finished, isTrue);
    expect(find.text('立即显示。▍'), findsOneWidget);
    service.complete(
      const AskTitoDexResult(
        status: AskTitoDexStatus.answered,
        answer: '立即显示。',
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets(
    'semantic growth does not pull the user back after they scroll up',
    (tester) async {
      final service = _SemanticStreamService();
      await _pumpAskPage(tester, service);
      tester.view.physicalSize = const Size(320, 520);
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('ask-titodex-question')),
        '给我一份较长的路线说明。',
      );
      await tester.tap(find.byKey(const Key('ask-titodex-submit')));
      await tester.pump();

      final firstText = List.generate(
        24,
        (index) => '第${index + 1}条已经核验的路线说明。',
      ).join('\n\n');
      final firstReveal = service.emitBlock(
        AskTitoDexAnswerBlock(
          id: 'route',
          turnId: 'turn-scroll-race',
          kind: AskTitoDexAnswerBlockKind.paragraph,
          text: firstText,
          isComplete: false,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 36));
      await firstReveal;
      await tester.pump();

      final scrollable = find
          .descendant(
            of: find.byKey(const Key('ask-titodex-answer-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(72));
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();

      final grownText =
          '$firstText\n\n${List.generate(8, (index) => '新增的第${index + 1}条核验说明。').join('\n\n')}';
      final secondReveal = service.emitBlock(
        AskTitoDexAnswerBlock(
          id: 'route',
          turnId: 'turn-scroll-race',
          kind: AskTitoDexAnswerBlockKind.paragraph,
          text: grownText,
          isComplete: false,
        ),
      );

      position.jumpTo(0);
      ScrollUpdateNotification(
        metrics: position,
        context: tester.element(
          find.byKey(const Key('ask-titodex-answer-scroll')),
        ),
        dragDetails: DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: Offset(0, 180),
        ),
        scrollDelta: -180,
      ).dispatch(
        tester.element(find.byKey(const Key('ask-titodex-answer-scroll'))),
      );
      expect(position.extentAfter, greaterThan(72));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 36));
      await secondReveal;

      expect(position.extentAfter, greaterThan(72));
      service.complete(
        AskTitoDexResult(status: AskTitoDexStatus.answered, answer: grownText),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'canonical text fallback keeps items and rows beyond projections',
    (tester) async {
      final service = _SemanticStreamService();
      await _pumpAskPage(tester, service);
      await tester.enterText(
        find.byKey(const Key('ask-titodex-question')),
        '列出完整路线和等级。',
      );
      await tester.tap(find.byKey(const Key('ask-titodex-submit')));
      await tester.pump();

      final bulletText = List.generate(
        13,
        (index) => '- 第${index + 1}项',
      ).join('\n');
      final tableText = [
        '| 地点 | 等级 |',
        '| --- | --- |',
        ...List.generate(12, (index) => '| 地点${index + 1} | ${index + 10} |'),
      ].join('\n');
      service.complete(
        AskTitoDexResult(
          status: AskTitoDexStatus.answered,
          answer: '$bulletText\n\n$tableText',
          answerBlocks: [
            AskTitoDexAnswerBlock(
              id: 'all-items',
              kind: AskTitoDexAnswerBlockKind.bullets,
              text: bulletText,
            ),
            AskTitoDexAnswerBlock(
              id: 'all-rows',
              kind: AskTitoDexAnswerBlockKind.table,
              text: tableText,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('第13项', findRichText: true), findsOneWidget);
      expect(find.text('地点12'), findsOneWidget);
      expect(find.text('21'), findsOneWidget);
    },
  );

  testWidgets(
    'final and historical clarification chips explicitly continue the question',
    (tester) async {
      final service = _SemanticStreamService();
      await _pumpAskPage(tester, service);
      const original = '蓝黑色的小狗在哪里抓？';
      await tester.enterText(
        find.byKey(const Key('ask-titodex-question')),
        original,
      );
      await tester.tap(find.byKey(const Key('ask-titodex-submit')));
      await tester.pump();
      service.complete(
        const AskTitoDexResult(
          status: AskTitoDexStatus.needsClarification,
          followUp: '你指的是下面哪一只宝可梦？',
          clarificationCandidates: [
            AskTitoDexClarificationCandidate(
              id: 'riolu',
              label: '利欧路',
              kind: 'pokemon',
            ),
            AskTitoDexClarificationCandidate(
              id: 'lucario',
              label: '路卡利欧',
              kind: 'pokemon',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('ask-titodex-clarification-candidates')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('ask-clarification-riolu')));
      await tester.pump();
      expect(service.questions, hasLength(2));
      expect(service.questions.last, '已确认对象是“利欧路”。原问题：$original');
      expect(service.questions.last.length, lessThanOrEqualTo(240));

      service.complete(
        const AskTitoDexResult(
          status: AskTitoDexStatus.noMatch,
          followUp: '请再补充所在的游戏版本。',
        ),
      );
      await tester.pumpAndSettle();

      final historicalChip = find.byKey(
        const ValueKey('ask-clarification-riolu'),
      );
      expect(historicalChip, findsOneWidget);
      await tester.ensureVisible(historicalChip);
      await tester.tap(historicalChip);
      await tester.pump();
      expect(service.questions, hasLength(3));
      expect(service.questions.last, '已确认对象是“利欧路”。原问题：$original');
      service.complete(
        const AskTitoDexResult(
          status: AskTitoDexStatus.noMatch,
          followUp: '测试结束。',
        ),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'an answer from an old edition is discarded after edition changes',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = _SemanticStreamService();
      final edition = ValueNotifier<GameEdition>(
        GameEdition.hgss.withFlavor('soulsilver'),
      );
      addTearDown(edition.dispose);
      final router = GoRouter(
        initialLocation: '/journey/ask',
        routes: [
          GoRoute(
            path: '/journey/ask',
            builder: (_, _) => ValueListenableBuilder<GameEdition>(
              valueListenable: edition,
              builder: (_, value, _) => TitoPageContainer(
                child: AskTitoDexPage(
                  journey: _journey,
                  edition: value,
                  service: service,
                ),
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
        '魂银里去哪抓利欧路？',
      );
      await tester.tap(find.byKey(const Key('ask-titodex-submit')));
      await tester.pump();

      edition.value = gameEditionFromSlug('sv')!.withFlavor('violet');
      await tester.pump();
      service.complete(
        const AskTitoDexResult(
          status: AskTitoDexStatus.answered,
          answer: '这是旧版本请求的回答。',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('这是旧版本请求的回答。'), findsNothing);
      expect(
        find.byKey(const Key('ask-titodex-active-answer-surface')),
        findsNothing,
      );
    },
  );
}

Future<void> _pumpAskPage(
  WidgetTester tester,
  _SemanticStreamService service,
) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
}

class _SemanticStreamService extends AskTitoDexService {
  final List<Completer<AskTitoDexResult>> _answers = [];
  final List<String> questions = [];
  AskTitoDexStreamEventCallback? _onStreamEvent;

  @override
  Future<AskTitoDexWorkerStatus> checkConnection() async =>
      const AskTitoDexWorkerStatus(availability: AskTitoDexAvailability.online);

  @override
  Future<AskTitoDexContext> buildContext(AskTitoDexContext context) async =>
      context;

  @override
  Future<AskTitoDexResult> ask(
    String question,
    AskTitoDexContext context, {
    List<Map<String, String>> history = const [],
    void Function(AskTitoDexProgress progress)? onProgress,
    AskTitoDexStreamEventCallback? onStreamEvent,
  }) {
    questions.add(question);
    _onStreamEvent = onStreamEvent;
    onProgress?.call(AskTitoDexProgress.retrievingSources);
    final answer = Completer<AskTitoDexResult>();
    _answers.add(answer);
    return answer.future;
  }

  Future<void> emitBlock(AskTitoDexAnswerBlock block) async {
    await _onStreamEvent?.call(AskTitoDexOnlineStreamEvent.answerBlock(block));
  }

  Future<void> emitReset({String? turnId}) async {
    await _onStreamEvent?.call(
      AskTitoDexOnlineStreamEvent.semanticReset(turnId: turnId),
    );
  }

  void complete(AskTitoDexResult result) =>
      _answers.removeAt(0).complete(result);
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
