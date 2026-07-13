import 'package:flutter/material.dart';

import '../features/dex/dex_filter.dart';
import '../l10n/app_zh.dart';
import '../theme/secondary_typography.dart';
import 'sticker_card.dart';

/// Reference drill-down filter banner for [DexPage].
class DexFilterBanner extends StatelessWidget {
  const DexFilterBanner({
    super.key,
    required this.filter,
    required this.onClear,
    this.loading = false,
  });

  final DexFilter filter;
  final VoidCallback onClear;
  final bool loading;

  String get _label {
    if (filter.labelZh != null && filter.labelZh!.isNotEmpty) {
      return filter.labelZh!;
    }
    if (filter.learnsMoveId != null) {
      return AppZh.dexFilterByMove('#${filter.learnsMoveId}');
    }
    if (filter.abilityId != null) {
      return AppZh.dexFilterByAbility('#${filter.abilityId}');
    }
    if (filter.eggGroupSlug != null) {
      return AppZh.dexFilterByEggGroup(filter.eggGroupSlug!);
    }
    return AppZh.dexFilterActive;
  }

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      variant: StickerVariant.sky,
      child: Row(
        children: [
          if (loading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Expanded(
            child: Text(
              _label,
              style: SecondaryTypography.onCard.body14.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: loading ? null : onClear,
            child: Text(
              AppZh.dexFilterClear,
              style: SecondaryTypography.onCard.small12.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
