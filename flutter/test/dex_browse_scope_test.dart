import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/dex/dex_browse_scope.dart';
import 'package:titodex/features/dex/dex_game_scope.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_settings_repository.dart';

void main() {
  const gen4 = PokemonSummary(
    id: 493,
    nameEn: 'arceus',
    nameZh: '阿尔宙斯',
    types: ['normal'],
    generation: 4,
    pokedexNumbers: {'hisui': 238},
  );

  test('generation scope matches debut generation independently of region', () {
    expect(const DexBrowseScope.generation(4).matches(gen4), isTrue);
    expect(const DexBrowseScope.generation(8).matches(gen4), isFalse);
    expect(
      const DexBrowseScope.region(DexRegionalPokedex.hisui).matches(gen4),
      isTrue,
    );
  });

  test('scope storage values round-trip', () {
    for (final scope in [
      const DexBrowseScope.region(DexRegionalPokedex.johto),
      const DexBrowseScope.generation(9),
    ]) {
      expect(DexBrowseScope.fromStorageValue(scope.storageValue), scope);
    }
    expect(DexBrowseScope.fromStorageValue('generation:10'), isNull);
  });

  test('repository persists generation browse selection', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = DexSettingsRepository();
    const selected = DexBrowseScope.generation(6);

    await repository.saveBrowseScope(selected);

    expect(await repository.loadBrowseScope(), selected);
  });
}
