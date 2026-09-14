import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/journey/ask_titodex_service.dart';
import 'package:titodex/features/journey/ask_titodex_settings.dart';
import 'package:titodex/features/journey/progression_hints.dart';

class _EmptyHints implements ProgressionHintDataSource {
  @override
  Future<String?> loadJson() async => null;
}

const _context = AskTitoDexContext(
  game: 'soulsilver',
  generation: 4,
  locationLabel: null,
  locationId: null,
  badgeIds: [],
  milestoneIds: [],
  parserRevision: 0,
);
List<Map<String, String>> _pair(String question) => [
  {'role': 'user', 'content': question},
  {'role': 'assistant', 'content': '不可信的旧回答说已经拿到了所有道具。'},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProgressionHintRepository hints;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    askTitoDexSettings.resetForTest();
    await askTitoDexSettings.load();
    hints = ProgressionHintRepository(
      extensionDataSource: _EmptyHints(),
      downloadedPackDataSource: _EmptyHints(),
    );
  });

  test(
    'offline service inherits the last supported blocker without trusting assistant facts',
    () async {
      final service = AskTitoDexService(hints: hints);
      final result = await service.ask(
        '那接下来怎么做？',
        _context,
        history: _pair('36号道路树才怪挡路怎么办？'),
      );
      expect(result.status, AskTitoDexStatus.answered);
      expect(result.answer, contains('花店'));
      expect(result.matchedHintIds, ['hgss-route36-sudowoodo']);
      expect(result.answer, isNot(contains('已经拿到了所有道具')));
      expect(result.unknowns.join(), contains('无法确认'));
    },
  );

  test(
    'successive explicit continuations inherit but a changed topic is a boundary',
    () async {
      expect(
        (await hints.answer(
          'what next?',
          _context,
          history: [..._pair('栎树林的小树怎么过？'), ..._pair('具体怎么做？')],
        )).matchedHintIds,
        ['hgss-ilex-forest-cut-tree'],
      );
      for (final topic in ['皮卡丘怎么进化？', '今天的天气如何？']) {
        expect(
          (await hints.answer(
            '接下来呢？',
            _context,
            history: [..._pair('36号道路树才怪挡路'), ..._pair(topic)],
          )).status,
          AskTitoDexStatus.noMatch,
        );
      }
    },
  );

  test(
    'new questions, unknown details, general and other games never revive an old blocker',
    () async {
      final history = _pair('树才怪挡路');
      for (final question in ['它有多少血？', 'PTCG树才怪的卡牌呢？', '能用火烧掉它吗？']) {
        expect(
          (await hints.answer(question, _context, history: history)).status,
          AskTitoDexStatus.noMatch,
        );
      }
      for (final game in ['general', 'platinum']) {
        final context = AskTitoDexContext(
          game: game,
          generation: game == 'general' ? 0 : 4,
          locationLabel: null,
          locationId: null,
          badgeIds: [],
          milestoneIds: [],
          parserRevision: 0,
        );
        expect(
          (await hints.answer('接下来呢？', context, history: history)).status,
          AskTitoDexStatus.noMatch,
        );
      }
      expect(
        (await hints.answer('接下来呢？', _context)).status,
        AskTitoDexStatus.noMatch,
      );
    },
  );
}
