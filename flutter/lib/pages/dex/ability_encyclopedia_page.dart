import 'package:flutter/material.dart';

import '../../features/dex/dex_models.dart';
import '../../features/dex/dex_repository.dart';
import '../../features/dex/reference_game_scope.dart';
import '../../features/game/game_edition_repository.dart';
import '../../l10n/app_zh.dart';
import 'dex_reference_list.dart';

class AbilityEncyclopediaPage extends StatelessWidget {
  const AbilityEncyclopediaPage({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  Widget build(BuildContext context) {
    final edition = gameEditionRepository.edition;
    return DexReferenceListPage<CachedAbility>(
      key: ValueKey('abilities:${edition.slug}:${edition.selectedFlavor}'),
      title: AppZh.dexReferenceAbilities,
      subtitle: edition.labelZh,
      loadEntries: () async => (await dexRepository.getAllAbilities())
          .where((ability) => cachedAbilityAvailableInEdition(ability, edition))
          .toList(growable: false),
      filterEntry: filterCachedAbility,
      primaryLabel: (ability) => ability.nameZh,
      secondaryLabel: (ability) => '#${ability.id} · ${ability.nameEn}',
      detailSheet: showAbilityDetailSheet,
      categoryFilter: abilityUsageCategoryFilter,
      initialQuery: initialQuery,
    );
  }
}

/// Group abilities by how broadly they are distributed across species.
/// `pokemonIds` is already part of the cached ability index, so this adds no
/// detail scans or network work.
final abilityUsageCategoryFilter = DexReferenceCategoryFilter<CachedAbility>(
  options: const [null, '专属', '少见', '常见'],
  label: abilityUsageCategoryLabel,
  filter: (ability, category) => abilityUsageCategoryLabel(ability) == category,
);

String abilityUsageCategoryLabel(CachedAbility ability) {
  final count = ability.pokemonIds.length;
  if (count <= 1) {
    return '专属';
  }
  if (count <= 5) {
    return '少见';
  }
  return '常见';
}
