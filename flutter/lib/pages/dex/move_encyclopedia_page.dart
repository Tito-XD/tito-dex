import 'package:flutter/material.dart';

import '../../features/dex/dex_models.dart';
import '../../features/dex/dex_repository.dart';
import '../../features/dex/type_chart.dart';
import '../../features/dex/reference_game_scope.dart';
import '../../features/dex/move_version_data.dart';
import '../../features/game/game_edition_repository.dart';
import '../../l10n/app_zh.dart';
import 'dex_reference_list.dart';

class MoveEncyclopediaPage extends StatelessWidget {
  const MoveEncyclopediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final edition = gameEditionRepository.edition;
    return DexReferenceListPage<CachedMove>(
      key: ValueKey('moves:${edition.slug}:${edition.selectedFlavor}'),
      title: AppZh.dexReferenceMoves,
      subtitle: edition.labelZh,
      loadEntries: () async {
        final results = await (
          dexRepository.getAllMoves(),
          moveVersionDataRepository.load(),
        ).wait;
        final targetHasMatrixCoverage = moveVersionDataRepository
            .knownVersionGroups
            .contains(edition.dataVersionGroupKey);
        return results.$1
            .where(
              (move) => cachedMoveAvailableInEdition(
                move,
                edition,
                indexedVersionGroups: targetHasMatrixCoverage
                    ? results.$2[move.id] ?? const <String>{}
                    : null,
                exactCoverageKnown: targetHasMatrixCoverage,
              ),
            )
            .toList(growable: false);
      },
      filterEntry: filterCachedMove,
      primaryLabel: (move) => move.nameZh,
      secondaryLabel: (move) =>
          '#${move.id} · ${typeNameZh(move.type)} · ${move.category}',
      detailSheet: showMoveDetailSheet,
      categoryFilter: moveTypeCategoryFilter,
    );
  }
}

/// The move reference keeps type filtering deliberately lightweight: one
/// horizontal row using the canonical 18-type order, intersected with the
/// existing text query by [DexReferenceListPage].
final moveTypeCategoryFilter = DexReferenceCategoryFilter<CachedMove>(
  options: <String?>[null, ...typeNamesZh.values],
  label: (move) => typeNameZh(move.type),
  filter: (move, typeZh) => typeNameZh(move.type) == typeZh,
);
