import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/shiny_odds.dart';
import 'package:titodex/features/dex/silhouette_quiz.dart';

PokemonSummary _summary(int id) => PokemonSummary(
  id: id,
  nameEn: 'mon-$id',
  nameZh: '宝可梦$id',
  types: const ['normal'],
);

void main() {
  group('buildSilhouetteQuestion', () {
    final pool = [for (var id = 1; id <= 30; id++) _summary(id)];

    test('produces four distinct choices including the answer', () {
      final question = buildSilhouetteQuestion(pool, Random(7));
      expect(question, isNotNull);
      expect(question!.choices, hasLength(4));
      expect(
        question.choices.map((c) => c.id).toSet(),
        hasLength(4),
      );
      expect(
        question.choices.map((c) => c.id),
        contains(question.answer.id),
      );
    });

    test('is deterministic for a fixed seed', () {
      final a = buildSilhouetteQuestion(pool, Random(42))!;
      final b = buildSilhouetteQuestion(pool, Random(42))!;
      expect(a.answer.id, b.answer.id);
      expect(
        a.choices.map((c) => c.id).toList(),
        b.choices.map((c) => c.id).toList(),
      );
    });

    test('avoids excluded answers when alternatives exist', () {
      final excluded = {for (var id = 1; id <= 25; id++) id};
      for (var seed = 0; seed < 20; seed++) {
        final question = buildSilhouetteQuestion(
          pool,
          Random(seed),
          excludeIds: excluded,
        )!;
        expect(excluded.contains(question.answer.id), isFalse);
      }
    });

    test('returns null when the pool is too small', () {
      expect(
        buildSilhouetteQuestion([_summary(1), _summary(2)], Random(1)),
        isNull,
      );
    });
  });

  group('shinyRoll', () {
    test('is deterministic per (seed, species)', () {
      expect(shinyRoll(123, 25), shinyRoll(123, 25));
    });

    test('hits roughly 1/64 across many species', () {
      var hits = 0;
      for (var id = 1; id <= 5000; id++) {
        if (shinyRoll(99, id)) {
          hits += 1;
        }
      }
      // Expectation ~78; keep a generous band to stay flake-free.
      expect(hits, inInclusiveRange(30, 160));
    });
  });
}
