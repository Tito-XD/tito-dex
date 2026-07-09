import '../../l10n/game_zh.dart';
import '../parser/hgss_format.dart';

/// HGSS journey companion artwork — bundled front sprites + tap cycle.
const hgssDefaultCompanion = 'Cyndaquil';

const hgssStarterCompanions = ['Chikorita', 'Cyndaquil', 'Totodile'];

const companionSpeciesIds = <String, int>{
  'Chikorita': 152,
  'Cyndaquil': 155,
  'Quilava': 156,
  'Typhlosion': 157,
  'Totodile': 158,
  'Riolu': 447,
};

String cycleCompanion(String current) {
  final index = hgssStarterCompanions.indexOf(current);
  if (index < 0) {
    return hgssStarterCompanions.first;
  }
  return hgssStarterCompanions[(index + 1) % hgssStarterCompanions.length];
}

/// Bundled asset path for HGSS starters (works offline on RG).
String? companionAssetPath(String species) {
  final id = companionSpeciesIds[species];
  if (id == null || !hgssStarterCompanions.contains(species)) {
    return null;
  }
  return 'assets/companion/$id.png';
}

/// Remote fallback when asset is missing.
String companionSpriteUrl(String species) {
  final id = companionSpeciesIds[species] ??
      companionSpeciesIds[hgssDefaultCompanion]!;
  return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png';
}

/// Prefer bundled asset, then remote URL.
String companionSpriteSource(String species) =>
    companionAssetPath(species) ?? companionSpriteUrl(species);

/// Resolve a party / companion label (EN or ZH) to a national dex id.
int? speciesIdForName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  for (final entry in companionSpeciesIds.entries) {
    if (entry.key.toLowerCase() == trimmed.toLowerCase()) {
      return entry.value;
    }
    if (localizeSpecies(entry.key) == trimmed) {
      return entry.value;
    }
  }

  for (final entry in speciesNamesZh.entries) {
    if (entry.value == trimmed ||
        entry.key.toLowerCase() == trimmed.toLowerCase()) {
      return companionSpeciesIds[entry.key] ??
          knownSpeciesIdForLabel(entry.key);
    }
  }

  return knownSpeciesIdForLabel(trimmed);
}
