import '../game/game_edition.dart';
import 'dex_cdn_config.dart';

/// PokeAPI version-group slug → national dex generation (1–9).
const Map<String, int> kSpriteVersionGroupGeneration = {
  'red-blue': 1,
  'yellow': 1,
  'gold-silver': 2,
  'crystal': 2,
  'ruby-sapphire': 3,
  'emerald': 3,
  'firered-leafgreen': 3,
  'diamond-pearl': 4,
  'platinum': 4,
  'heartgold-soulsilver': 4,
  'black-white': 5,
  'black-2-white-2': 5,
  'x-y': 6,
  'omega-ruby-alpha-sapphire': 6,
  'sun-moon': 7,
  'ultra-sun-ultra-moon': 7,
  'lets-go-pikachu-lets-go-eevee': 7,
  'sword-shield': 8,
  'brilliant-diamond-shining-pearl': 8,
  'legends-arceus': 8,
  'scarlet-violet': 9,
};

const List<String> kSpriteVersionGroupOrder = [
  'red-blue',
  'yellow',
  'gold-silver',
  'crystal',
  'ruby-sapphire',
  'emerald',
  'firered-leafgreen',
  'diamond-pearl',
  'platinum',
  'heartgold-soulsilver',
  'black-white',
  'black-2-white-2',
  'x-y',
  'omega-ruby-alpha-sapphire',
  'sun-moon',
  'ultra-sun-ultra-moon',
  'lets-go-pikachu-lets-go-eevee',
  'sword-shield',
  'brilliant-diamond-shining-pearl',
  'legends-arceus',
  'scarlet-violet',
];

/// Pseudo-generation for cross-game sources (HOME / Showdown / 官方绘图).
const int spriteGenerationUniversal = 100;

String generationRomanLabel(int generation) {
  if (generation == spriteGenerationUniversal) {
    return '通用';
  }
  const romans = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX'];
  if (generation < 1 || generation > romans.length) {
    return 'Gen ?';
  }
  return 'Gen ${romans[generation - 1]}';
}

String editionShortLabelForVersionGroup(String versionGroup) {
  for (final edition in GameEdition.all) {
    if (edition.versionGroup == versionGroup) {
      final label = edition.labelZh;
      final paren = label.indexOf(' (');
      return paren > 0 ? label.substring(0, paren) : label;
    }
  }
  return versionGroup;
}

class SpriteEditionOption {
  const SpriteEditionOption({
    required this.versionGroup,
    required this.generation,
    required this.editionLabelZh,
    required this.spriteUrl,
    this.animatedUrl,
  });

  final String versionGroup;
  final int generation;
  final String editionLabelZh;
  final String spriteUrl;
  final String? animatedUrl;

  String get generationLabel => generationRomanLabel(generation);
}

/// Build picker rows from summary remote URLs (PokeAPI / CDN); skips missing URLs.
List<SpriteEditionOption> spriteEditionOptions({
  required Map<String, String>? spriteUrlsByVersion,
  String? fallbackSpriteUrl,
  String? animatedSpriteUrl,
}) {
  final options = <SpriteEditionOption>[];
  final seen = <String>{};

  void addOption(String versionGroup, String? url) {
    if (url == null || url.isEmpty || !seen.add(versionGroup)) {
      return;
    }
    options.add(
      SpriteEditionOption(
        versionGroup: versionGroup,
        generation: kSpriteVersionGroupGeneration[versionGroup] ?? 9,
        editionLabelZh: editionShortLabelForVersionGroup(versionGroup),
        spriteUrl: url,
        animatedUrl: animatedSpriteUrl,
      ),
    );
  }

  final byVersion = spriteUrlsByVersion ?? const {};
  for (final vg in kSpriteVersionGroupOrder) {
    addOption(vg, byVersion[vg]);
  }
  for (final entry in byVersion.entries) {
    addOption(entry.key, entry.value);
  }

  if (options.isEmpty && fallbackSpriteUrl != null && fallbackSpriteUrl.isNotEmpty) {
    options.add(
      SpriteEditionOption(
        versionGroup: 'default',
        generation: 9,
        editionLabelZh: '默认',
        spriteUrl: fallbackSpriteUrl,
        animatedUrl: animatedSpriteUrl,
      ),
    );
  }

  options.sort((a, b) {
    final genCompare = a.generation.compareTo(b.generation);
    if (genCompare != 0) {
      return genCompare;
    }
    return a.editionLabelZh.compareTo(b.editionLabelZh);
  });
  return options;
}

/// PokeAPI sprites GitHub raw base — per-version sprites are fetched on
/// demand from here instead of being bundled into the APK or the dex CDN
/// (the per-version files are too many/small to host on the free R2 tier).
const String pokeApiSpritesBase =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';

/// Gen V black-white animated GIFs exist for ids 1–649.
const int bwAnimatedMaxId = 649;

class _VersionSpriteSource {
  const _VersionSpriteSource(this.versionGroup, this.folder, this.maxId);

  /// PokeAPI version-group slug.
  final String versionGroup;

  /// Folder under `sprites/pokemon/versions/`.
  final String folder;

  /// Highest national dex id with a sprite in this folder.
  final int maxId;
}

/// Version groups with real per-game sprite folders in the PokeAPI repo.
/// Gen VIII+ games have no per-version sprites there; they are covered by the
/// cross-game HOME / Showdown / default sources below.
const List<_VersionSpriteSource> _versionSpriteSources = [
  _VersionSpriteSource('red-blue', 'generation-i/red-blue', 151),
  _VersionSpriteSource('yellow', 'generation-i/yellow', 151),
  _VersionSpriteSource('gold-silver', 'generation-ii/gold', 251),
  _VersionSpriteSource('crystal', 'generation-ii/crystal', 251),
  _VersionSpriteSource('ruby-sapphire', 'generation-iii/ruby-sapphire', 386),
  _VersionSpriteSource('emerald', 'generation-iii/emerald', 386),
  _VersionSpriteSource(
    'firered-leafgreen',
    'generation-iii/firered-leafgreen',
    386,
  ),
  _VersionSpriteSource('diamond-pearl', 'generation-iv/diamond-pearl', 493),
  _VersionSpriteSource('platinum', 'generation-iv/platinum', 493),
  _VersionSpriteSource(
    'heartgold-soulsilver',
    'generation-iv/heartgold-soulsilver',
    493,
  ),
  _VersionSpriteSource('black-white', 'generation-v/black-white', 649),
  _VersionSpriteSource('x-y', 'generation-vi/x-y', 721),
  _VersionSpriteSource(
    'omega-ruby-alpha-sapphire',
    'generation-vi/omegaruby-alphasapphire',
    721,
  ),
  _VersionSpriteSource(
    'ultra-sun-ultra-moon',
    'generation-vii/ultra-sun-ultra-moon',
    807,
  ),
];

String defaultSpriteUrlFor(int id) => '$pokeApiSpritesBase/$id.png';

String shinySpriteUrlFor(int id) => '$pokeApiSpritesBase/shiny/$id.png';

String officialArtworkUrlFor(int id) =>
    '$pokeApiSpritesBase/other/official-artwork/$id.png';

String homeSpriteUrlFor(int id) => '$pokeApiSpritesBase/other/home/$id.png';

String showdownGifUrlFor(int id, {bool shiny = false}) => shiny
    ? '$pokeApiSpritesBase/other/showdown/shiny/$id.gif'
    : '$pokeApiSpritesBase/other/showdown/$id.gif';

String bwAnimatedGifUrlFor(int id) =>
    '$pokeApiSpritesBase/versions/generation-v/black-white/animated/$id.gif';

String bwAnimatedShinyGifUrlFor(int id) =>
    '$pokeApiSpritesBase/versions/generation-v/black-white/animated/shiny'
    '/$id.gif';

/// Shiny animated candidates. Callers append the normal chain afterwards so
/// a missing shiny asset degrades to the regular look instead of a blank.
List<String> animatedShinySpriteCandidatesFor(int id) => [
  showdownGifUrlFor(id, shiny: true),
  if (id <= bwAnimatedMaxId) bwAnimatedShinyGifUrlFor(id),
];

/// Own-CDN animated GIF (seeded per release for the starters; a fast 404
/// falls through for everyone else).
String cdnAnimatedGifUrlFor(int id) =>
    '${DexCdnConfig.cdnBase}/${DexCdnConfig.bundleVersionPrefix}'
    '/sprites/animated/$id.gif';

/// Own-CDN static sprite — already hosted for every species.
String cdnStaticSpriteUrlFor(int id) =>
    '${DexCdnConfig.cdnBase}/${DexCdnConfig.bundleVersionPrefix}'
    '/sprites/$id.png';

/// Animated sprite candidates, best first: own CDN (starters seeded, fast
/// and reachable without GitHub) → Showdown → BW animated → static.
/// Callers fall through on load errors.
List<String> animatedSpriteCandidatesFor(int id) => [
  cdnAnimatedGifUrlFor(id),
  showdownGifUrlFor(id),
  if (id <= bwAnimatedMaxId) bwAnimatedGifUrlFor(id),
  cdnStaticSpriteUrlFor(id),
  defaultSpriteUrlFor(id),
];

/// PokeAPI cries repo (OGG). `latest` covers every species.
String cryUrlFor(int id) =>
    'https://raw.githubusercontent.com/PokeAPI/cries/main'
    '/cries/pokemon/latest/$id.ogg';

/// Own-CDN cry (seeded alongside the starter GIFs).
String cdnCryUrlFor(int id) =>
    '${DexCdnConfig.cdnBase}/${DexCdnConfig.bundleVersionPrefix}'
    '/cries/$id.ogg';

/// Cry candidates, best first — same CDN-first strategy as the sprites.
List<String> cryCandidatesFor(int id) => [cdnCryUrlFor(id), cryUrlFor(id)];

/// Build the full per-generation picker for one Pokémon from known PokeAPI
/// repo URL patterns, filtered by each folder's id ceiling. CDN URLs in
/// [cdnUrlsByVersion] (future bundles) override the GitHub fallback.
List<SpriteEditionOption> spriteEditionOptionsForPokemon(
  int id, {
  Map<String, String>? cdnUrlsByVersion,
  String? fallbackSpriteUrl,
}) {
  final options = <SpriteEditionOption>[];
  final seen = <String>{};

  void add(
    String versionGroup,
    String labelZh,
    int generation,
    String url, {
    String? animatedUrl,
  }) {
    if (!seen.add(versionGroup)) {
      return;
    }
    options.add(
      SpriteEditionOption(
        versionGroup: versionGroup,
        generation: generation,
        editionLabelZh: labelZh,
        spriteUrl: url,
        animatedUrl: animatedUrl,
      ),
    );
  }

  final byVersion = cdnUrlsByVersion ?? const {};
  for (final source in _versionSpriteSources) {
    final url =
        byVersion[source.versionGroup] ??
        (id <= source.maxId
            ? '$pokeApiSpritesBase/versions/${source.folder}/$id.png'
            : null);
    if (url == null) {
      continue;
    }
    add(
      source.versionGroup,
      editionShortLabelForVersionGroup(source.versionGroup),
      kSpriteVersionGroupGeneration[source.versionGroup] ?? 9,
      url,
      animatedUrl:
          source.versionGroup == 'black-white' && id <= bwAnimatedMaxId
          ? bwAnimatedGifUrlFor(id)
          : null,
    );
  }

  // CDN-only entries for version groups without a GitHub folder.
  for (final entry in byVersion.entries) {
    add(
      entry.key,
      editionShortLabelForVersionGroup(entry.key),
      kSpriteVersionGroupGeneration[entry.key] ?? 9,
      entry.value,
    );
  }

  // Cross-game sources — always available regardless of generation.
  add(
    'default',
    '默认',
    spriteGenerationUniversal,
    fallbackSpriteUrl ?? defaultSpriteUrlFor(id),
  );
  add('home', 'HOME', spriteGenerationUniversal, homeSpriteUrlFor(id));
  add(
    'official-artwork',
    '官方绘图',
    spriteGenerationUniversal,
    officialArtworkUrlFor(id),
  );
  add(
    'showdown',
    'Showdown 动图',
    spriteGenerationUniversal,
    showdownGifUrlFor(id),
    animatedUrl: showdownGifUrlFor(id),
  );

  return options;
}

/// Group [options] by generation for section headers in the picker UI.
Map<int, List<SpriteEditionOption>> groupSpriteOptionsByGeneration(
  List<SpriteEditionOption> options,
) {
  final grouped = <int, List<SpriteEditionOption>>{};
  for (final option in options) {
    grouped.putIfAbsent(option.generation, () => []).add(option);
  }
  return Map.fromEntries(
    grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}
