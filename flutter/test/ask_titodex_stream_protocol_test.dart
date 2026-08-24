import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/journey/ask_titodex_answer_blocks.dart';
import 'package:titodex/features/journey/ask_titodex_settings.dart';
import 'package:titodex/features/journey/ask_titodex_service.dart';
import 'package:titodex/features/journey/progression_hints.dart';

const _context = AskTitoDexContext(
  game: 'violet',
  generation: 9,
  locationLabel: null,
  locationId: null,
  badgeIds: [],
  milestoneIds: [],
  parserRevision: 0,
);

void main() {
  test(
    'semantic NDJSON yields stable cumulative answer block snapshots',
    () async {
      final online = _clientFor([
        {'type': 'progress', 'stage': 'retrieving', 'turnId': 'turn-1'},
        {
          'type': 'answer_plan',
          'turnId': 'turn-1',
          'blocks': [
            {'blockId': 'summary-1', 'kind': 'summary', 'title': '结论'},
          ],
        },
        {
          'type': 'block_start',
          'turnId': 'turn-1',
          'blockId': 'summary-1',
          'kind': 'summary',
          'title': '结论',
        },
        {
          'type': 'block_delta',
          'turnId': 'turn-1',
          'blockId': 'summary-1',
          'delta': '利欧路可以在南第4区遇到。',
        },
        {'type': 'block_end', 'turnId': 'turn-1', 'blockId': 'summary-1'},
        {'type': 'progress', 'stage': 'writing', 'turnId': 'turn-1'},
        {
          'type': 'result',
          'turnId': 'turn-1',
          'result': {
            'status': 'answered',
            'answer': '利欧路可以在南第4区遇到。',
            'confidence': 'medium',
            'answerBlocks': [
              {
                'id': 'summary-1',
                'kind': 'summary',
                'title': '结论',
                'text': '利欧路可以在南第4区遇到。',
              },
            ],
          },
        },
      ]);

      final events = await online.askStream('哪里抓利欧路？', _context).toList();
      final blocks = events
          .map((event) => event.answerBlock)
          .whereType<AskTitoDexAnswerBlock>()
          .toList();

      expect(events.first.stage, AskTitoDexStreamStage.retrieving);
      expect(events.first.turnId, 'turn-1');
      expect(events.where((event) => event.answerPlan != null), hasLength(1));
      expect(blocks, hasLength(3));
      expect(blocks.first.text, isEmpty);
      expect(blocks.first.isComplete, isFalse);
      expect(blocks[1].text, '利欧路可以在南第4区遇到。');
      expect(blocks[1].isComplete, isFalse);
      expect(blocks.last.isComplete, isTrue);
      expect(events.last.result?.answerBlocks.single.id, 'summary-1');
    },
  );

  test(
    'out-of-order semantic events degrade to the authoritative result',
    () async {
      final online = _clientFor([
        {
          'type': 'block_delta',
          'turnId': 'turn-2',
          'blockId': 'summary-1',
          'delta': '不应显示',
        },
        {
          'type': 'result',
          'turnId': 'turn-2',
          'result': {
            'status': 'answered',
            'answer': '仍然返回最终答案。',
            'confidence': 'low',
            'answerBlocks': [
              {'id': 'summary-1', 'kind': 'summary', 'text': '仍然返回最终答案。'},
            ],
          },
        },
      ]);

      final events = await online.askStream('测试', _context).toList();

      expect(events.where((event) => event.answerBlock != null), isEmpty);
      expect(events.where((event) => event.semanticReset), hasLength(1));
      expect(events.last.result?.answer, '仍然返回最终答案。');
    },
  );

  test(
    'service clears partial semantic state after decoder downgrade',
    () async {
      SharedPreferences.setMockInitialValues({});
      askTitoDexSettings.resetForTest();
      await askTitoDexSettings.load();
      await askTitoDexSettings.enableWithConsent();
      addTearDown(askTitoDexSettings.resetForTest);

      final online = _clientFor([
        {
          'type': 'answer_plan',
          'turnId': 'turn-reset',
          'blocks': [
            {'blockId': 'old-summary', 'kind': 'summary'},
          ],
        },
        {
          'type': 'block_start',
          'turnId': 'turn-reset',
          'blockId': 'old-summary',
          'kind': 'summary',
        },
        {
          'type': 'block_delta',
          'turnId': 'turn-reset',
          'blockId': 'old-summary',
          'delta': '不完整的旧内容',
        },
        {
          'type': 'block_delta',
          'turnId': 'turn-reset',
          'blockId': 'old-summary',
          'delta': 'x' * 513,
        },
        {
          'type': 'result',
          'turnId': 'turn-reset',
          'result': {
            'status': 'answered',
            'answer': '最终权威答案。',
            'answerBlocks': [
              {'id': 'final-summary', 'kind': 'summary', 'text': '最终权威答案。'},
            ],
          },
        },
      ]);
      final service = AskTitoDexService(
        hints: ProgressionHintRepository(
          extensionDataSource: const _EmptyHintSource(),
          bundledDataSource: const _EmptyHintSource(),
          downloadedPackDataSource: const _EmptyHintSource(),
        ),
        online: online,
      );
      final streamEvents = <AskTitoDexOnlineStreamEvent>[];

      final result = await service.ask(
        '测试语义降级',
        _context,
        onStreamEvent: streamEvents.add,
      );

      expect(streamEvents.where((event) => event.semanticReset), hasLength(1));
      expect(result.status, AskTitoDexStatus.answered);
      expect(result.answer, '最终权威答案。');
      expect(result.answerBlocks.single.id, 'final-summary');
      expect(result.errorCode, isNull);
    },
  );

  test('completed semantic blocks must match final result blocks', () async {
    final online = _clientFor([
      {
        'type': 'answer_plan',
        'turnId': 'turn-3',
        'blocks': [
          {'blockId': 'summary-1', 'kind': 'summary'},
        ],
      },
      {
        'type': 'block_start',
        'turnId': 'turn-3',
        'blockId': 'summary-1',
        'kind': 'summary',
      },
      {
        'type': 'block_delta',
        'turnId': 'turn-3',
        'blockId': 'summary-1',
        'delta': '流内容',
      },
      {'type': 'block_end', 'turnId': 'turn-3', 'blockId': 'summary-1'},
      {
        'type': 'result',
        'turnId': 'turn-3',
        'result': {
          'status': 'answered',
          'answer': '最终内容',
          'answerBlocks': [
            {'id': 'summary-1', 'kind': 'summary', 'text': '最终内容'},
          ],
        },
      },
    ]);

    expect(
      online.askStream('测试', _context).drain<void>(),
      throwsA(
        isA<AskTitoDexOnlineException>().having(
          (error) => error.code,
          'code',
          'semantic_stream_mismatch',
        ),
      ),
    );
  });

  test('final structured metadata is bounded and round-trips', () {
    final valid = AskTitoDexResult.fromJson({
      'status': 'needs_clarification',
      'followUp': '你说的是哪一只？',
      'answerBlocks': [
        {'id': 'question', 'kind': 'clarification', 'text': '请先选择。'},
      ],
      'clarificationCandidates': [
        {'id': 'riolu', 'label': '利欧路', 'kind': 'pokemon'},
      ],
    });
    expect(
      valid.answerBlocks.single.kind,
      AskTitoDexAnswerBlockKind.clarification,
    );
    expect(valid.clarificationCandidates.single.label, '利欧路');
    expect(
      AskTitoDexResult.fromJson(valid.toJson()).answerBlocks.single.text,
      '请先选择。',
    );

    final oversized = AskTitoDexResult.fromJson({
      'status': 'answered',
      'answerBlocks': List.generate(
        askTitoDexMaxAnswerBlocks + 1,
        (index) => {'id': 'block-$index', 'kind': 'paragraph', 'text': 'x'},
      ),
      'clarificationCandidates': List.generate(
        askTitoDexMaxClarificationCandidates + 1,
        (index) => {'id': 'candidate-$index', 'label': '候选$index'},
      ),
    });
    expect(oversized.answerBlocks, isEmpty);
    expect(oversized.clarificationCandidates, isEmpty);
  });

  test('incomplete final projections fall back to canonical block text', () {
    const bulletText = '- 波导弹\n- 剑舞';
    const tableText =
        '| 招式 | 用途 |\n| --- | --- |\n| 波导弹 | 特攻候选 |\n| 剑舞 | 物攻候选 |';
    final result = AskTitoDexResult.fromJson({
      'status': 'answered',
      'answer': '$bulletText\n\n$tableText',
      'answerBlocks': [
        {
          'id': 'moves',
          'kind': 'bullets',
          'text': bulletText,
          'items': ['波导弹'],
        },
        {
          'id': 'comparison',
          'kind': 'table',
          'text': tableText,
          'rows': [
            ['招式', '用途'],
            ['波导弹', '特攻候选'],
          ],
        },
      ],
    });

    expect(result.answer, '$bulletText\n\n$tableText');
    expect(result.answerBlocks, hasLength(2));
    expect(result.answerBlocks.first.text, bulletText);
    expect(result.answerBlocks.first.items, isEmpty);
    expect(result.answerBlocks.last.text, tableText);
    expect(result.answerBlocks.last.rows, isEmpty);

    final valid = AskTitoDexResult.fromJson({
      'status': 'answered',
      'answer': '$bulletText\n\n$tableText',
      'answerBlocks': [
        {
          'id': 'moves',
          'kind': 'bullets',
          'text': bulletText,
          'items': ['波导弹', '剑舞'],
        },
        {
          'id': 'comparison',
          'kind': 'table',
          'text': tableText,
          'rows': [
            ['招式', '用途'],
            ['波导弹', '特攻候选'],
            ['剑舞', '物攻候选'],
          ],
        },
      ],
    });
    expect(valid.answerBlocks.first.items, ['波导弹', '剑舞']);
    expect(valid.answerBlocks.last.rows, [
      ['招式', '用途'],
      ['波导弹', '特攻候选'],
      ['剑舞', '物攻候选'],
    ]);
  });

  test('oversized projection does not discard a valid final result', () async {
    SharedPreferences.setMockInitialValues({});
    askTitoDexSettings.resetForTest();
    await askTitoDexSettings.load();
    await askTitoDexSettings.enableWithConsent();
    addTearDown(askTitoDexSettings.resetForTest);

    final bulletText = List.generate(
      askTitoDexMaxBlockItems + 1,
      (index) => '- 第${index + 1}项',
    ).join('\n');
    final online = _clientFor([
      {
        'type': 'answer_plan',
        'turnId': 'turn-projection',
        'blocks': [
          {'blockId': 'all-items', 'kind': 'bullets'},
        ],
      },
      {
        'type': 'block_start',
        'turnId': 'turn-projection',
        'blockId': 'all-items',
        'kind': 'bullets',
      },
      {
        'type': 'block_delta',
        'turnId': 'turn-projection',
        'blockId': 'all-items',
        'delta': bulletText,
      },
      {
        'type': 'block_end',
        'turnId': 'turn-projection',
        'blockId': 'all-items',
      },
      {
        'type': 'result',
        'turnId': 'turn-projection',
        'result': {
          'status': 'answered',
          'answer': bulletText,
          'answerBlocks': [
            {
              'id': 'all-items',
              'kind': 'bullets',
              'text': bulletText,
              'items': List.generate(
                askTitoDexMaxBlockItems + 1,
                (index) => '第${index + 1}项',
              ),
            },
          ],
        },
      },
    ]);
    final service = AskTitoDexService(
      hints: ProgressionHintRepository(
        extensionDataSource: const _EmptyHintSource(),
        bundledDataSource: const _EmptyHintSource(),
        downloadedPackDataSource: const _EmptyHintSource(),
      ),
      online: online,
    );

    final result = await service.ask('列出全部内容', _context);

    expect(result.status, AskTitoDexStatus.answered);
    expect(result.answer, bulletText);
    expect(result.answerBlocks.single.text, bulletText);
    expect(result.answerBlocks.single.items, isEmpty);
    expect(result.errorCode, isNull);
  });

  test(
    "service rejects blocks whose joined text differs from final answer",
    () async {
      SharedPreferences.setMockInitialValues({});
      askTitoDexSettings.resetForTest();
      await askTitoDexSettings.load();
      await askTitoDexSettings.enableWithConsent();
      addTearDown(askTitoDexSettings.resetForTest);

      final online = _clientFor([
        {
          "type": "answer_plan",
          "turnId": "turn-answer-mismatch",
          "blocks": [
            {"blockId": "summary-1", "kind": "summary"},
            {"blockId": "paragraph-1", "kind": "paragraph"},
          ],
        },
        {
          "type": "block_start",
          "turnId": "turn-answer-mismatch",
          "blockId": "summary-1",
          "kind": "summary",
        },
        {
          "type": "block_delta",
          "turnId": "turn-answer-mismatch",
          "blockId": "summary-1",
          "delta": "第一块",
        },
        {
          "type": "block_end",
          "turnId": "turn-answer-mismatch",
          "blockId": "summary-1",
        },
        {
          "type": "block_start",
          "turnId": "turn-answer-mismatch",
          "blockId": "paragraph-1",
          "kind": "paragraph",
        },
        {
          "type": "block_delta",
          "turnId": "turn-answer-mismatch",
          "blockId": "paragraph-1",
          "delta": "第二块",
        },
        {
          "type": "block_end",
          "turnId": "turn-answer-mismatch",
          "blockId": "paragraph-1",
        },
        {
          "type": "result",
          "turnId": "turn-answer-mismatch",
          "result": {
            "status": "answered",
            "answer": "第一块第二块",
            "answerBlocks": [
              {"id": "summary-1", "kind": "summary", "text": "第一块"},
              {"id": "paragraph-1", "kind": "paragraph", "text": "第二块"},
            ],
          },
        },
      ]);
      final emptyHints = ProgressionHintRepository(
        extensionDataSource: const _EmptyHintSource(),
        bundledDataSource: const _EmptyHintSource(),
        downloadedPackDataSource: const _EmptyHintSource(),
      );
      final service = AskTitoDexService(hints: emptyHints, online: online);

      final result = await service.ask("测试", _context);

      expect(result.status, AskTitoDexStatus.noMatch);
      expect(result.onlineAttempted, isTrue);
      expect(result.errorCode, "online_semantic_answer_mismatch_fallback");
    },
  );

  test("service awaits semantic callbacks before reading result", () async {
    SharedPreferences.setMockInitialValues({});
    askTitoDexSettings.resetForTest();
    await askTitoDexSettings.load();
    await askTitoDexSettings.enableWithConsent();
    addTearDown(askTitoDexSettings.resetForTest);

    final online = _clientFor([
      {
        "type": "answer_plan",
        "turnId": "turn-paced",
        "blocks": [
          {"blockId": "summary-1", "kind": "summary"},
        ],
      },
      {
        "type": "block_start",
        "turnId": "turn-paced",
        "blockId": "summary-1",
        "kind": "summary",
      },
      {
        "type": "block_delta",
        "turnId": "turn-paced",
        "blockId": "summary-1",
        "delta": "逐块显示。",
      },
      {"type": "block_end", "turnId": "turn-paced", "blockId": "summary-1"},
      {
        "type": "result",
        "turnId": "turn-paced",
        "result": {
          "status": "answered",
          "answer": "逐块显示。",
          "answerBlocks": [
            {"id": "summary-1", "kind": "summary", "text": "逐块显示。"},
          ],
        },
      },
    ]);
    final service = AskTitoDexService(
      hints: ProgressionHintRepository(
        extensionDataSource: const _EmptyHintSource(),
        bundledDataSource: const _EmptyHintSource(),
        downloadedPackDataSource: const _EmptyHintSource(),
      ),
      online: online,
    );
    final blockCallbackEntered = Completer<void>();
    final releaseBlockCallback = Completer<void>();
    final resultCallbackEntered = Completer<void>();

    final request = service.ask(
      "测试异步回调",
      _context,
      onStreamEvent: (event) async {
        if (event.answerBlock?.isComplete == true) {
          blockCallbackEntered.complete();
          await releaseBlockCallback.future;
        }
        if (event.result != null) resultCallbackEntered.complete();
      },
    );
    await blockCallbackEntered.future;
    await Future<void>.delayed(Duration.zero);

    expect(resultCallbackEntered.isCompleted, isFalse);
    releaseBlockCallback.complete();
    final result = await request;
    expect(resultCallbackEntered.isCompleted, isTrue);
    expect(result.answer, "逐块显示。");
  });
}

HttpAskTitoDexOnlineClient _clientFor(List<Map<String, dynamic>> events) {
  return HttpAskTitoDexOnlineClient(
    client: MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(events.map(jsonEncode).join('\n')),
        200,
        headers: {'content-type': 'application/x-ndjson'},
      ),
    ),
    endpoint: 'https://example.test/v1/ask',
    deviceKeyProvider: () async => 'anonymous-test-key-123',
  );
}

class _EmptyHintSource implements ProgressionHintDataSource {
  const _EmptyHintSource();

  @override
  Future<String?> loadJson() async => "{\"entries\":[]}";
}
