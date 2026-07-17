import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/companion/companion_metrics.dart';

void main() {
  group('companionSpriteSizeFor', () {
    const minSize = 44.0;
    const maxSize = 96.0;

    double sizeFor(int? heightDm) =>
        companionSpriteSizeFor(heightDm, minSize: minSize, maxSize: maxSize);

    test('tiny species pin to the minimum baseline', () {
      expect(sizeFor(1), minSize); // 0.1m 绵绵泡芙级
      expect(sizeFor(companionHeightFloorDm), minSize);
    });

    test('giants pin to the maximum baseline', () {
      expect(sizeFor(companionHeightCeilDm), maxSize);
      expect(sizeFor(145), maxSize); // 吼鲸王 14.5m
      expect(sizeFor(200), maxSize); // 无极汰那 20m
    });

    test('mid heights interpolate proportionally and monotonically', () {
      final cyndaquil = sizeFor(5); // 火球鼠 0.5m
      final riolu = sizeFor(7); // 利欧路 0.7m
      final typhlosion = sizeFor(17); // 火暴兽 1.7m
      final snorlax = sizeFor(21); // 卡比兽 2.1m

      expect(cyndaquil, greaterThan(minSize));
      expect(cyndaquil, lessThan(riolu));
      expect(riolu, lessThan(typhlosion));
      expect(typhlosion, lessThan(snorlax));
      expect(snorlax, lessThan(maxSize));

      // Proportional check: 0.5m sits at (5-2)/(25-2) of the band.
      final expected = minSize + (maxSize - minSize) * (5 - 2) / (25 - 2);
      expect(cyndaquil, closeTo(expected, 0.001));
    });

    test('unknown height falls back to the band midpoint', () {
      expect(sizeFor(null), (minSize + maxSize) / 2);
      expect(sizeFor(0), (minSize + maxSize) / 2);
    });
  });

  group('companionQuotePoolFor', () {
    test('HGSS pool has follower narration plus Gen II flavor', () {
      final pool = companionQuotePoolFor(generation: 4, editionSlug: 'hgss');
      expect(pool, containsAll(companionSharedQuotes));
      expect(pool, containsAll(companionFollowerQuotes));
      expect(pool, containsAll(companionGenerationQuotes[4]!));
      expect(pool.contains(companionPartnerQuote), isFalse);
    });

    test('non-follower games skip follower narration', () {
      final pool = companionQuotePoolFor(generation: 5, editionSlug: 'bw');
      expect(pool.contains(companionFollowerQuotes.first), isFalse);
      expect(pool, containsAll(companionGenerationQuotes[5]!));
    });

    test('partner games add the hug line', () {
      final lgpe = companionQuotePoolFor(generation: 7, editionSlug: 'lgpe');
      expect(lgpe, contains(companionPartnerQuote));
      expect(lgpe, containsAll(companionFollowerQuotes));
    });

    test('intimacy tiers unlock by lifetime pat count', () {
      List<String> pool(int pats) =>
          companionQuotePoolFor(generation: 4, patCount: pats);

      expect(
        pool(0).any(companionIntimacyTier1Quotes.contains),
        isFalse,
      );
      final tier1 = pool(companionIntimacyTier1Pats);
      expect(tier1, containsAll(companionIntimacyTier1Quotes));
      expect(
        tier1.any(companionIntimacyTier2Quotes.contains),
        isFalse,
      );
      expect(
        pool(companionIntimacyTier2Pats),
        containsAll(companionIntimacyTier2Quotes),
      );
    });

    test('time-of-day greetings follow the local hour', () {
      List<String> pool(int hour) =>
          companionQuotePoolFor(generation: 4, hour: hour);

      expect(pool(8), containsAll(companionMorningQuotes));
      expect(pool(8).any(companionNightQuotes.contains), isFalse);
      expect(pool(22), containsAll(companionNightQuotes));
      expect(pool(2), containsAll(companionNightQuotes));
      expect(pool(14).any(companionMorningQuotes.contains), isFalse);
      expect(pool(14).any(companionNightQuotes.contains), isFalse);
    });

    test('shiny sessions add sparkle lines', () {
      final normal = companionQuotePoolFor(generation: 4);
      final shiny = companionQuotePoolFor(generation: 4, shiny: true);
      expect(normal.any(companionShinyQuotes.contains), isFalse);
      expect(shiny, containsAll(companionShinyQuotes));
    });

    test('every generation in the catalog has flavor lines', () {
      for (var generation = 1; generation <= 9; generation++) {
        expect(
          companionGenerationQuotes[generation],
          isNotNull,
          reason: 'gen $generation missing',
        );
      }
    });
  });

  group('pickCompanionQuote', () {
    final pool = companionQuotePoolFor(generation: 4, editionSlug: 'hgss');

    test('never repeats the previous quote back-to-back', () {
      final random = Random(3);
      var previous = pickCompanionQuote(pool, random);
      for (var i = 0; i < 200; i++) {
        final next = pickCompanionQuote(pool, random, previous: previous);
        expect(next, isNot(previous));
        previous = next;
      }
    });

    test('only emits quotes from the given pool', () {
      final random = Random(9);
      for (var i = 0; i < 50; i++) {
        expect(pool, contains(pickCompanionQuote(pool, random)));
      }
    });

    test('formatCompanionQuote substitutes the companion name', () {
      expect(
        formatCompanionQuote('{name}使用了撒娇！', '火球鼠'),
        '火球鼠使用了撒娇！',
      );
      expect(formatCompanionQuote('效果拔群！', '火球鼠'), '效果拔群！');
      expect(
        formatCompanionQuote(companionFriendshipQuote, '波克比'),
        '波克比最喜欢你了！❤',
      );
    });
  });
}
