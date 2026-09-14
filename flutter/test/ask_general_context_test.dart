import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/journey/progression_hints.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('general requests omit all save and version facts', () {
    const context = AskTitoDexContext(
      game: null,
      generation: 4,
      locationLabel: 'Private place',
      locationId: 'johto-route-36-area',
      badgeIds: ['plain_badge'],
      badgeCount: 3,
      milestoneIds: ['story-progress'],
      parserRevision: 7,
    );
    expect(context.toRequestJson(), {
      'game': 'general',
      'generation': 0,
      'badgeIds': <String>[],
      'milestoneIds': <String>[],
      'locale': 'zh-Hans',
      'parserRevision': 0,
      'contextReliability': {
        'game': 'user_selected',
        'location': 'unknown',
        'badges': 'unknown',
        'milestones': 'unsupported',
      },
    });
  });

  final hints = ProgressionHintRepository(
    extensionDataSource: const _NoHints(),
    downloadedPackDataSource: const _NoHints(),
  );
  const gameContext = AskTitoDexContext(
    game: 'soulsilver',
    generation: 4,
    locationLabel: null,
    locationId: null,
    badgeIds: [],
    milestoneIds: [],
    parserRevision: 0,
  );

  for (final question in [
    '动画里火箭队的开场白是什么？',
    'PTCG 火箭队卡牌怎么使用？',
    '树才怪是什么属性？',
    '大葱鸭的种族值是多少？',
    '树才怪的属性是什么？',
    '树才怪会哪些招式？',
    '火箭队的口号是什么？',
  ]) {
    test('local blockers do not answer unrelated topic: $question', () async {
      final answer = await hints.answer(question, gameContext);
      expect(answer.status, AskTitoDexStatus.noMatch);
      expect(answer.answer, isNull);
    });
  }

  test('general mode does not require HeartGold or SoulSilver first', () async {
    const context = AskTitoDexContext(
      game: null,
      generation: 0,
      locationLabel: null,
      locationId: null,
      badgeIds: [],
      milestoneIds: [],
      parserRevision: 0,
    );
    final result = await hints.answer('动画里皮卡丘的训练家是谁？', context);
    expect(result.status, AskTitoDexStatus.noMatch);
    expect(result.followUp, isNot(contains('先确认')));
  });
}

class _NoHints implements ProgressionHintDataSource {
  const _NoHints();

  @override
  Future<String?> loadJson() async => null;
}
