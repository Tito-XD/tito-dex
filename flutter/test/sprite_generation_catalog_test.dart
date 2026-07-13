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
  });
}
