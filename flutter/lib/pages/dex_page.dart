import 'package:flutter/material.dart';

import '../features/dex/dex_mock_data.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/tito_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/sticker_card.dart';

class DexPage extends StatelessWidget {
  const DexPage({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  Widget build(BuildContext context) {
    final caught = dexMockData.where((e) => e.caught).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AppHeader(showSettings: true),
        Text(
          '${AppZh.navDex} · ${localizeGame(journey.game)} ($caught/${dexMockData.length})',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: TitoColors.card,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          AppZh.dexScopeNote,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: TitoColors.card,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: dexMockData.length,
          itemBuilder: (context, index) {
            final entry = dexMockData[index];
            return StickerCard(
              variant: entry.caught ? StickerVariant.mint : StickerVariant.cream,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '#${entry.id.toString().padLeft(3, '0')}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: TitoColors.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    localizeSpecies(entry.name),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.type,
                    style: const TextStyle(
                      fontSize: 11,
                      color: TitoColors.mutedInk,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    entry.caught
                        ? AppZh.dexCaught
                        : entry.seen
                            ? AppZh.dexSeen
                            : AppZh.dexUnknown,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
