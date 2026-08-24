import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/game/game_edition.dart';
import 'package:titodex/features/journey/ask_titodex_answer_blocks.dart';
import 'package:titodex/features/journey/ask_titodex_entity_links.dart';
import 'package:titodex/features/journey/ask_titodex_history.dart';
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

    expect(find.byKey(const Key('ask-titodex-streaming-answer')), findsOne);
    final firstFrame = _visibleCursorText(tester);
    expect(firstFrame, startsWith('利'));
    expect(firstFrame, endsWith('▍'));
    expect(firstFrame.length, lessThan('利欧路可以在南第4区遇到。▍'.length));
    final liveAnswerSemantics = tester.widget<Semantics>(
      find.byKey(const Key('ask-titodex-live-answer-semantics')),
    );
    expect(liveAnswerSemantics.properties.liveRegion, isTrue);
    expect(
      liveAnswerSemantics.properties.label,
      contains(firstFrame.replaceAll('▍', '')),
    );
    expect(pacingFinished, isFalse);
    await tester.pump(const Duration(milliseconds: 48));
    await tester.pump();
    final secondFrame = _visibleCursorText(tester);
    expect(secondFrame.length, greaterThan(firstFrame.length));
    expect(secondFrame, endsWith('▍'));
    expect(secondFrame.length, lessThan('利欧路可以在南第4区遇到。▍'.length));
    await _pumpUntil(tester, () => pacingFinished);
    await pacing;
    expect(pacingFinished, isTrue);
    expect(_visibleCursorText(tester), '利欧路可以在南第4区遇到。▍');

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

    var revealFinished = false;
    final reveal = service
        .emitBlock(
          const AskTitoDexAnswerBlock(
            id: 'stale-summary',
            turnId: 'turn-reset-ui',
            kind: AskTitoDexAnswerBlockKind.summary,
            text: '不完整的旧语义内容。',
            isComplete: false,
          ),
        )
        .then((_) => revealFinished = true);
    await tester.pump();
    await _pumpUntil(tester, () => revealFinished);
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

  testWidgets(
    'invalid streamed content is cleared before local fallback reveal',
    (tester) async {
      const invalidText = '错误的悖谬宝可梦定义。';
      const fallbackText = '本地核验回答。';
      final service = _SemanticStreamService();
      await _pumpAskPage(tester, service);
      await tester.enterText(
        find.byKey(const Key('ask-titodex-question')),
        '利欧路在哪里抓？',
      );
      await tester.tap(find.byKey(const Key('ask-titodex-submit')));
      await tester.pump();

      var invalidRevealFinished = false;
      final invalidReveal = service
          .emitBlock(
            const AskTitoDexAnswerBlock(
              id: 'invalid-remote',
              kind: AskTitoDexAnswerBlockKind.summary,
              text: invalidText,
            ),
          )
          .then((_) => invalidRevealFinished = true);
      await tester.pump();
      await _pumpUntil(tester, () => invalidRevealFinished);
      await invalidReveal;
      expect(find.text(invalidText, findRichText: true), findsOne);

      service.complete(
        const AskTitoDexResult(
          status: AskTitoDexStatus.answered,
          answer: fallbackText,
          errorCode: 'invalid_ai_contract_fallback',
        ),
      );
      await tester.pump();

      expect(find.text(invalidText, findRichText: true), findsNothing);
      final fallbackFirstFrame = _visibleCursorText(tester);
      expect(fallbackFirstFrame, startsWith(fallbackText.substring(0, 1)));
      expect(fallbackFirstFrame, endsWith('▍'));

      await _pumpUntil(
        tester,
        () => find
            .byKey(const Key('ask-titodex-completion-check'))
            .evaluate()
            .isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(find.text(invalidText, findRichText: true), findsNothing);
      expect(find.text(fallbackText, findRichText: true), findsOne);
    },
  );

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
      var firstRevealFinished = false;
      final firstReveal = service
          .emitBlock(
            AskTitoDexAnswerBlock(
              id: 'route',
              turnId: 'turn-scroll-race',
              kind: AskTitoDexAnswerBlockKind.paragraph,
              text: firstText,
              isComplete: false,
            ),
          )
          .then((_) => firstRevealFinished = true);
      await tester.pump();
      await _pumpUntil(tester, () => firstRevealFinished);
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
      ScrollUpdateNotification(
        metrics: position,
        context: tester.element(
          find.byKey(const Key('ask-titodex-answer-scroll')),
        ),
        dragDetails: DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: Offset(0, 180),
        ),
        scrollDelta: 180,
      ).dispatch(
        tester.element(find.byKey(const Key('ask-titodex-answer-scroll'))),
      );
      expect(position.extentBefore, greaterThan(72));

      final grownText =
          '$firstText\n\n${List.generate(8, (index) => '新增的第${index + 1}条核验说明。').join('\n\n')}';
      var secondRevealFinished = false;
      final secondReveal = service
          .emitBlock(
            AskTitoDexAnswerBlock(
              id: 'route',
              turnId: 'turn-scroll-race',
              kind: AskTitoDexAnswerBlockKind.paragraph,
              text: grownText,
              isComplete: false,
            ),
          )
          .then((_) => secondRevealFinished = true);
      await tester.pump();
      await _pumpUntil(tester, () => secondRevealFinished);
      await secondReveal;

      expect(position.extentBefore, greaterThan(72));
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
    'local answer synthesizes blocks, settles in place, then reveals evidence and chips',
    (tester) async {
      const answer = '本地核验回答会逐字显示，并把光标留在真正的末尾。';
      const resolver = _FixedEntityResolver([
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
          route: '/dex/moves?q=quick-attack',
        ),
      ]);
      final service = _SemanticStreamService();
      await _pumpAskPage(tester, service, entityResolver: resolver);
      await tester.enterText(
        find.byKey(const Key('ask-titodex-question')),
        '本地资料能回答什么？',
      );
      await tester.tap(find.byKey(const Key('ask-titodex-submit')));
      await tester.pump();
      final activeSurface = tester.element(
        find.byKey(const Key('ask-titodex-active-answer-surface')),
      );

      service.complete(
        const AskTitoDexResult(
          status: AskTitoDexStatus.answered,
          answer: answer,
          confidence: 'high',
          sources: [
            ProgressionSource(
              title: 'TitoDex 本地审核资料',
              url: 'https://example.com/titodex-local',
              accessedAt: '2026-08-24T00:00:00Z',
            ),
          ],
        ),
      );
      await tester.pump();

      final partial = _visibleCursorText(tester);
      expect(partial, startsWith(answer.substring(0, 1)));
      expect(partial, endsWith('▍'));
      expect(partial.length, lessThan(answer.length + 1));
      expect(find.byKey(const ValueKey('ask-answer-block-local-01')), findsOne);

      await _pumpUntil(
        tester,
        () => find
            .byKey(const Key('ask-titodex-completion-check'))
            .evaluate()
            .isNotEmpty,
      );
      expect(
        tester.element(
          find.byKey(const Key('ask-titodex-active-answer-surface')),
        ),
        same(activeSurface),
      );
      final settling = tester.widget<Transform>(
        find.byKey(const Key('ask-titodex-answer-settle')),
      );
      expect(settling.transform.getTranslation().y, greaterThan(0));

      await tester.pump();
      final evidence = find.byKey(const Key('ask-titodex-evidence-reveal'));
      final evidenceSize = tester.widget<SizeTransition>(
        find.descendant(of: evidence, matching: find.byType(SizeTransition)),
      );
      expect(evidenceSize.sizeFactor.value, 0);
      final firstChip = find.byKey(
        const ValueKey('ask-entity-reveal-pokemon-447'),
      );
      final secondChip = find.byKey(
        const ValueKey('ask-entity-reveal-move-98'),
      );
      expect(firstChip, findsOne);
      expect(secondChip, findsOne);
      expect(_chipOpacity(tester, firstChip), 0);
      expect(_chipOpacity(tester, secondChip), 0);

      await tester.pump(const Duration(milliseconds: 170));
      await tester.pump(const Duration(milliseconds: 60));
      expect(evidenceSize.sizeFactor.value, greaterThan(0));
      expect(_chipOpacity(tester, firstChip), 0);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 35));
      expect(_chipOpacity(tester, firstChip), greaterThan(0));
      expect(_chipOpacity(tester, secondChip), 0);

      await tester.pumpAndSettle();
      expect(find.text(answer, findRichText: true), findsOne);
      expect(find.text('$answer▍', findRichText: true), findsNothing);
    },
  );

  testWidgets(
    'first frame defers heavy work and 50 long turns stay lazy at newest',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = _SemanticStreamService();
      final historyStore = _CountingHistoryStore(
        List.generate(
          50,
          (index) => AskTitoDexHistoryEntry(
            game: 'soulsilver',
            question: '历史问题 ${index + 1}',
            result: AskTitoDexResult(
              status: AskTitoDexStatus.answered,
              answer:
                  '历史回答 ${index + 1}。'
                  '${List.filled(20, '这是一段用于验证惰性构建的较长内容。').join()}',
            ),
            createdAt: DateTime.utc(2026, 8, 24, 0, index),
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
      expect(historyStore.loadCalls, 0);
      expect(service.contextBuilds, 0);
      expect(service.connectionChecks, 0);
      expect(find.byKey(const Key('ask-titodex-answer-viewport')), findsOne);

      await tester.pumpAndSettle();
      expect(historyStore.loadCalls, 1);
      expect(service.contextBuilds, 1);
      expect(service.connectionChecks, 1);
      expect(find.textContaining('历史回答 50'), findsOne);

      final builtAnswers = find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> && key.value.startsWith('ask-answer-');
      });
      expect(builtAnswers.evaluate().length, greaterThan(0));
      expect(builtAnswers.evaluate().length, lessThan(50));
      final scrollable = find
          .descendant(
            of: find.byKey(const Key('ask-titodex-answer-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));
      expect(position.extentBefore, lessThanOrEqualTo(1));
    },
  );

  testWidgets('reduced motion still starts deferred initialization', (
    tester,
  ) async {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final service = _SemanticStreamService();
    final historyStore = _CountingHistoryStore();
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
    expect(historyStore.loadCalls, 0);
    expect(service.contextBuilds, 0);
    await tester.pumpAndSettle();
    expect(historyStore.loadCalls, 1);
    expect(service.contextBuilds, 1);
    expect(service.connectionChecks, 1);
  });

  testWidgets('a new question does not replay the previous answer', (
    tester,
  ) async {
    const firstAnswer = '第一条回答完成后应该保持静止。';
    final service = _SemanticStreamService();
    await _pumpAskPage(tester, service);
    await tester.enterText(
      find.byKey(const Key('ask-titodex-question')),
      '第一问',
    );
    await tester.tap(find.byKey(const Key('ask-titodex-submit')));
    await tester.pump();
    service.complete(
      const AskTitoDexResult(
        status: AskTitoDexStatus.answered,
        answer: firstAnswer,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('ask-titodex-question')),
      '第二问',
    );
    await tester.tap(find.byKey(const Key('ask-titodex-submit')));
    await tester.pump();

    expect(find.text(firstAnswer, findRichText: true), findsOne);
    expect(find.text('$firstAnswer▍', findRichText: true), findsNothing);
    expect(find.byKey(const Key('ask-titodex-generating-answer')), findsOne);
    final staticEvidence = tester.widget<SizeTransition>(
      find
          .descendant(
            of: find.byKey(const Key('ask-titodex-evidence-reveal')),
            matching: find.byType(SizeTransition),
          )
          .first,
    );
    expect(staticEvidence.sizeFactor.value, 1);

    service.complete(
      const AskTitoDexResult(
        status: AskTitoDexStatus.noMatch,
        followUp: '第二问测试结束。',
      ),
    );
    await tester.pumpAndSettle();
  });

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

String _visibleCursorText(WidgetTester tester) {
  final values = <String>[
    ...tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? ''),
    ...tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? ''),
    ...tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText()),
  ].where((value) => value.contains('▍')).toList(growable: false);
  expect(values, isNotEmpty);
  return values.last;
}

double _chipOpacity(WidgetTester tester, Finder chip) {
  final fade = tester.widget<FadeTransition>(
    find.descendant(of: chip, matching: find.byType(FadeTransition)).first,
  );
  return fade.opacity.value;
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration step = const Duration(milliseconds: 24),
  int maxPumps = 80,
}) async {
  for (var index = 0; index < maxPumps && !condition(); index += 1) {
    await tester.pump(step);
  }
  expect(condition(), isTrue, reason: 'bounded async UI work did not finish');
}

Future<void> _pumpAskPage(
  WidgetTester tester,
  _SemanticStreamService service, {
  AskTitoDexHistoryStore? historyStore,
  AskTitoDexEntityResolver? entityResolver,
}) async {
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
            historyStore: historyStore,
            entityResolver: entityResolver,
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
  int connectionChecks = 0;
  int contextBuilds = 0;

  @override
  Future<AskTitoDexWorkerStatus> checkConnection() async {
    connectionChecks += 1;
    return const AskTitoDexWorkerStatus(
      availability: AskTitoDexAvailability.online,
    );
  }

  @override
  Future<AskTitoDexContext> buildContext(AskTitoDexContext context) async {
    contextBuilds += 1;
    return context;
  }

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

class _FixedEntityResolver implements AskTitoDexEntityResolver {
  const _FixedEntityResolver(this.links);

  final List<AskTitoDexEntityLink> links;

  @override
  Future<List<AskTitoDexEntityLink>> resolve({
    required String question,
    required String answer,
  }) async => links;
}

class _CountingHistoryStore implements AskTitoDexHistoryStore {
  _CountingHistoryStore([List<AskTitoDexHistoryEntry> entries = const []])
    : _entries = List.of(entries);

  List<AskTitoDexHistoryEntry> _entries;
  int loadCalls = 0;

  @override
  Future<List<AskTitoDexHistoryEntry>> load() async {
    loadCalls += 1;
    return List.unmodifiable(_entries);
  }

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
  Future<void> clear() async {
    _entries = [];
  }
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
