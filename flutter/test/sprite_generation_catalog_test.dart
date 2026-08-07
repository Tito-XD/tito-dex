import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/sprite_generation_catalog.dart';

void main() {
  test('spriteEditionOptions groups known version groups with Gen labels', () {
    final options = spriteEditionOptions(
      spriteUrlsByVersion: const {
        'heartgold-soulsilver': 'https://cdn/hgss.png',
        'scarlet-violet': 'https://cdn/sv.png',
      },
      animatedSpriteUrl: 'https://cdn/anim.gif',
    );

    expect(options, hasLength(2));
    expect(options.first.generationLabel, 'Gen IV');
    expect(options.last.generationLabel, 'Gen IX');
    expect(options.last.animatedUrl, 'https://cdn/anim.gif');
  });

  test('generationRomanLabel uses Roman numerals', () {
    expect(generationRomanLabel(1), 'Gen I');
    expect(generationRomanLabel(9), 'Gen IX');
    expect(generationRomanLabel(spriteGenerationUniversal), '通用');
  });

  group('spriteEditionOptionsForPokemon', () {
    test('Pikachu (25) covers every per-version folder plus universal', () {
      final options = spriteEditionOptionsForPokemon(25);
      final groups = options.map((o) => o.versionGroup).toList();

      expect(groups, contains('red-blue'));
      expect(groups, contains('yellow'));
      expect(groups, contains('heartgold-soulsilver'));
      expect(groups, contains('ultra-sun-ultra-moon'));
      expect(groups, contains('default'));
      expect(groups, contains('home'));
      expect(groups, contains('official-artwork'));
      expect(groups, contains('showdown'));

      final rb = options.firstWhere((o) => o.versionGroup == 'red-blue');
      expect(
        rb.spriteUrl,
        '$pokeApiSpritesBase/versions/generation-i/red-blue/25.png',
      );
    });

    test('id ceilings hide folders that predate the species', () {
      // Riolu (#447) debuted in Gen IV.
      final options = spriteEditionOptionsForPokemon(447);
      final groups = options.map((o) => o.versionGroup).toSet();

      expect(groups.contains('red-blue'), isFalse);
      expect(groups.contains('crystal'), isFalse);
      expect(groups.contains('emerald'), isFalse);
      expect(groups, contains('diamond-pearl'));
      expect(groups, contains('heartgold-soulsilver'));
    });

    test('Gen IX species only get universal sources', () {
      final options = spriteEditionOptionsForPokemon(1000);
      final generations = options.map((o) => o.generation).toSet();
      expect(generations, {spriteGenerationUniversal});
    });

    test('black-white carries the animated GIF within the BW ceiling', () {
      final bw = spriteEditionOptionsForPokemon(
        6,
      ).firstWhere((o) => o.versionGroup == 'black-white');
      expect(bw.animatedUrl, bwAnimatedGifUrlFor(6));

      final beyond = spriteEditionOptionsForPokemon(700).firstWhere(
        (o) => o.versionGroup == 'black-white',
        orElse: () {
          return const SpriteEditionOption(
            versionGroup: 'absent',
            generation: 0,
            editionLabelZh: '',
            spriteUrl: '',
          );
        },
      );
      expect(beyond.versionGroup, 'absent');
    });

    test('CDN URLs override the GitHub fallback per version group', () {
      final options = spriteEditionOptionsForPokemon(
        25,
        cdnUrlsByVersion: const {'yellow': 'https://cdn/yellow-25.png'},
      );
      final yellow = options.firstWhere((o) => o.versionGroup == 'yellow');
      expect(yellow.spriteUrl, 'https://cdn/yellow-25.png');
    });

    test('animated candidates prefer CDN then fall back to public sources', () {
      expect(animatedSpriteCandidatesFor(25), [
        cdnAnimatedGifUrlFor(25),
        showdownGifUrlFor(25),
        bwAnimatedGifUrlFor(25),
        cdnStaticSpriteUrlFor(25),
        defaultSpriteUrlFor(25),
      ]);
      expect(animatedSpriteCandidatesFor(1000), [
        cdnAnimatedGifUrlFor(1000),
        showdownGifUrlFor(1000),
        cdnStaticSpriteUrlFor(1000),
        defaultSpriteUrlFor(1000),
      ]);
    });

    test('back sprites exist for Gen I/II/IV/V folders and BW animation', () {
      expect(
        pokeApiBackSpriteUrlFor('black-white', 25),
        '$pokeApiSpritesBase/versions/generation-v/black-white/back/25.png',
      );
      expect(
        pokeApiBackSpriteUrlFor('red-blue', 25),
        '$pokeApiSpritesBase/versions/generation-i/red-blue/back/25.png',
      );
      expect(pokeApiBackSpriteUrlFor('x-y', 25), isNull);
      expect(pokeApiBackSpriteUrlFor('emerald', 25), isNull);
      expect(
        bwAnimatedBackGifUrlFor(25),
        '$pokeApiSpritesBase/versions/generation-v/black-white'
        '/animated/back/25.gif',
      );
    });

    test('per-version options expose back URLs where available', () {
      final options = spriteEditionOptionsForPokemon(25);
      final bw = options.firstWhere((o) => o.versionGroup == 'black-white');
      expect(bw.backSpriteUrl, isNotNull);
      expect(bw.animatedBackUrl, bwAnimatedBackGifUrlFor(25));

      final xy = options.firstWhere((o) => o.versionGroup == 'x-y');
      expect(xy.backSpriteUrl, isNull);
      expect(xy.animatedBackUrl, isNull);
    });

    test('pre-debut generations are not offered for Gen IV species', () {
      // Pachirisu (#417) debuted in Gen IV.
      final options = spriteEditionOptionsForPokemon(417);
      final groups = options.map((o) => o.versionGroup).toSet();

      expect(groups.contains('red-blue'), isFalse);
      expect(groups.contains('yellow'), isFalse);
      expect(groups.contains('gold-silver'), isFalse);
      expect(groups.contains('crystal'), isFalse);
      expect(groups.contains('ruby-sapphire'), isFalse);
      expect(groups.contains('emerald'), isFalse);
      expect(groups.contains('firered-leafgreen'), isFalse);
      expect(groups, contains('diamond-pearl'));
      expect(groups, contains('platinum'));
      expect(groups, contains('heartgold-soulsilver'));
      expect(groups, contains('black-white'));
    });

    test('Gen IX species only keep Gen IX CDN groups from a full map', () {
      // Gholdengo (#1000) exists only in Scarlet/Violet.
      final options = spriteEditionOptionsForPokemon(
        1000,
        cdnUrlsByVersion: const {
          'red-blue': 'https://cdn/1.png',
          'gold-silver': 'https://cdn/2.png',
          'diamond-pearl': 'https://cdn/4.png',
          'black-white': 'https://cdn/5.png',
          'x-y': 'https://cdn/6.png',
          'sun-moon': 'https://cdn/7.png',
          'sword-shield': 'https://cdn/8.png',
          'brilliant-diamond-shining-pearl': 'https://cdn/8b.png',
          'legends-arceus': 'https://cdn/8c.png',
          'scarlet-violet': 'https://cdn/9.png',
        },
      );
      final groups = options.map((o) => o.versionGroup).toSet();
      expect(groups, contains('scarlet-violet'));
      expect(groups.contains('red-blue'), isFalse);
      expect(groups.contains('sword-shield'), isFalse);
      expect(groups.contains('legends-arceus'), isFalse);
      expect(groups.contains('diamond-pearl'), isFalse);
      expect(groups, contains('default'));
    });
  });
}
