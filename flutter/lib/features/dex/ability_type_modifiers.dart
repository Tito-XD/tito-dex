/// Defensive ability modifiers on incoming move types (multiply type chart).
library;

/// PokeAPI ability slug → incoming attack-type multipliers.
///
/// Values stack multiplicatively on top of the standard type chart.
const kAbilityDefensiveTypeModifiers = <String, Map<String, double>>{
  'sap-sipper': {'grass': 0},
  'thick-fat': {'fire': 0.5, 'ice': 0.5},
  'levitate': {'ground': 0},
  'flash-fire': {'fire': 0},
  'water-absorb': {'water': 0},
  'volt-absorb': {'electric': 0},
  'lightning-rod': {'electric': 0},
  'storm-drain': {'water': 0},
  'motor-drive': {'electric': 0},
  'earth-eater': {'ground': 0},
  'well-baked-body': {'fire': 0},
  'heatproof': {'fire': 0.5},
  'water-bubble': {'fire': 0.5},
  'dry-skin': {'water': 0, 'fire': 1.25},
  'fluffy': {'fire': 2},
  'purifying-salt': {'ghost': 0.5},
};

String abilitySlugFromNameEn(String nameEn) =>
    nameEn.toLowerCase().replaceAll(' ', '-');

Map<String, double>? defensiveTypeModifiersForAbility(String? abilitySlug) {
  if (abilitySlug == null || abilitySlug.isEmpty) {
    return null;
  }
  return kAbilityDefensiveTypeModifiers[abilitySlug];
}

bool abilityAffectsTypeMatchup(String? abilitySlug) =>
    defensiveTypeModifiersForAbility(abilitySlug) != null;

void applyAbilityTypeModifiers(
  Map<String, double> multipliers,
  String? abilitySlug,
) {
  final mods = defensiveTypeModifiersForAbility(abilitySlug);
  if (mods == null) {
    return;
  }
  for (final entry in mods.entries) {
    final current = multipliers[entry.key] ?? 1.0;
    multipliers[entry.key] = current * entry.value;
  }
}
