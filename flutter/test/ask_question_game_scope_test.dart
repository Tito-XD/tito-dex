import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/journey/ask_question_game_scope.dart';

List<Map<String, String>> pair(String question, [String answer = '已有回答']) => [
  {'role': 'user', 'content': question},
  {'role': 'assistant', 'content': answer},
];

void main() {
  final cases =
      jsonDecode(
            File(
              '../cloudflare/journey-assistant/test/question_game_scope_cases.json',
            ).readAsStringSync(),
          )
          as List<dynamic>;
  for (final value in cases) {
    final row = value as Map<String, dynamic>;
    final targets = (row['targets'] as List<dynamic>).cast<String>();
    test('same reliable game recognition as Worker: ${row['question']}', () {
      final expected =
          targets.isNotEmpty &&
          (targets.length != 1 || targets.single != 'soulsilver');
      expect(
        shouldSkipLocalGameHints(
          row['question'] as String,
          'soulsilver',
          const [],
        ),
        expected,
      );
    });
  }
  test('same explicit game may continue local hints', () {
    expect(
      shouldSkipLocalGameHints('《魂银》挡路的树怎么过？', 'soulsilver', const []),
      isFalse,
    );
  });
  test('inherits only recent explicit user game for a follow-up', () {
    expect(
      shouldSkipLocalGameHints('那怎么获得？', 'soulsilver', pair('《白金》利欧路怎么进化？')),
      isTrue,
    );
    expect(
      shouldSkipLocalGameHints(
        '那怎么获得？',
        'soulsilver',
        pair('利欧路怎么进化？', '在《白金》里这样做'),
      ),
      isFalse,
    );
  });
  test('ordinary new question defaults to global game again', () {
    expect(
      shouldSkipLocalGameHints('挡路的树怎么过？', 'soulsilver', pair('《白金》利欧路怎么进化？')),
      isFalse,
    );
  });
  test(
    'new title-less user topic and failed/empty history break inheritance',
    () {
      expect(
        shouldSkipLocalGameHints('那怎么进化？', 'soulsilver', [
          ...pair('《白金》利欧路怎么获得？'),
          ...pair('伊布在哪里？'),
        ]),
        isFalse,
      );
      expect(
        shouldSkipLocalGameHints('那怎么获得？', 'soulsilver', [
          ...pair('《白金》利欧路怎么进化？'),
          ...pair('下个问题', ''),
        ]),
        isFalse,
      );
    },
  );
}
