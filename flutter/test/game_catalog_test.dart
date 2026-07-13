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
}
