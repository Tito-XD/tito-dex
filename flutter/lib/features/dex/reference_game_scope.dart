import '../game/game_edition.dart';
import 'dex_models.dart';
import '../../widgets/dex_reference_detail.dart';

bool cachedMoveAvailableInEdition(
  CachedMove move,
  GameEdition edition, {
  Set<String>? indexedVersionGroups,
  bool exactCoverageKnown = true,
}) {
  final exactGroups = <String>{
    ...move.availableVersionGroups,
    ...?indexedVersionGroups,
  };
  // A non-null matrix set means this target game is covered, including the
  // meaningful empty-set case where the move does not exist in that game.
  if (exactCoverageKnown &&
      (indexedVersionGroups != null ||
          move.availableVersionGroups.isNotEmpty)) {
    return exactGroups.contains(edition.dataVersionGroupKey);
  }
  return (move.generation ?? moveGenerationForId(move.id)) <=
      edition.generation;
}

bool cachedAbilityAvailableInEdition(
  CachedAbility ability,
  GameEdition edition,
) {
  if (edition.generation < 3) return false;
  if (ability.availableVersionGroups.isNotEmpty) {
    return ability.availableVersionGroups.contains(edition.dataVersionGroupKey);
  }
  return (ability.generation ?? abilityGenerationForId(ability.id)) <=
      edition.generation;
}

int moveGenerationForId(int id) {
  if (id <= 165) return 1;
  if (id <= 251) return 2;
  if (id <= 354) return 3;
  if (id <= 467) return 4;
  if (id <= 559) return 5;
  if (id <= 621) return 6;
  if (id <= 742) return 7;
  if (id <= 850) return 8;
  return 9;
}

int abilityGenerationForId(int id) {
  if (id <= 77) return 3;
  if (id <= 123) return 4;
  if (id <= 164) return 5;
  if (id <= 191) return 6;
  if (id <= 233) return 7;
  if (id <= 267) return 8;
  return 9;
}

bool jsonReferenceAvailableInEdition(
  DexReferenceKind kind,
  Map<String, dynamic> entry,
  GameEdition edition,
) {
  final generation = edition.generation;
  final explicitGroups =
      (entry['availableVersionGroups'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toSet();
  if (explicitGroups.isNotEmpty) {
    return explicitGroups.contains(edition.dataVersionGroupKey);
  }
  final explicitGeneration = (entry['generation'] as num?)?.toInt();
  if (explicitGeneration != null && explicitGeneration > generation) {
    return false;
  }
  final slug = entry['slug'] as String? ?? '';
  return switch (kind) {
    DexReferenceKind.nature => generation >= 3,
    DexReferenceKind.eggGroup => generation >= 2,
    DexReferenceKind.weather => _weatherGeneration(slug) <= generation,
    DexReferenceKind.terrain => _terrainGeneration(slug) <= generation,
    DexReferenceKind.status => _statusAvailable(slug, edition),
    _ => true,
  };
}

int _weatherGeneration(String slug) => switch (slug) {
  'sun' || 'rain' || 'sandstorm' => 2,
  'hail' => 3,
  'fog' => 4,
  'strong-winds' ||
  'heavy-rain' ||
  'harsh-sunlight' ||
  'strong-winds-primal' => 6,
  'snow' => 9,
  _ => 1,
};

int _terrainGeneration(String slug) => switch (slug) {
  'psychic' => 7,
  _ => 6,
};

bool _statusAvailable(String slug, GameEdition edition) {
  if (slug == 'frostbite' || slug == 'drowsy') {
    return edition.slug == 'pla';
  }
  if (slug == 'yawn') return edition.generation >= 3;
  return true;
}
