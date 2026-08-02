import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/widgets/pokemon_obtain_sections.dart';

void main() {
  test('held item rows use Chinese references and exact-version rarity', () {
    const item = PokemonHeldItem(
      slug: 'metal-coat',
      rarityByVersion: {'heartgold': 5, 'soulsilver': 0, 'diamond': 10},
      maxRarity: 10,
    );
    const reference = HeldItemReference(
      slug: 'metal-coat',
      nameZh: '金属膜',
      spriteUrl: '/tmp/metal-coat.png',
    );

    final rows = heldItemDisplayEntries(
      items: const [item],
      versionKeys: const ['heartgold', 'soulsilver'],
      references: const {'metal-coat': reference},
    );

    expect(rows, hasLength(1));
    expect(rows.single.reference.nameZh, '金属膜');
    expect(rows.single.rarities, const {'heartgold': 5});
  });

  test('held item rows hide items unavailable in the selected version', () {
    const item = PokemonHeldItem(
      slug: 'light-ball',
      rarityByVersion: {'diamond': 5},
      maxRarity: 5,
    );

    final rows = heldItemDisplayEntries(
      items: const [item],
      versionKeys: const ['soulsilver'],
    );

    expect(rows, isEmpty);
  });

  test('item references are indexed by slug', () {
    final references = heldItemReferencesBySlug(const [
      {'slug': 'oran-berry', 'nameZh': '橙橙果', 'spriteUrl': '/tmp/oran.png'},
    ]);

    expect(references['oran-berry']?.nameZh, '橙橙果');
  });
}
