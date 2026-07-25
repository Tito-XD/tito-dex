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

  test('every edition carries a bundled game icon asset', () {
    const slugFiles = {
      'xy', 'oras', 'sm', 'usum', 'lgpe', 'swsh',
      'bdsp', 'pla', 'sv', 'lza', 'champions', //
    };
    const flavorFiles = {
      'rgb': 'red',
      'gs': 'gold',
      'rs': 'ruby',
      'frlg': 'firered',
      'dp': 'diamond',
      'hgss': 'heartgold',
      'bw': 'black',
      'bw2': 'black-2',
      'yellow': 'yellow',
      'crystal': 'crystal',
      'emerald': 'emerald',
      'pt': 'platinum',
    };
    for (final edition in GameEdition.all) {
      final asset = edition.iconAsset;
      if (slugFiles.contains(edition.slug)) {
        expect(asset, 'assets/game_icons/${edition.slug}.png');
      } else {
        final flavor = flavorFiles[edition.slug];
        expect(
          asset,
          'assets/game_icons/$flavor.png',
          reason: '${edition.slug} shows its primary flavor icon',
        );
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
