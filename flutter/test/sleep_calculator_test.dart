import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/sleep/sleep_calculator.dart';

void main() {
  group('Neroli sleep score port', () {
    test('matches pinned upstream sample durations', () {
      expect(sleepScoreFromDurationMinutes(8 * 60), 94);
      expect(sleepScoreFromDurationMinutes(4 * 60 + 15), 50);
      expect(sleepScoreFromDurationMinutes(8 * 60 + 30), 100);
      expect(sleepScoreFromDurationMinutes(12 * 60), 100);
      expect(sleepScoreFromDurationMinutes(60 + 15), 15);
      expect(sleepScoreFromDurationMinutes(-10), 0);
    });

    test('duration wraps across midnight', () {
      expect(
        sleepDurationMinutesBetween(
          bedtimeMinutes: 23 * 60 + 30,
          wakeupMinutes: 15,
        ),
        45,
      );
      expect(
        sleepDurationMinutesBetween(
          bedtimeMinutes: 22 * 60,
          wakeupMinutes: 23 * 60 + 15,
        ),
        75,
      );
    });
  });

  group('Neroli recipe energy port', () {
    test('ships all 19 current ingredient values', () {
      expect(sleepIngredients, hasLength(19));
      expect(
        sleepIngredients.firstWhere((item) => item.slug == 'apple').baseEnergy,
        90,
      );
      expect(
        sleepIngredients.firstWhere((item) => item.slug == 'tail').baseEnergy,
        342,
      );
    });

    test('level table covers 1 through 70', () {
      expect(recipeLevelMultipliers, hasLength(70));
      expect(recipeLevelMultiplier(1), 1);
      expect(recipeLevelMultiplier(10), 1.18);
      expect(recipeLevelMultiplier(70), 3.58);
      expect(recipeLevelMultiplier(999), 3.58);
    });

    test('matches ingredient, level, and recipe bonus formula', () {
      const quantities = {'apple': 2, 'milk': 3};
      expect(ingredientBaseEnergy(quantities), 474);
      expect(
        calculateRecipeEnergy(
          quantities: quantities,
          recipeLevel: 10,
          recipeBonusPercent: 10,
        ),
        615,
      );
    });

    test('ignores unknown and negative ingredient amounts', () {
      expect(ingredientBaseEnergy(const {'apple': -2, 'unknown': 50}), 0);
    });
  });
}
