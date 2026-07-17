import '../../l10n/game_zh.dart';
import '../parser/hgss_format.dart';

/// HGSS journey companion identity + name→dex-id resolution. The animated
/// standby art itself lives in companion_media.dart (bundled/cached/网络).
const hgssDefaultCompanion = 'Cyndaquil';

const companionSpeciesIds = <String, int>{
  'Chikorita': 152,
  'Cyndaquil': 155,
  'Quilava': 156,
  'Typhlosion': 157,
  'Totodile': 158,
  'Riolu': 447,
};

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
