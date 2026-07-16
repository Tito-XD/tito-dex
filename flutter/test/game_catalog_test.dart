import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/game/game_catalog.dart';
import 'package:titodex/features/game/game_edition.dart';

void main() {
  test('homeGameBadgeLabel strips parenthetical slug', () {
    expect(
      homeGameBadgeLabel(defaultGameEdition),
      '心金/魂银',
    );
    expect(
      homeGameBadgeLabel(GameEdition.all.firstWhere((e) => e.slug == 'sv')),
      '朱/紫',
    );
  });

  test('Gen VI+ editions carry a bundled HOME icon asset', () {
    const bundled = {
      'xy', 'oras', 'sm', 'usum', 'lgpe', 'swsh',
      'bdsp', 'pla', 'sv', 'lza', 'champions', //
    };
    for (final edition in GameEdition.all) {
      final asset = edition.iconAsset;
      if (bundled.contains(edition.slug)) {
        expect(asset, 'assets/game_icons/${edition.slug}.png');
      } else {
        expect(asset, isNull, reason: '${edition.slug} predates HOME icons');
      }
    }
  });

  test('gameEditionShortCode extracts the parenthetical tag', () {
    expect(gameEditionShortCode(defaultGameEdition), 'HGSS');
    expect(
      gameEditionShortCode(GameEdition.all.firstWhere((e) => e.slug == 'gs')),
      'GS',
    );
    expect(
      gameEditionShortCode(
        GameEdition.all.firstWhere((e) => e.slug == 'champions'),
      ),
      'CHAM',
    );
  });
}
