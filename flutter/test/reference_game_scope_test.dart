import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/reference_game_scope.dart';
import 'package:titodex/features/dex/move_version_data.dart';
import 'package:titodex/features/game/game_edition.dart';
import 'package:titodex/widgets/dex_reference_detail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('moves and abilities are hidden before their debut generation', () {
    const lateMove = CachedMove(
      id: 800,
      nameEn: 'late-move',
      nameZh: '后期招式',
      type: 'normal',
      category: 'physical',
    );
    const lateAbility = CachedAbility(
      id: 200,
      nameEn: 'late-ability',
      nameZh: '后期特性',
      descriptionZh: '',
    );

    expect(cachedMoveAvailableInEdition(lateMove, GameEdition.hgss), isFalse);
    expect(
      cachedMoveAvailableInEdition(lateMove, gameEditionFromSlug('swsh')!),
      isTrue,
    );
    expect(
      cachedAbilityAvailableInEdition(lateAbility, GameEdition.hgss),
      isFalse,
    );
  });

  test('exact version-group metadata wins over generation fallback', () {
    const move = CachedMove(
      id: 1,
      nameEn: 'pound',
      nameZh: '拍击',
      type: 'normal',
      category: 'physical',
      availableVersionGroups: ['scarlet-violet'],
    );
    expect(cachedMoveAvailableInEdition(move, GameEdition.hgss), isFalse);
    expect(
      cachedMoveAvailableInEdition(move, gameEditionFromSlug('sv')!),
      isTrue,
    );
  });

  test('bundled matrix catches moves removed from a later game', () async {
    const hiddenPower = CachedMove(
      id: 237,
      nameEn: 'hidden-power',
      nameZh: '觉醒力量',
      type: 'normal',
      category: 'special',
    );
    final matrix = await moveVersionDataRepository.load();

    expect(
      cachedMoveAvailableInEdition(
        hiddenPower,
        GameEdition.hgss,
        indexedVersionGroups: matrix[hiddenPower.id],
      ),
      isTrue,
    );
    expect(
      cachedMoveAvailableInEdition(
        hiddenPower,
        gameEditionFromSlug('swsh')!,
        indexedVersionGroups: matrix[hiddenPower.id],
      ),
      isFalse,
    );
  });

  test('an uncovered future game falls back to debut generation', () {
    const move = CachedMove(
      id: 85,
      nameEn: 'thunderbolt',
      nameZh: '十万伏特',
      type: 'electric',
      category: 'special',
      availableVersionGroups: ['heartgold-soulsilver'],
    );
    expect(
      cachedMoveAvailableInEdition(
        move,
        gameEditionFromSlug('champions')!,
        exactCoverageKnown: false,
      ),
      isTrue,
    );
  });

  test('reference rules gate game-specific mechanics', () {
    expect(
      jsonReferenceAvailableInEdition(DexReferenceKind.nature, const {
        'slug': 'hardy',
      }, gameEditionFromSlug('yellow')!),
      isFalse,
    );
    expect(
      jsonReferenceAvailableInEdition(DexReferenceKind.status, const {
        'slug': 'frostbite',
      }, gameEditionFromSlug('pla')!),
      isTrue,
    );
    expect(
      jsonReferenceAvailableInEdition(DexReferenceKind.status, const {
        'slug': 'frostbite',
      }, gameEditionFromSlug('sv')!),
      isFalse,
    );
  });
}
