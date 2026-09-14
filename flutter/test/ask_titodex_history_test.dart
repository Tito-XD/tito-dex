import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/journey/ask_titodex_entity_links.dart';
import 'package:titodex/features/journey/ask_titodex_history.dart';
import 'package:titodex/features/journey/progression_hints.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('conversation keeps the newest 50 question and answer pairs', () async {
    const store = SharedPreferencesAskTitoDexHistoryStore();
    for (var index = 0; index < 51; index += 1) {
      await store.append(
        AskTitoDexHistoryEntry(
          game: 'violet',
          question: '问题 $index',
          result: AskTitoDexResult(
            status: AskTitoDexStatus.answered,
            answer: '回答 $index',
          ),
          createdAt: DateTime.utc(2026, 8, 16, 0, index),
        ),
      );
    }

    final history = await store.load();
    expect(history, hasLength(askTitoDexHistoryLimit));
    expect(history.first.question, '问题 1');
    expect(history.last.question, '问题 50');
    expect(history.last.result.answer, '回答 50');
  });

  test('follow-up context sends only six latest pairs from the same game', () {
    final history = [
      for (var index = 0; index < 8; index += 1)
        AskTitoDexHistoryEntry(
          game: 'violet',
          question: '紫问题 $index',
          result: AskTitoDexResult(
            status: AskTitoDexStatus.answered,
            answer: '紫回答 $index',
          ),
          createdAt: DateTime.utc(2026, 8, 16, 0, index),
        ),
      AskTitoDexHistoryEntry(
        game: 'soulsilver',
        question: '魂银问题',
        result: const AskTitoDexResult(
          status: AskTitoDexStatus.answered,
          answer: '魂银回答',
        ),
        createdAt: DateTime.utc(2026, 8, 16, 1),
      ),
    ];

    final messages = askTitoDexRequestHistory(history, game: 'violet');
    expect(messages, hasLength(12));
    expect(messages.first, {'role': 'user', 'content': '紫问题 2'});
    expect(messages.last, {'role': 'assistant', 'content': '紫回答 7'});
    expect(messages.toString(), isNot(contains('魂银')));
  });

  test('follow-up context strips legacy answer envelope and source footer', () {
    final entry = AskTitoDexHistoryEntry(
      game: 'violet',
      question: '路卡利欧有哪些升级招式？',
      result: const AskTitoDexResult(
        status: AskTitoDexStatus.answered,
        answer: '''DeepSeek 原生联网参考（未经 TitoDex 人工审核）：
## 升级习得

| 等级 | 招式 |
| --- | --- |
| 1 | 看穿 |

来源：
[1] Lucario learnset：https://example.com/lucario''',
      ),
      createdAt: DateTime.utc(2026, 8, 22),
    );

    expect(entry.assistantContent, startsWith('## 升级习得'));
    expect(entry.assistantContent, isNot(contains('DeepSeek 原生联网参考')));
    expect(entry.assistantContent, isNot(contains('来源：')));
    expect(entry.assistantContent, isNot(contains('https://')));
    expect(
      askTitoDexRequestHistory([entry], game: 'violet').last['content'],
      entry.assistantContent,
    );
  });

  group('follow-up context boundaries', () {
    AskTitoDexHistoryEntry entry(
      String question,
      AskTitoDexResult result, {
      String game = 'general',
    }) => AskTitoDexHistoryEntry(
      game: game,
      question: question,
      result: result,
      createdAt: DateTime.utc(2026, 9, 14),
    );

    const answered = AskTitoDexResult(
      status: AskTitoDexStatus.answered,
      answer: '已验证的回答。',
    );
    const clarification = AskTitoDexResult(
      status: AskTitoDexStatus.needsClarification,
      followUp: '你指的是哪个版本？',
    );
    final unusableResults = {
      'no match': const AskTitoDexResult(
        status: AskTitoDexStatus.noMatch,
        followUp: '暂未找到资料。',
      ),
      'failure': const AskTitoDexResult(
        status: AskTitoDexStatus.failed,
        followUp: '请求失败，请重试。',
      ),
      'missing answer': const AskTitoDexResult(
        status: AskTitoDexStatus.answered,
      ),
      'blank clarification': const AskTitoDexResult(
        status: AskTitoDexStatus.needsClarification,
        followUp: '   ',
      ),
    };
    for (final failure in unusableResults.entries) {
      test(
        '${failure.key} prevents a follow-up from reviving an older topic',
        () {
          final history = [
            entry('皮卡丘怎么进化？', answered),
            entry('拉普拉斯在哪里捕捉？', failure.value),
          ];

          expect(askTitoDexRequestHistory(history, game: 'general'), isEmpty);

          history.add(entry('伊布怎么进化？', clarification));
          history.add(entry('太阳伊布。', answered));
          final messages = askTitoDexRequestHistory(history, game: 'general');
          expect(messages, [
            {'role': 'user', 'content': '伊布怎么进化？'},
            {'role': 'assistant', 'content': '你指的是哪个版本？'},
            {'role': 'user', 'content': '太阳伊布。'},
            {'role': 'assistant', 'content': '已验证的回答。'},
          ]);
        },
      );
    }

    test('a failure in another scope does not erase this scope context', () {
      final history = [
        entry('皮卡丘怎么进化？', answered),
        entry('拉普拉斯在哪里捕捉？', unusableResults['no match']!, game: 'soulsilver'),
      ];

      expect(askTitoDexRequestHistory(history, game: 'general'), [
        {'role': 'user', 'content': '皮卡丘怎么进化？'},
        {'role': 'assistant', 'content': '已验证的回答。'},
      ]);
      expect(askTitoDexRequestHistory(history, game: 'soulsilver'), isEmpty);
    });
  });

  test(
    'manual history compression keeps only the newest requested entries',
    () async {
      const store = SharedPreferencesAskTitoDexHistoryStore();
      for (var index = 0; index < 14; index += 1) {
        await store.append(
          AskTitoDexHistoryEntry(
            game: 'violet',
            question: '问题 $index',
            result: AskTitoDexResult(
              status: AskTitoDexStatus.answered,
              answer: '回答 $index',
            ),
            createdAt: DateTime.utc(2026, 8, 16, 0, index),
          ),
        );
      }

      final compacted = await store.compact();
      expect(compacted, hasLength(10));
      expect(compacted.first.question, '问题 4');
      expect(compacted.last.question, '问题 13');
      expect(await store.load(), hasLength(10));
    },
  );

  test('entity links resolve stable ids from the runtime catalog', () async {
    final resolver = DexAskTitoDexEntityResolver(
      catalogLoader: () async => const [
        AskTitoDexEntityRecord(
          kind: AskTitoDexEntityKind.pokemon,
          id: 447,
          nameZh: '利欧路',
          nameEn: 'Riolu',
          slug: 'riolu',
        ),
        AskTitoDexEntityRecord(
          kind: AskTitoDexEntityKind.item,
          id: 287,
          nameZh: '讲究围巾',
          nameEn: 'Choice Scarf',
          slug: 'choice-scarf',
        ),
        AskTitoDexEntityRecord(
          kind: AskTitoDexEntityKind.move,
          id: 370,
          nameZh: '近身战',
          nameEn: 'Close Combat',
          slug: 'close-combat',
        ),
        AskTitoDexEntityRecord(
          kind: AskTitoDexEntityKind.ability,
          id: 39,
          nameZh: '精神力',
          nameEn: 'Inner Focus',
          slug: 'inner-focus',
        ),
      ],
    );
    final links = await resolver.resolve(
      question: '紫里哪里抓利欧路？讲究围巾和近身战适合吗？',
      answer: '利欧路也可能讨论精神力特性。',
    );

    expect(
      links.map((link) => link.kind),
      containsAll([
        AskTitoDexEntityKind.pokemon,
        AskTitoDexEntityKind.item,
        AskTitoDexEntityKind.move,
        AskTitoDexEntityKind.ability,
      ]),
    );
    expect(links.singleWhere((link) => link.nameZh == '利欧路').route, '/dex/447');
    expect(
      links.singleWhere((link) => link.nameZh == '讲究围巾').route,
      '/search/reference/json?kind=items&id=287&open=1&q=%E8%AE%B2%E7%A9%B6%E5%9B%B4%E5%B7%BE',
    );
    expect(
      links.singleWhere((link) => link.nameZh == '近身战').slug,
      'close-combat',
    );
  });

  test('ambiguous translated names do not create a misleading chip', () async {
    final resolver = DexAskTitoDexEntityResolver(
      catalogLoader: () async => const [
        AskTitoDexEntityRecord(
          kind: AskTitoDexEntityKind.item,
          id: 1,
          nameZh: '重复名称',
          nameEn: 'First Item',
          slug: 'first-item',
        ),
        AskTitoDexEntityRecord(
          kind: AskTitoDexEntityKind.item,
          id: 2,
          nameZh: '重复名称',
          nameEn: 'Second Item',
          slug: 'second-item',
        ),
      ],
    );

    expect(
      await resolver.resolve(question: '重复名称有什么用？', answer: '暂无。'),
      isEmpty,
    );
    final explicit = await resolver.resolve(
      question: 'First Item 有什么用？',
      answer: '暂无。',
    );
    expect(explicit.single.id, 1);
  });
}
