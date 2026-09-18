import '../dex/dex_models.dart';

/// Never borrow another game's learnset for a battle selection.
List<CachedMove> battleLearnset(PokemonDetail? detail, String versionGroup) {
  if (detail == null) return const [];
  final (source, set) = detail.resolvedMoveSetForKey(versionGroup);
  if (source != versionGroup) return const [];
  return {
    for (final row in [
      ...set.levelUp,
      ...set.machine,
      ...set.egg,
      ...set.tutor,
    ])
      row.move.id: row.move,
  }.values.toList();
}
