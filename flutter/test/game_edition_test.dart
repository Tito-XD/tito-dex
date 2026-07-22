import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/game/game_edition.dart';

void main() {
  test('GameEdition.all contains 23 games', () {
    expect(GameEdition.all.length, 23);
  });

  test('defaultGameEdition is hgss', () {
    expect(defaultGameEdition.slug, 'hgss');
    expect(defaultGameEdition.versionGroup, 'heartgold-soulsilver');
  });

  test('gameEditionFromSlug resolves known slugs', () {
    expect(gameEditionFromSlug('sv')?.labelZh, contains('朱'));
    expect(gameEditionFromSlug('lza')?.hasPokeApiData, isTrue);
    expect(gameEditionFromSlug('missing'), isNull);
  });

  test('gameEditionFromJourneyGame maps SoulSilver to hgss', () {
    final edition = gameEditionFromJourneyGame('SoulSilver');
    expect(edition.slug, 'hgss');
    expect(edition.journeyGameKey, 'SoulSilver');
  });

  test('lza uses its current PokeAPI data key', () {
    final lza = gameEditionFromSlug('lza')!;
    expect(lza.dataVersionGroupKey, 'legends-za');
    expect(lza.fallbackSlug, 'sv');
    expect(lza.defaultRegionalPokedex.name, 'kalos');
  });

  test('bdsp falls back to dp for sparse data', () {
    final bdsp = gameEditionFromSlug('bdsp')!;
    expect(bdsp.fallbackSlug, 'dp');
    expect(bdsp.versionGroup, 'brilliant-diamond-shining-pearl');
  });
}
