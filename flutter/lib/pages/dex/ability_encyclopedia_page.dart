import 'package:flutter/material.dart';

import '../../features/dex/dex_models.dart';
import '../../features/dex/dex_repository.dart';
import '../../l10n/app_zh.dart';
import 'dex_reference_list.dart';

class AbilityEncyclopediaPage extends StatelessWidget {
  const AbilityEncyclopediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DexReferenceListPage<CachedAbility>(
      title: AppZh.dexReferenceAbilities,
      loadEntries: dexRepository.getAllAbilities,
      filterEntry: filterCachedAbility,
      primaryLabel: (ability) => ability.nameZh,
      secondaryLabel: (ability) => '#${ability.id} · ${ability.nameEn}',
      detailSheet: showAbilityDetailSheet,
    );
  }
}
