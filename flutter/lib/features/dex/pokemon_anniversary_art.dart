/// Species-level commemorative artwork from the official 30th logo catalog.
/// These are display assets, never battle forms or shiny/animated variants.
const pokemonAnniversarySourceUrl = 'https://www.pokemon.co.jp/ex/30th_logo/';

String? pokemonAnniversaryArtUrl(int nationalId) {
  if (nationalId < 1 || nationalId > 1025) return null;
  final key = nationalId.toString().padLeft(4, '0');
  return '${pokemonAnniversarySourceUrl}assets/img/download/$key.png';
}
