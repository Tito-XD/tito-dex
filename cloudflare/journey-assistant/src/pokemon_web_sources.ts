/**
 * Server-owned Pokémon research boundary shared by Tavily and DeepSeek.
 *
 * Search snippets are transient evidence only: they are never written to R2,
 * AI Search, the APK, or logs. The list intentionally spans official pages,
 * encyclopedias, walkthroughs, and long-running player guide communities so
 * natural-language questions are not limited to encyclopedia wording.
 */
export const POKEMON_WEB_ALLOWED_DOMAINS = [
  'www.pokemon.com',
  'bulbapedia.bulbagarden.net',
  'www.serebii.net',
  'strategywiki.org',
  'wiki.52poke.com',
  'pokeapi.co',
  'pokemondb.net',
  'www.smogon.com',
  'www.marriland.com',
  'marriland.com',
  'gamefaqs.gamespot.com',
  'game8.co',
  'www.ign.com',
  'www.nintendolife.com',
  'www.eurogamer.net',
] as const;

export type PokemonWebAllowedDomain =
  (typeof POKEMON_WEB_ALLOWED_DOMAINS)[number];
