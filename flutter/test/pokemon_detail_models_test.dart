import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_game_scope.dart';
import 'package:titodex/features/dex/type_chart.dart';

void main() {
  test('formatTypeMultiplier covers common defensive values', () {
    expect(formatTypeMultiplier(2), '2');
    expect(formatTypeMultiplier(0.5), '1/2');
    expect(formatTypeMultiplier(0), '0');
    expect(formatTypeMultiplier(1), '1');
  });

  test('johto dex constants include HGSS flavor versions', () {
    expect(hgssFlavorVersions, contains('heartgold'));
    expect(hgssFlavorVersions, contains('soulsilver'));
    expect(johtoPokedexNames, contains('original-johto'));
  });

  test('computeDefensiveMultipliers returns all 18 types', () {
    const relations = {
      'fire': TypeDamageRelations(
        doubleDamageTo: {'grass'},
        halfDamageTo: {'fire'},
        noDamageTo: {},
      ),
    };
    final multipliers =
        computeDefensiveMultipliers(['fire'], relations);
    expect(multipliers.length, typeGridOrder.length);
    expect(multipliers['water'], 1);
  });
}
