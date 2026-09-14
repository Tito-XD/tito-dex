import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/journey/ask_titodex_answer_blocks.dart';
import 'package:titodex/features/journey/ask_titodex_reveal_controller.dart';
import 'package:titodex/features/journey/ask_titodex_service.dart';
import 'package:titodex/features/journey/progression_hints.dart';

void main() {
  testWidgets(
    'reveals whole Unicode runes every 20ms and holds the cursor 96ms',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.controller.dispose);
      var finished = false;
      harness.enqueue('😀甲乙', complete: true).then((_) => finished = true);
      await tester.pump();
      expect(harness.text, '😀');
      await tester.pump(const Duration(milliseconds: 19));
      expect(harness.text, '😀');
      await tester.pump(const Duration(milliseconds: 1));
      expect(harness.text, '😀甲');
      await tester.pump(const Duration(milliseconds: 20));
      expect(harness.text, '😀甲乙');
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 95));
      expect(finished, isFalse);
      expect(harness.controller.blocks.single.isComplete, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(finished, isTrue);
      expect(harness.controller.blocks.single.isComplete, isTrue);
    },
  );

  testWidgets(
    '112-step budget is shared across blocks and reset by semantic reset',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.controller.dispose);
      final text = List.filled(28, '甲').join();
      for (var block = 0; block < 4; block += 1) {
        final pending = harness.enqueue(text, id: 'block-$block');
        await tester.pump();
        for (var step = 0; step < 28; step += 1) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        await pending;
      }
      final last = harness.enqueue(text, id: 'last');
      await tester.pump();
      await last;
      expect(harness.controller.blocks.last.text, text);
      final clarification = harness.controller.enqueue(
        AskTitoDexOnlineStreamEvent.clarification(
          const AskTitoDexClarification(
            turnId: 'turn-1',
            prompt: '请确认对象',
            candidates: [],
          ),
        ),
        1,
        'edition-a',
      );
      await tester.pump();
      await clarification;
      expect(harness.controller.clarification?.prompt, '请确认对象');
      final reset = harness.controller.enqueue(
        const AskTitoDexOnlineStreamEvent.semanticReset(),
        1,
        'edition-a',
      );
      await tester.pump();
      await reset;
      expect(harness.controller.blocks, isEmpty);
      expect(harness.controller.clarification, isNull);
      final fresh = harness.enqueue('甲乙', id: 'fresh');
      await tester.pump();
      expect(harness.text, '甲');
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      await fresh;
    },
  );

  testWidgets(
    'reads reduced motion when each queued block begins, not when enqueued',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.controller.dispose);
      final first = harness.enqueue('甲乙');
      final next = harness.enqueue('立即显示全部', id: 'next', complete: true);
      await tester.pump();
      expect(harness.text, '甲');
      harness.reduceMotion = true;
      await tester.pump(const Duration(milliseconds: 20));
      expect(harness.controller.blocks, hasLength(1));
      await tester.pump(const Duration(milliseconds: 20));
      await first;
      await next;
      expect(harness.controller.blocks.last.text, '立即显示全部');
      expect(harness.controller.blocks.last.isComplete, isTrue);
      expect(harness.preferenceReads, 2);
    },
  );

  testWidgets(
    'final replacement removes incompatible streamed text before reveal',
    (tester) async {
      final harness = _Harness()..reduceMotion = true;
      addTearDown(harness.controller.dispose);
      final initial = harness.enqueue('错误旧答案');
      await tester.pump();
      await initial;
      harness.reduceMotion = false;
      final finalReveal = harness.controller.revealVerifiedResult(
        const AskTitoDexResult(
          status: AskTitoDexStatus.answered,
          answer: '最终答案。',
        ),
        1,
        'edition-a',
      );
      expect(harness.text, '最');
      expect(
        harness.controller.blocks.any((block) => block.text.contains('错误')),
        isFalse,
      );
      for (var step = 0; step < 12; step += 1) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await finalReveal;
      expect(harness.text, '最终答案。');
      expect(harness.controller.blocks.single.isComplete, isTrue);
    },
  );

  testWidgets(
    'page identity invalidates old queued blocks and edition callbacks',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.controller.dispose);
      final old = harness.enqueue('旧版长答案');
      final queuedOld = harness.enqueue('旧版排队答案', id: 'queued');
      await tester.pump();
      harness.requestId = 2;
      harness.edition = 'edition-b';
      harness.controller.begin();
      harness.reduceMotion = true;
      final fresh = harness.enqueue('新版本答案');
      await tester.pump();
      await fresh;
      await tester.pump(const Duration(milliseconds: 200));
      await old;
      await queuedOld;
      await harness.controller.revealVerifiedResult(
        const AskTitoDexResult(
          status: AskTitoDexStatus.answered,
          answer: '失效结果',
        ),
        1,
        'edition-a',
      );
      harness.controller.queueProgress(
        AskTitoDexProgress.revealingAnswer,
        1,
        'edition-a',
      );
      expect(harness.text, '新版本答案');
      expect(harness.controller.blocks, hasLength(1));
      expect(harness.controller.progress, AskTitoDexProgress.checkingLocal);
    },
  );

  testWidgets(
    'progress keeps its minimum and disposal prevents delayed notifications',
    (tester) async {
      final harness = _Harness();
      harness.controller.queueProgress(
        AskTitoDexProgress.retrievingSources,
        1,
        'edition-a',
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(harness.controller.progress, AskTitoDexProgress.checkingLocal);
      await tester.pump(const Duration(milliseconds: 50));
      expect(harness.controller.progress, AskTitoDexProgress.retrievingSources);
      harness.reduceMotion = true;
      harness.controller.queueProgress(
        AskTitoDexProgress.revealingAnswer,
        1,
        'edition-a',
      );
      expect(harness.controller.progress, AskTitoDexProgress.revealingAnswer);
      harness.reduceMotion = false;
      final pending = harness.enqueue('销毁后的旧内容');
      await tester.pump();
      harness.controller.queueProgress(
        AskTitoDexProgress.retrievingSources,
        1,
        'edition-a',
      );
      final changes = harness.changes;
      harness.controller.dispose();
      await tester.pump(const Duration(seconds: 1));
      await pending;
      expect(harness.changes, changes);
    },
  );
}

class _Harness {
  _Harness() {
    controller = AskTitoDexRevealController(
      isActiveRequest: (id, token) => id == requestId && token == edition,
      reduceMotion: () {
        preferenceReads += 1;
        return reduceMotion;
      },
      onChanged: () => changes += 1,
      onBlocksChanged: () => changes += 1,
    )..begin();
  }

  late final AskTitoDexRevealController controller;
  int requestId = 1;
  String edition = 'edition-a';
  bool reduceMotion = false;
  int preferenceReads = 0;
  int changes = 0;
  String get text => controller.blocks.map((block) => block.text).join();

  Future<void> enqueue(
    String text, {
    String id = 'summary',
    bool complete = false,
  }) => controller.enqueue(
    AskTitoDexOnlineStreamEvent.answerBlock(
      AskTitoDexAnswerBlock(
        id: id,
        kind: AskTitoDexAnswerBlockKind.summary,
        text: text,
        isComplete: complete,
      ),
    ),
    requestId,
    edition,
  );
}
