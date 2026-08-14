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

  test('selected HGSS flavor owns its exact label and journey key', () {
    final heartGold = GameEdition.hgss.withFlavor('heartgold');
    final soulSilver = GameEdition.hgss.withFlavor('soulsilver');

    expect(heartGold.selectedLabelZh, '心金');
    expect(heartGold.selectedJourneyGameKey, 'HeartGold');
    expect(soulSilver.selectedLabelZh, '魂银');
    expect(soulSilver.selectedJourneyGameKey, 'SoulSilver');
  });

  test('manual modern editions expose exact Assistant game keys', () {
    expect(
      gameEditionFromSlug('swsh')!.withFlavor('shield').selectedJourneyGameKey,
      'shield',
    );
    expect(
      gameEditionFromSlug('bdsp')!
          .withFlavor('brilliant-diamond')
          .selectedJourneyGameKey,
      'brilliant-diamond',
    );
    expect(
      gameEditionFromSlug('pla')!
          .withFlavor('legends-arceus')
          .selectedJourneyGameKey,
      'legends-arceus',
    );
    expect(
      gameEditionFromSlug('sv')!.withFlavor('violet').selectedJourneyGameKey,
      'violet',
    );
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

  group('gameEditionForSaveGame', () {
    test('picks the flavor when the save pins a single version', () {
      final soulSilver = gameEditionForSaveGame('SoulSilver')!;
      expect(soulSilver.slug, 'hgss');
      expect(soulSilver.selectedFlavor, 'soulsilver');

      final pearl = gameEditionForSaveGame('Pearl')!;
      expect(pearl.slug, 'dp');
      expect(pearl.selectedFlavor, 'pearl');

      final ultraMoon = gameEditionForSaveGame('UltraMoon')!;
      expect(ultraMoon.slug, 'usum');
      expect(ultraMoon.selectedFlavor, 'ultra-moon');
    });

    test('stays merged when the save cannot pin a version', () {
      final rgb = gameEditionForSaveGame('RedBlueYellow')!;
      expect(rgb.slug, 'rgb');
      expect(rgb.selectedFlavor, isNull);

      final frlg = gameEditionForSaveGame('FireRedLeafGreen')!;
      expect(frlg.slug, 'frlg');
      expect(frlg.selectedFlavor, isNull);
    });

    test('covers every game name the save parser can emit', () {
      const parserGames = [
        'RedBlueYellow',
        'GoldSilver',
        'Crystal',
        'RubySapphire',
        'Emerald',
        'FireRedLeafGreen',
        'Diamond',
        'Pearl',
        'DiamondPearl',
        'Platinum',
        'HeartGold',
        'SoulSilver',
        'Black',
        'White',
        'BlackWhite',
        'Black2',
        'White2',
        'X',
        'Y',
        'XY',
        'OmegaRuby',
        'AlphaSapphire',
        'ORAS',
        'Sun',
        'Moon',
        'SunMoon',
        'UltraSun',
        'UltraMoon',
        'USUM',
      ];
      for (final game in parserGames) {
        expect(
          gameEditionForSaveGame(game),
          isNotNull,
          reason: 'parser game "$game" must map to an edition',
        );
      }
    });

    test('returns null for unknown names instead of defaulting', () {
      expect(gameEditionForSaveGame('Champions'), isNull);
      expect(gameEditionForSaveGame(''), isNull);
      expect(gameEditionForSaveGame(null), isNull);
    });
  });
}
