/// HGSS journey companion artwork (PokeAPI official-artwork sprites).
const hgssDefaultCompanion = 'Cyndaquil';

const companionSpeciesIds = <String, int>{
  'Chikorita': 152,
  'Cyndaquil': 155,
  'Quilava': 156,
  'Typhlosion': 157,
  'Totodile': 158,
  'Riolu': 447,
};

String companionSpriteUrl(String species) {
  final id = companionSpeciesIds[species] ??
      companionSpeciesIds[hgssDefaultCompanion]!;
  return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';
}
