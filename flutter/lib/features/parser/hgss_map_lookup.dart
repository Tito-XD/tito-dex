import '../../l10n/game_zh.dart';
import 'hgss_map_list.dart';

/// Save offset 0x1234 stores an index into the HGSS map list (Project Pokémon).
String locationLabelForMapId(int mapId) {
  if (mapId < 0 || mapId >= hgssMapEntries.length) {
    return localizeLocation('Map #$mapId');
  }

  final entry = hgssMapEntries[mapId];
  final name = entry['name'] ?? 'Unknown';
  final code = entry['code'] ?? '';

  if (code.contains('None None-None')) {
    return localizeLocation(name);
  }

  final hint = _interiorHint(code);
  if (hint == null) {
    return localizeLocation(name);
  }
  return localizeLocation('$name · $hint');
}

String? _interiorHint(String code) {
  if (code.contains('PC ')) {
    return 'Pokémon Center';
  }
  if (code.contains('FS ')) {
    return 'Poké Mart';
  }
  if (code.contains('GYM ')) {
    return 'Gym';
  }
  if (code.startsWith('R ')) {
    return 'Route';
  }
  if (code.startsWith('D ')) {
    return 'Dungeon';
  }
  return null;
}
