import '../game/game_edition.dart';

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

String generationRomanLabel(int generation) {
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
