import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/features/dex/dex_game_scope.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_scope.dart';
import 'package:titodex/features/game/game_edition.dart';
import 'package:titodex/models/journey.dart';

PokemonSummary _summary({
  required int id,
  Map<String, int>? pokedexNumbers,
}) {
  return PokemonSummary(
    id: id,
    nameEn: 'Species$id',
    nameZh: '宝可梦$id',
    types: const ['normal'],
    pokedexNumbers: pokedexNumbers,
  );
}

void main() {
  group('DexScope.defaultForJourney', () {
    test('returns HGSS johto default regional scope', () {
      final scope = DexScope.defaultForJourney(CurrentJourney.mock());

      expect(scope.gameVersion, DexGameVersion.hgss);
      expect(scope.gameEdition.slug, 'hgss');
      expect(scope.regionalScope, DexRegionalPokedex.johto);
      expect(scope.label, contains('城都'));
    });
  });

  group('DexScope.regionalNumberFor', () {
    test('national scope returns national id', () {
      const scope = DexScope();
      final summary = _summary(id: 25);

      expect(scope.regionalNumberFor(summary), 25);
    });

    test('johto scope prefers CDN pokedexNumbers', () {
      const scope = DexScope(regionalScope: DexRegionalPokedex.johto);
      final summary = _summary(
        id: 155,
        pokedexNumbers: const {'original-johto': 4},
      );

      expect(scope.regionalNumberFor(summary), 4);
    });

    test('johto scope falls back to HGSS national range offset', () {
      const scope = DexScope(regionalScope: DexRegionalPokedex.johto);
      final summary = _summary(id: 155);

      expect(scope.regionalNumberFor(summary), 4);
    });
  });

  group('DexScope.speciesInScope', () {
    test('national scope accepts ids up to titodexMaxNationalDexId', () {
      const scope = DexScope();

      expect(scope.speciesInScope(_summary(id: 1)), isTrue);
      expect(scope.speciesInScope(_summary(id: titodexMaxNationalDexId)), isTrue);
      expect(scope.speciesInScope(_summary(id: titodexMaxNationalDexId + 1)), isFalse);
    });

    test('johto scope filters via pokedexNumbers', () {
      const scope = DexScope(regionalScope: DexRegionalPokedex.johto);

      expect(
        scope.speciesInScope(
          _summary(id: 900, pokedexNumbers: const {'original-johto': 200}),
        ),
        isTrue,
      );
      expect(scope.speciesInScope(_summary(id: 900)), isFalse);
    });

    test('johto scope accepts HGSS national fallback ids', () {
      const scope = DexScope(regionalScope: DexRegionalPokedex.johto);

      expect(scope.speciesInScope(_summary(id: 155)), isTrue);
      expect(scope.speciesInScope(_summary(id: 151)), isFalse);
    });

    test('kanto scope accepts HGSS national fallback ids', () {
      const scope = DexScope(regionalScope: DexRegionalPokedex.kanto);

      expect(scope.speciesInScope(_summary(id: 25)), isTrue);
      expect(scope.speciesInScope(_summary(id: 152)), isFalse);
    });
  });

  group('DexScope.idRangeForScope', () {
    test('national browse range spans 1..1025', () {
      expect(
        DexScope.idRangeForScope(DexRegionalPokedex.national),
        (1, titodexMaxNationalDexId),
      );
    });

    test('HGSS johto/kanto still expose national id ranges', () {
      expect(
        DexScope.idRangeForScope(
          DexRegionalPokedex.johto,
          gameEdition: GameEdition.hgss,
        ),
        (152, 251),
      );
      expect(
        DexScope.idRangeForScope(
          DexRegionalPokedex.kanto,
          gameEdition: GameEdition.hgss,
        ),
        (1, 151),
      );
    });
  });
}
