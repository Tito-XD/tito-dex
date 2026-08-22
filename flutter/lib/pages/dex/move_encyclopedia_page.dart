import 'package:flutter/material.dart';

import '../../features/dex/dex_models.dart';
import '../../features/dex/dex_repository.dart';
import '../../features/dex/type_chart.dart';
import '../../features/dex/reference_game_scope.dart';
import '../../features/dex/move_version_data.dart';
import '../../features/game/game_edition.dart';
import '../../features/game/game_edition_repository.dart';
import '../../l10n/app_zh.dart';
import 'dex_reference_list.dart';

class MoveEncyclopediaPage extends StatelessWidget {
  const MoveEncyclopediaPage({
    super.key,
    this.initialQuery,
    this.initialEntryId,
    this.openInitialEntry = false,
  });

  final String? initialQuery;
  final int? initialEntryId;
  final bool openInitialEntry;

  @override
  Widget build(BuildContext context) {
    final edition = gameEditionRepository.edition;
    var matrix = const <int, Set<String>>{};
    var exactCoverageKnown = false;
    return DexReferenceListPage<CachedMove>(
      key: ValueKey('moves:${edition.slug}:${edition.selectedFlavor}'),
      title: AppZh.dexReferenceMoves,
      subtitle: edition.labelZh,
      loadEntries: () async {
        final results = await (
          dexRepository.getAllMoves(),
          moveVersionDataRepository.load(),
        ).wait;
        matrix = results.$2;
        exactCoverageKnown = moveVersionDataRepository.knownVersionGroups
            .contains(edition.dataVersionGroupKey);
        return results.$1;
      },
      includeEntry: (move) => cachedMoveAvailableInEdition(
        move,
        edition,
        indexedVersionGroups: exactCoverageKnown
            ? matrix[move.id] ?? const <String>{}
            : null,
        exactCoverageKnown: exactCoverageKnown,
      ),
      scopeNotice: (move) => moveScopeNotice(
        move,
        edition,
        indexedVersionGroups: exactCoverageKnown
            ? matrix[move.id] ?? const <String>{}
            : null,
        exactCoverageKnown: exactCoverageKnown,
      ),
      filterEntry: filterCachedMove,
      primaryLabel: (move) => move.nameZh,
      secondaryLabel: (move) =>
          '#${move.id} · ${typeNameZh(move.type)} · ${move.category}',
      detailSheet: showMoveDetailSheet,
      scopedDetailSheet: (context, move, notice) =>
          showMoveDetailSheet(context, move, scopeNotice: notice),
      categoryFilter: moveTypeCategoryFilter,
      initialQuery: initialQuery,
      initialEntryId: initialEntryId,
      openInitialEntry: openInitialEntry,
      entryId: (move) => move.id,
    );
  }
}

String? moveScopeNotice(
  CachedMove move,
  GameEdition edition, {
  Set<String>? indexedVersionGroups,
  required bool exactCoverageKnown,
}) {
  if (!cachedMoveAvailableInEdition(
    move,
    edition,
    indexedVersionGroups: indexedVersionGroups,
    exactCoverageKnown: exactCoverageKnown,
  )) {
    return AppZh.dexReferenceUnavailableInGame;
  }
  if (!exactCoverageKnown && move.availableVersionGroups.isEmpty) {
    return AppZh.dexReferenceScopeUnknown;
  }
  return null;
}

/// The move reference keeps type filtering deliberately lightweight: one
/// horizontal row using the canonical 18-type order, intersected with the
/// existing text query by [DexReferenceListPage].
final moveTypeCategoryFilter = DexReferenceCategoryFilter<CachedMove>(
  options: <String?>[null, ...typeNamesZh.values],
  label: (move) => typeNameZh(move.type),
  filter: (move, typeZh) => typeNameZh(move.type) == typeZh,
);
