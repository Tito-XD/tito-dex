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
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/ask_titodex_page.dart';
import 'package:titodex/widgets/ask_answer_motion_title.dart';
import 'package:titodex/widgets/tito_page_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    askTitoDexSettings.resetForTest();
    await askTitoDexSettings.load();
    await askTitoDexSettings.enableWithConsent();
  });

  testWidgets(
    'one answer title keeps its theme through stream updates and catches after the body is visible',
    (tester) async {
      final service = _MotionService();
      await _mount(tester, service);
      await _submit(tester, '电光一闪是什么招式？');
      final title = find.byKey(_titleKey);
      final titleState = tester.state(title);
      final theme = tester.widget<AskAnswerMotionTitle>(title).theme;
      expect(theme.topic, 'moves');
      expect(tester.getSize(title).height, 18);

      // Let the phase transition end before new semantic text arrives.
      await tester.pump(const Duration(seconds: 2));
      expect(_paintInside(title), findsNothing);
      const initial = AskTitoDexAnswerBlock(
        id: 'summary',
        kind: AskTitoDexAnswerBlockKind.summary,
        text: '这是先制招式。',
      );
      await _finishAsync(tester, service.emit(initial));
      expect(tester.state(title), same(titleState));
      expect(tester.widget<AskAnswerMotionTitle>(title).theme, same(theme));
      expect(_paintInside(title), findsNothing);

      const answer = '这是先制招式。其威力为40。';
      const extended = AskTitoDexAnswerBlock(
        id: 'summary',
        kind: AskTitoDexAnswerBlockKind.summary,
        text: answer,
      );
      await _finishAsync(tester, service.emit(extended));
      expect(tester.widget<AskAnswerMotionTitle>(title).theme, same(theme));
      expect(_paintInside(title), findsNothing);
      expect(find.text(answer, findRichText: true), findsOneWidget);

      service.complete(
        const AskTitoDexResult(
          status: AskTitoDexStatus.answered,
          answer: answer,
          answerBlocks: [extended],
        ),
      );
      await _until(tester, () => _title(tester).outcome != null);
      expect(tester.state(title), same(titleState));
      expect(_title(tester).theme, same(theme));
      expect(_title(tester).outcome, AskMotionOutcome.caught);
      expect(find.byKey(const ValueKey('ask-motion-caught')), findsOneWidget);
      expect(find.text(answer, findRichText: true), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('ask-motion-caught')), findsOneWidget);
      expect(find.text(answer, findRichText: true), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ask-motion-caught')), findsNothing);
      expect(tester.getSize(title).height, 18);
    },
  );

  testWidgets(
    'no match escapes while failed and clarification results remain neutral',
    (tester) async {
      for (final status in [
        AskTitoDexStatus.noMatch,
        AskTitoDexStatus.failed,
        AskTitoDexStatus.needsClarification,
      ]) {
        final service = _MotionService();
        await _mount(tester, service);
        await _submit(tester, '蓝色的小狗在哪里？');
        final state = tester.state(find.byKey(_titleKey));
        service.complete(
          AskTitoDexResult(
            status: status,
            followUp: '请补充具体对象。',
            errorCode: status == AskTitoDexStatus.failed
                ? 'network_error'
                : null,
          ),
        );
        await _until(tester, () => _title(tester).outcome != null);
        expect(tester.state(find.byKey(_titleKey)), same(state));
        final escaped = status == AskTitoDexStatus.noMatch;
        expect(
          _title(tester).outcome,
          escaped ? AskMotionOutcome.escaped : AskMotionOutcome.neutral,
        );
        expect(
          find.byKey(const ValueKey('ask-motion-escaped')),
          escaped ? findsOneWidget : findsNothing,
        );
        expect(find.byKey(const ValueKey('ask-motion-caught')), findsNothing);
        if (!escaped) expect(_paintInside(find.byKey(_titleKey)), findsNothing);
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'idle words rest between changes and stop when hidden or disposed',
    (tester) async {
      await _mount(tester, _MotionService());
      final idle = find.byKey(const Key('ask-titodex-idle-topic'));
      final prefix = find.text(AppZh.askTitoDexIdlePrefix);
      final suffix = find.text(AppZh.askTitoDexIdleSuffix);
      final first = tester.widget<AskAnswerMotionTitle>(idle).text;
      expect(first, AppZh.askTitoDexIdleTopics.first);
      expect(_paintInside(idle), findsNothing);
      expect(find.text(AppZh.askTitoDexIdlePrompt), findsOneWidget);
      final prefixPosition = tester.getTopLeft(prefix);
      final suffixPosition = tester.getTopLeft(suffix);

      await tester.pump(const Duration(seconds: 2));
      expect(tester.widget<AskAnswerMotionTitle>(idle).text, first);
      expect(_paintInside(idle), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 12));
      expect(tester.widget<AskAnswerMotionTitle>(idle).text, first);
      expect(_paintInside(idle), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 6));
      expect(
        tester.widget<AskAnswerMotionTitle>(idle).text,
        AppZh.askTitoDexIdleTopics[1],
      );
      expect(tester.getTopLeft(prefix), prefixPosition);
      expect(tester.getTopLeft(suffix), suffixPosition);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion keeps idle and real answer outcomes immediate', (
    tester,
  ) async {
    final dispatcher = tester.binding.platformDispatcher;
    dispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(dispatcher.clearAccessibilityFeaturesTestValue);
    final service = _MotionService();
    await _mount(tester, service);
    final idle = find.byKey(const Key('ask-titodex-idle-topic'));
    await tester.pump(const Duration(seconds: 20));
    expect(
      tester.widget<AskAnswerMotionTitle>(idle).text,
      AppZh.askTitoDexIdleTopics.first,
    );
    expect(_paintInside(idle), findsNothing);
    await _submit(tester, '橙橙果有什么用？');
    expect(_paintInside(find.byKey(_titleKey)), findsNothing);
    service.complete(
      const AskTitoDexResult(
        status: AskTitoDexStatus.answered,
        answer: '可以回复体力。',
      ),
    );
    await tester.pumpAndSettle();
    expect(_title(tester).outcome, AskMotionOutcome.caught);
    expect(find.text('可以回复体力。', findRichText: true), findsOneWidget);
    expect(_paintInside(find.byKey(_titleKey)), findsNothing);
    expect(find.byKey(const ValueKey('ask-motion-caught')), findsNothing);
  });
}

const _titleKey = Key('ask-titodex-answer-motion-title');

AskAnswerMotionTitle _title(WidgetTester tester) =>
    tester.widget<AskAnswerMotionTitle>(find.byKey(_titleKey));

Finder _paintInside(Finder parent) =>
    find.descendant(of: parent, matching: find.byType(CustomPaint));

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 24));
  }
  expect(done(), isTrue, reason: 'The bounded answer update did not complete.');
}

Future<void> _finishAsync(WidgetTester tester, Future<void> work) async {
  var done = false;
  final tracked = work.then((_) => done = true);
  await _until(tester, () => done);
  await tracked;
}

Future<void> _submit(WidgetTester tester, String question) async {
  await tester.enterText(
    find.byKey(const Key('ask-titodex-question')),
    question,
  );
  await tester.tap(find.byKey(const Key('ask-titodex-submit')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 180));
  await tester.pump();
}

Future<void> _mount(WidgetTester tester, _MotionService service) async {
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

class _MotionService extends AskTitoDexService {
  final _answer = Completer<AskTitoDexResult>();
  AskTitoDexStreamEventCallback? _onStream;

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
    void Function(AskTitoDexProgress)? onProgress,
    AskTitoDexStreamEventCallback? onStreamEvent,
  }) {
    _onStream = onStreamEvent;
    onProgress?.call(AskTitoDexProgress.retrievingSources);
    return _answer.future;
  }

  Future<void> emit(AskTitoDexAnswerBlock block) async {
    await _onStream?.call(AskTitoDexOnlineStreamEvent.answerBlock(block));
  }

  void complete(AskTitoDexResult result) => _answer.complete(result);
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
