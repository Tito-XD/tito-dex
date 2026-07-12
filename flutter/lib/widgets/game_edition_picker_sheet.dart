/// v0.4.0 — Shared 23-item game edition picker (B1).
library;

import 'package:flutter/material.dart';

import '../features/game/game_edition.dart';
import '../theme/tito_colors.dart';
import '../theme/secondary_typography.dart';

/// Shows grouped bottom sheet; returns selected [GameEdition] or null if dismissed.
Future<GameEdition?> showGameEditionPickerSheet(
  BuildContext context, {
  GameEdition? selected,
}) {
  return showModalBottomSheet<GameEdition>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    '选择游戏版本',
                    style: SecondaryTypography.onCard.body14.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (final group in gameEditionPickerGroups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      group.key,
                      style: SecondaryTypography.onCard.small12.copyWith(
                        fontWeight: FontWeight.w800,
                        color: TitoColors.mutedInk,
                      ),
                    ),
                  ),
                  for (final edition in group.value)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: edition.hasPokeApiData
                            ? TitoColors.skyBlue.withValues(alpha: 0.25)
                            : TitoColors.mutedInk.withValues(alpha: 0.2),
                        child: Text(
                          edition.homeBadgeLabel,
                          style: SecondaryTypography.onCard.small12.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      title: Text(edition.labelZh),
                      subtitle: edition.hasPokeApiData
                          ? null
                          : Text(
                              '暂无 PokeAPI 数据',
                              style: SecondaryTypography.onCard.small12.copyWith(
                                color: TitoColors.mutedInk,
                              ),
                            ),
                      trailing: selected == edition
                          ? const Icon(Icons.check_rounded, color: TitoColors.ink)
                          : null,
                      onTap: () => Navigator.pop(context, edition),
                    ),
                ],
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      );
    },
  );
}
