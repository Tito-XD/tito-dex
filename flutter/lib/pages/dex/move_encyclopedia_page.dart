import 'package:flutter/material.dart';

import '../../features/dex/dex_models.dart';
import '../../features/dex/dex_repository.dart';
import '../../features/dex/type_chart.dart';
import '../../l10n/app_zh.dart';
import 'dex_reference_list.dart';

class MoveEncyclopediaPage extends StatelessWidget {
  const MoveEncyclopediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DexReferenceListPage<CachedMove>(
      title: AppZh.dexReferenceMoves,
      loadEntries: dexRepository.getAllMoves,
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
