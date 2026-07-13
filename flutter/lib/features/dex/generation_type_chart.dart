/// Generation-specific adjustments to the modern type chart.
library;

import 'type_chart.dart';

/// Types that did not exist before Gen VI.
const kTypesIntroducedGen6 = {'fairy'};

/// Normalize species types for games before Gen VI (strip Fairy, fallback Normal).
List<String> normalizeTypesForGeneration(
  List<String> types,
  int generation,
) {
  if (generation >= 6) {
    return List<String>.from(types);
  }
  final withoutFairy = types.where((t) => t != 'fairy').toList();
  if (withoutFairy.isEmpty && types.contains('fairy')) {
    return const ['normal'];
  }
  return withoutFairy;
}

/// Attack types available in a given generation (no Fairy before Gen VI).
List<String> attackTypesForGeneration(int generation) {
  if (generation >= 6) {
    return typeGridOrder;
  }
  return typeGridOrder.where((t) => !kTypesIntroducedGen6.contains(t)).toList();
}

/// Patch modern PokeAPI relations for pre–Gen VI steel resistances, etc.
Map<String, TypeDamageRelations> typeRelationsForGeneration(
  Map<String, TypeDamageRelations> modern,
  int generation,
) {
  if (generation >= 6) {
    return modern;
  }

  final patched = <String, TypeDamageRelations>{};
  for (final entry in modern.entries) {
    patched[entry.key] = entry.value;
  }

  final steel = patched['steel'];
  if (steel != null) {
    patched['steel'] = TypeDamageRelations(
      doubleDamageTo: steel.doubleDamageTo,
      halfDamageTo: steel.halfDamageTo.difference({'ghost', 'dark'}),
      noDamageTo: steel.noDamageTo,
    );
  }

  return patched;
}
