import '../game/game_edition.dart';
import 'dex_cdn_config.dart';
import 'sprite_version_existence.g.dart';

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
    this.backSpriteUrl,
    this.animatedBackUrl,
    this.isOfficialArtwork = false,
  });

  final String versionGroup;
  final int generation;
  final String editionLabelZh;
  final String spriteUrl;
  final String? animatedUrl;
  final String? backSpriteUrl;
  final String? animatedBackUrl;
  final bool isOfficialArtwork;

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
        isOfficialArtwork: url.contains('/official-artwork/'),
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

  if (options.isEmpty &&
      fallbackSpriteUrl != null &&
      fallbackSpriteUrl.isNotEmpty) {
    options.add(
      SpriteEditionOption(
        versionGroup: 'default',
        generation: 9,
        editionLabelZh: '默认',
        spriteUrl: fallbackSpriteUrl,
        animatedUrl: animatedSpriteUrl,
        isOfficialArtwork: fallbackSpriteUrl.contains('/official-artwork/'),
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
    'https://raw.githubusercontent.com/PokeAPI/sprites/'
    '$kSpriteExistenceSourceCommit/sprites/pokemon';

/// Gen V black-white animated GIFs exist for ids 1–649.
const int bwAnimatedMaxId = 649;

class _VersionSpriteSource {
  const _VersionSpriteSource(this.versionGroup, this.folder);

  /// PokeAPI version-group slug.
  final String versionGroup;

  /// Folder under `sprites/pokemon/versions/`.
  final String folder;
}

/// Version groups with real per-game sprite folders in the PokeAPI repo.
/// Unsupported games are covered only by the cross-game HOME / Showdown /
/// default sources below; BDSP and Scarlet/Violet have exact sparse folders.
const List<_VersionSpriteSource> _versionSpriteSources = [
  _VersionSpriteSource('red-blue', 'generation-i/red-blue'),
  _VersionSpriteSource('yellow', 'generation-i/yellow'),
  _VersionSpriteSource('gold-silver', 'generation-ii/gold'),
  _VersionSpriteSource('crystal', 'generation-ii/crystal'),
  _VersionSpriteSource('ruby-sapphire', 'generation-iii/ruby-sapphire'),
  _VersionSpriteSource('emerald', 'generation-iii/emerald'),
  _VersionSpriteSource('firered-leafgreen', 'generation-iii/firered-leafgreen'),
  _VersionSpriteSource('diamond-pearl', 'generation-iv/diamond-pearl'),
  _VersionSpriteSource('platinum', 'generation-iv/platinum'),
  _VersionSpriteSource(
    'heartgold-soulsilver',
    'generation-iv/heartgold-soulsilver',
  ),
  _VersionSpriteSource('black-white', 'generation-v/black-white'),
  _VersionSpriteSource('x-y', 'generation-vi/x-y'),
  _VersionSpriteSource(
    'omega-ruby-alpha-sapphire',
    'generation-vi/omegaruby-alphasapphire',
  ),
  _VersionSpriteSource(
    'ultra-sun-ultra-moon',
    'generation-vii/ultra-sun-ultra-moon',
  ),
  _VersionSpriteSource(
    'brilliant-diamond-shining-pearl',
    'generation-viii/brilliant-diamond-shining-pearl',
  ),
  _VersionSpriteSource('scarlet-violet', 'generation-ix/scarlet-violet'),
];

/// National-dex debut cap per version group. Mirrors
/// ``VERSION_GROUP_MAX_ID`` in tools/build_dex_bundle.py. Used to stop
/// PokeAPI's placeholder URLs for generations a species predates from
/// appearing in the edition picker.
const Map<String, int> kSpriteVersionGroupMaxId = {
  'red-blue': 151,
  'yellow': 151,
  'gold-silver': 251,
  'crystal': 251,
  'ruby-sapphire': 386,
  'emerald': 386,
  'firered-leafgreen': 386,
  'diamond-pearl': 493,
  'platinum': 493,
  'heartgold-soulsilver': 493,
  'black-white': 649,
  'black-2-white-2': 649,
  'x-y': 721,
  'omega-ruby-alpha-sapphire': 721,
  'sun-moon': 809,
  'ultra-sun-ultra-moon': 809,
  'lets-go-pikachu-lets-go-eevee': 809,
  'sword-shield': 905,
  'brilliant-diamond-shining-pearl': 905,
  'legends-arceus': 905,
  'scarlet-violet': 1025,
  'legends-za': 1025,
  'mega-dimension': 1025,
};

bool _idInRanges(Map<String, List<int>> rangesByVersion, String group, int id) {
  final ranges = rangesByVersion[group];
  if (ranges == null || id <= 0) return false;
  for (var index = 0; index + 1 < ranges.length; index += 2) {
    if (id >= ranges[index] && id <= ranges[index + 1]) return true;
  }
  return false;
}

/// Whether the exact official PokeAPI/sprites Git tree contains this asset.
///
/// The national-id cap is still required because that repository contains a
/// handful of retro-style community sprites for species introduced later; a
/// file alone does not prove that the Pokémon existed in that game.
bool spriteVersionHasFront(String versionGroup, int id) {
  final cap = kSpriteVersionGroupMaxId[versionGroup];
  return (cap == null || id > 1025 || id <= cap) &&
      _idInRanges(kSpriteFrontIdRanges, versionGroup, id);
}

bool spriteVersionHasBack(String versionGroup, int id) {
  final cap = kSpriteVersionGroupMaxId[versionGroup];
  return (cap == null || id > 1025 || id <= cap) &&
      _idInRanges(kSpriteBackIdRanges, versionGroup, id);
}

bool spriteVersionHasAnimatedFront(String versionGroup, int id) {
  final cap = kSpriteVersionGroupMaxId[versionGroup];
  return (cap == null || id > 1025 || id <= cap) &&
      _idInRanges(kSpriteAnimatedFrontIdRanges, versionGroup, id);
}

bool spriteVersionHasAnimatedBack(String versionGroup, int id) {
  final cap = kSpriteVersionGroupMaxId[versionGroup];
  return (cap == null || id > 1025 || id <= cap) &&
      _idInRanges(kSpriteAnimatedBackIdRanges, versionGroup, id);
}

String defaultSpriteUrlFor(int id) => '$pokeApiSpritesBase/$id.png';

String shinySpriteUrlFor(int id) => '$pokeApiSpritesBase/shiny/$id.png';

String officialArtworkUrlFor(int id) =>
    '$pokeApiSpritesBase/other/official-artwork/$id.png';

String shinyOfficialArtworkUrlFor(int id) =>
    '$pokeApiSpritesBase/other/official-artwork/shiny/$id.png';

String homeSpriteUrlFor(int id) => '$pokeApiSpritesBase/other/home/$id.png';

String showdownGifUrlFor(int id, {bool shiny = false}) => shiny
    ? '$pokeApiSpritesBase/other/showdown/shiny/$id.gif'
    : '$pokeApiSpritesBase/other/showdown/$id.gif';

String bwAnimatedGifUrlFor(int id) =>
    '$pokeApiSpritesBase/versions/generation-v/black-white/animated/$id.gif';

String bwAnimatedBackGifUrlFor(int id) =>
    '$pokeApiSpritesBase/versions/generation-v/black-white/animated/back/$id.gif';

/// Back sprite for a version group with a real back folder, or null.
String? pokeApiBackSpriteUrlFor(String versionGroup, int id) {
  for (final source in _versionSpriteSources) {
    if (source.versionGroup == versionGroup &&
        spriteVersionHasBack(versionGroup, id)) {
      return '$pokeApiSpritesBase/versions/${source.folder}/back/$id.png';
    }
  }
  return null;
}

String? pokeApiAnimatedSpriteUrlFor(String versionGroup, int id) {
  for (final source in _versionSpriteSources) {
    if (source.versionGroup == versionGroup &&
        spriteVersionHasAnimatedFront(versionGroup, id)) {
      return '$pokeApiSpritesBase/versions/${source.folder}/animated/$id.gif';
    }
  }
  return null;
}

String? pokeApiAnimatedBackSpriteUrlFor(String versionGroup, int id) {
  for (final source in _versionSpriteSources) {
    if (source.versionGroup == versionGroup &&
        spriteVersionHasAnimatedBack(versionGroup, id)) {
      return '$pokeApiSpritesBase/versions/${source.folder}'
          '/animated/back/$id.gif';
    }
  }
  return null;
}

String bwAnimatedShinyGifUrlFor(int id) =>
    '$pokeApiSpritesBase/versions/generation-v/black-white/animated/shiny'
    '/$id.gif';

/// Shiny variant of a PokeAPI sprite URL — inserts the `shiny/` folder
/// before the filename. Returns null when the source has no shiny
/// counterpart: own-CDN copies, non-PokeAPI URLs, and Gen I games (shiny
/// colors only exist from Gen II on).
String? shinySpriteVariantUrl(String url) {
  if (!url.startsWith(pokeApiSpritesBase)) {
    return null;
  }
  if (url.contains('/red-blue/') || url.contains('/yellow/')) {
    return null;
  }
  if (url.contains('/shiny/')) {
    return url;
  }
  final slash = url.lastIndexOf('/');
  if (slash < 0) {
    return null;
  }
  return '${url.substring(0, slash)}/shiny${url.substring(slash)}';
}

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

/// Pre-Gen-V-style cry retained by the official PokeAPI cries repository.
/// The legacy collection currently covers National Dex ids 1–905.
String? legacyCryUrlFor(int id) => id <= 905
    ? 'https://raw.githubusercontent.com/PokeAPI/cries/main'
          '/cries/pokemon/legacy/$id.ogg'
    : null;

/// Own-CDN cry (seeded alongside the starter GIFs).
String cdnCryUrlFor(int id) =>
    '${DexCdnConfig.cdnBase}/${DexCdnConfig.bundleVersionPrefix}'
    '/cries/$id.ogg';

/// Cry candidates, best first — same CDN-first strategy as the sprites.
List<String> cryCandidatesFor(int id) => [cdnCryUrlFor(id), cryUrlFor(id)];

/// Build the per-generation picker from exact files in PokeAPI/sprites.
///
/// [cdnUrlsByVersion] remains in the signature for old bundle models, but the
/// current v18 values are synthetic `/sprites/by-version/` URLs with no stored
/// objects behind them. They must not override a verified GitHub file or add an
/// unsupported game slot, otherwise the CDN Worker falls back to the same
/// default sprite for every row.
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
    String? backSpriteUrl,
    String? animatedBackUrl,
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
        backSpriteUrl: backSpriteUrl,
        animatedBackUrl: animatedBackUrl,
        isOfficialArtwork:
            versionGroup == 'official-artwork' ||
            url.contains('/official-artwork/'),
      ),
    );
  }

  for (final source in _versionSpriteSources) {
    // Form ids live above the national range. Their detail map was already
    // filtered by the form's introduction and in-game availability during the
    // bundle build, so keep it as an allow-list. The raw upstream folders also
    // contain retro-style community backfills that are not historical proof.
    if (id > 1025 &&
        !(cdnUrlsByVersion?.containsKey(source.versionGroup) ?? false)) {
      continue;
    }
    if (!spriteVersionHasFront(source.versionGroup, id)) continue;
    final url = '$pokeApiSpritesBase/versions/${source.folder}/$id.png';
    add(
      source.versionGroup,
      editionShortLabelForVersionGroup(source.versionGroup),
      kSpriteVersionGroupGeneration[source.versionGroup] ?? 9,
      url,
      animatedUrl: pokeApiAnimatedSpriteUrlFor(source.versionGroup, id),
      backSpriteUrl: pokeApiBackSpriteUrlFor(source.versionGroup, id),
      animatedBackUrl: pokeApiAnimatedBackSpriteUrlFor(source.versionGroup, id),
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
