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

  test(
    'entity links resolve Pokemon, item, move and ability from local labels',
    () async {
      final links = await DexAskTitoDexEntityResolver().resolve(
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
      expect(
        links.singleWhere((link) => link.nameZh == '利欧路').route,
        '/dex/447',
      );
      expect(
        links.singleWhere((link) => link.nameZh == '讲究围巾').route,
        contains('kind=items'),
      );
    },
  );
}
