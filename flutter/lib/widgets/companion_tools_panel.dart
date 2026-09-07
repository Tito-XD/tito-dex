import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/companion/battle_game_scope.dart';
import '../features/game/game_edition_repository.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/app_visual_style.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../widgets/handheld_input.dart';
import '../widgets/sticker_card.dart';
import '../widgets/sticker_pressable.dart';

class CompanionToolsPanel extends StatelessWidget {
  const CompanionToolsPanel({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gameEditionRepository,
      builder: (context, _) {
        final edition = gameEditionRepository.edition;
        final scope = battleScopeForEdition(edition);
        // Secondary route: SecondaryTypography only — onGradient inside the
        // deep card, onCard inside the cream tiles below.
        final subtitle = SecondaryTypography.onGradient.small12.copyWith(
          color: TitoColors.skyBlue,
          fontWeight: FontWeight.w700,
        );

        return StickerCard(
          variant: StickerVariant.deep,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppZh.companionToolsTitle,
                style: SecondaryTypography.onGradient.h15,
              ),
              const SizedBox(height: 4),
              Text(
                AppZh.companionToolsSubtitle(edition.label),
                style: subtitle,
              ),
              const SizedBox(height: 4),
              Text(
                AppZh.companionToolsFacility(scope.facilityLabel),
                style: subtitle,
              ),
              const SizedBox(height: 12),
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
                icon: Icons.radar_rounded,
                title: AppZh.companionToolBlindSpot,
                subtitle: AppZh.companionToolBlindSpotHint,
                onTap: () => context.push('/search/companion/blind-spot'),
              ),
              const SizedBox(height: 8),
              _CompanionToolTile(
                icon: Icons.flash_on_rounded,
                title: AppZh.companionToolQuickDamage,
                subtitle: AppZh.companionToolQuickDamageHint(
                  scope.facilityLabel,
                ),
                onTap: () => context.push('/search/companion/quick-damage'),
              ),
            ],
          ),
        );
      },
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
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(TitoRadii.md);
    final (
      Color fill,
      BorderSide side,
      Color accent,
      Color muted,
    ) = appVisualStyle.usesTrainerJournal
        ? (
            TitoColors.card,
            const BorderSide(color: TitoColors.ink, width: TitoBorders.element),
            TitoColors.deepBlue,
            TitoColors.mutedInk,
          )
        : appVisualStyle.usesSolidPlastic
        ? (
            Colors.white.withValues(alpha: 0.82),
            BorderSide(
              color: Colors.white.withValues(alpha: 0.85),
              width: TitoBorders.glass,
            ),
            TitoColors.deepBlue,
            TitoColors.mutedInk,
          )
        : (
            scheme.surfaceContainerHighest,
            BorderSide.none,
            scheme.primary,
            scheme.onSurfaceVariant,
          );
    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: radius,
      child: StickerPressable(
        borderRadius: radius,
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(borderRadius: radius, side: side),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, color: accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SecondaryTypography.onCard.body14.copyWith(
                            fontWeight: FontWeight.w800,
                            color: appVisualStyle.usesFlatUi
                                ? scheme.onSurface
                                : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SecondaryTypography.onCard.small12.copyWith(
                            color: muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
