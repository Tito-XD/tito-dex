import 'dart:math' as math;

/// Small, deterministic Pokémon Sleep helpers ported from Neroli's Lab.
///
/// Upstream: https://github.com/nerolis-lab/nerolis-lab
/// Pinned commit: cb533f240a0551da315151c310b4dbd165091672
/// License: Apache-2.0. See assets/licenses/nerolis-lab-Apache-2.0.txt.
/// Modified for TitoDex in 2026: translated to Dart, reduced to transparent
/// offline helpers, and given explicit input clamping and Chinese UI metadata.
const int fullSleepScoreMinutes = 8 * 60 + 30;

int sleepDurationMinutesBetween({
  required int bedtimeMinutes,
  required int wakeupMinutes,
}) {
  final safeBedtime = bedtimeMinutes.clamp(0, 24 * 60 - 1);
  final safeWakeup = wakeupMinutes.clamp(0, 24 * 60 - 1);
  final duration = safeWakeup - safeBedtime;
  return duration < 0 ? duration + 24 * 60 : duration;
}

int sleepScoreFromDurationMinutes(int durationMinutes) {
  final safeMinutes = math.max(0, durationMinutes);
  return math.min(100, (safeMinutes / fullSleepScoreMinutes * 100).round());
}

class SleepIngredient {
  const SleepIngredient({
    required this.slug,
    required this.nameZh,
    required this.nameEn,
    required this.baseEnergy,
  });

  final String slug;
  final String nameZh;
  final String nameEn;
  final int baseEnergy;
}

/// Ingredient values follow the pinned Neroli's Lab ingredient catalog.
/// Chinese labels follow the in-game terminology recorded by 52Poké Wiki.
const sleepIngredients = <SleepIngredient>[
  SleepIngredient(
    slug: 'apple',
    nameZh: '特选苹果',
    nameEn: 'Fancy Apple',
    baseEnergy: 90,
  ),
  SleepIngredient(
    slug: 'milk',
    nameZh: '哞哞鲜奶',
    nameEn: 'Moomoo Milk',
    baseEnergy: 98,
  ),
  SleepIngredient(
    slug: 'soybean',
    nameZh: '萌绿大豆',
    nameEn: 'Greengrass Soybeans',
    baseEnergy: 100,
  ),
  SleepIngredient(
    slug: 'honey',
    nameZh: '甜甜蜜',
    nameEn: 'Honey',
    baseEnergy: 101,
  ),
  SleepIngredient(
    slug: 'sausage',
    nameZh: '豆制肉',
    nameEn: 'Bean Sausage',
    baseEnergy: 103,
  ),
  SleepIngredient(
    slug: 'ginger',
    nameZh: '暖暖姜',
    nameEn: 'Warming Ginger',
    baseEnergy: 109,
  ),
  SleepIngredient(
    slug: 'tomato',
    nameZh: '好眠番茄',
    nameEn: 'Snoozy Tomato',
    baseEnergy: 110,
  ),
  SleepIngredient(
    slug: 'egg',
    nameZh: '特选蛋',
    nameEn: 'Fancy Egg',
    baseEnergy: 115,
  ),
  SleepIngredient(
    slug: 'oil',
    nameZh: '纯粹油',
    nameEn: 'Pure Oil',
    baseEnergy: 121,
  ),
  SleepIngredient(
    slug: 'potato',
    nameZh: '窝心洋芋',
    nameEn: 'Soft Potato',
    baseEnergy: 124,
  ),
  SleepIngredient(
    slug: 'herb',
    nameZh: '火辣香草',
    nameEn: 'Fiery Herb',
    baseEnergy: 130,
  ),
  SleepIngredient(
    slug: 'corn',
    nameZh: '萌绿玉米',
    nameEn: 'Greengrass Corn',
    baseEnergy: 140,
  ),
  SleepIngredient(
    slug: 'cacao',
    nameZh: '放松可可',
    nameEn: 'Soothing Cacao',
    baseEnergy: 151,
  ),
  SleepIngredient(
    slug: 'coffee',
    nameZh: '醒脑咖啡豆',
    nameEn: 'Rousing Coffee',
    baseEnergy: 153,
  ),
  SleepIngredient(
    slug: 'avocado',
    nameZh: '嫩亮鳄梨',
    nameEn: 'Glossy Avocado',
    baseEnergy: 162,
  ),
  SleepIngredient(
    slug: 'mushroom',
    nameZh: '品鲜蘑菇',
    nameEn: 'Tasty Mushroom',
    baseEnergy: 167,
  ),
  SleepIngredient(
    slug: 'leek',
    nameZh: '粗枝大葱',
    nameEn: 'Large Leek',
    baseEnergy: 185,
  ),
  SleepIngredient(
    slug: 'pumpkin',
    nameZh: '沉甸甸南瓜',
    nameEn: 'Plump Pumpkin',
    baseEnergy: 250,
  ),
  SleepIngredient(
    slug: 'tail',
    nameZh: '美味尾巴',
    nameEn: 'Slowpoke Tail',
    baseEnergy: 342,
  ),
];

const recipeLevelMultipliers = <double>[
  1.00,
  1.02,
  1.04,
  1.06,
  1.08,
  1.09,
  1.11,
  1.13,
  1.16,
  1.18,
  1.19,
  1.21,
  1.23,
  1.24,
  1.26,
  1.28,
  1.30,
  1.31,
  1.33,
  1.35,
  1.37,
  1.40,
  1.42,
  1.45,
  1.47,
  1.50,
  1.52,
  1.55,
  1.58,
  1.61,
  1.64,
  1.67,
  1.70,
  1.74,
  1.77,
  1.81,
  1.84,
  1.88,
  1.92,
  1.96,
  2.00,
  2.04,
  2.08,
  2.13,
  2.17,
  2.22,
  2.27,
  2.32,
  2.37,
  2.42,
  2.48,
  2.53,
  2.59,
  2.65,
  2.71,
  2.77,
  2.83,
  2.90,
  2.97,
  3.03,
  3.09,
  3.15,
  3.21,
  3.27,
  3.34,
  3.39,
  3.43,
  3.48,
  3.52,
  3.58,
];

double recipeLevelMultiplier(int level) {
  final safeLevel = level.clamp(1, recipeLevelMultipliers.length);
  return recipeLevelMultipliers[safeLevel - 1];
}

int ingredientBaseEnergy(Map<String, int> quantities) {
  return sleepIngredients.fold(0, (total, ingredient) {
    final amount = math.max(0, quantities[ingredient.slug] ?? 0);
    return total + ingredient.baseEnergy * amount;
  });
}

int calculateRecipeEnergy({
  required Map<String, int> quantities,
  required int recipeLevel,
  int recipeBonusPercent = 0,
}) {
  final base = ingredientBaseEnergy(quantities);
  final bonus = math.max(0, recipeBonusPercent);
  return (base * recipeLevelMultiplier(recipeLevel) * (1 + bonus / 100))
      .round();
}
