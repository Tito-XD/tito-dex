import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/companion/battle_game_scope.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../widgets/handheld_input.dart';
import '../widgets/sticker_card.dart';

class CompanionToolsPanel extends StatelessWidget {
  const CompanionToolsPanel({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  Widget build(BuildContext context) {
    final scope = battleScopeForGame(journey.game);

    return StickerCard(
      variant: StickerVariant.deep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.companionToolsTitle,
            style: SecondaryTypography.onCard.h15,
          ),
          const SizedBox(height: 4),
          Text(
            AppZh.companionToolsSubtitle(localizeGame(journey.game)),
            style: SecondaryTypography.onCard.small12.copyWith(
              color: TitoColors.mutedInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppZh.companionToolsFacility(scope.facilityLabel),
            style: SecondaryTypography.onCard.small12.copyWith(
              color: TitoColors.mutedInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _CompanionToolTile(
            icon: Icons.auto_stories_rounded,
            title: AppZh.companionToolDex,
            subtitle: AppZh.companionToolDexHint,
            onTap: () => context.push('/dex'),
          ),
          const SizedBox(height: 8),
          _CompanionToolTile(
            icon: Icons.bolt_rounded,
            title: AppZh.companionToolTypeMatchup,
            subtitle: AppZh.companionToolTypeMatchupHint,
            onTap: () => context.push('/search/companion/type-matchup'),
          ),
          const SizedBox(height: 8),
          _CompanionToolTile(
            icon: Icons.calculate_rounded,
            title: AppZh.companionToolStatCalc,
            subtitle: AppZh.companionToolStatCalcHint,
            onTap: () => context.push('/search/companion/stat-calc'),
          ),
          const SizedBox(height: 8),
          _CompanionToolTile(
            icon: Icons.flash_on_rounded,
            title: AppZh.companionToolQuickDamage,
            subtitle: AppZh.companionToolQuickDamageHint(scope.facilityLabel),
            onTap: () => context.push('/search/companion/quick-damage'),
          ),
        ],
      ),
    );
  }
}

class _CompanionToolTile extends StatelessWidget {
  const _CompanionToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: TitoColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: TitoColors.ink, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: TitoColors.deepBlue, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: SecondaryTypography.onCard.body14.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: SecondaryTypography.onCard.small12.copyWith(
                          color: TitoColors.mutedInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: TitoColors.mutedInk,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
