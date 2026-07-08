import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'sticker_card.dart';

class PartySummary extends StatelessWidget {
  const PartySummary({
    super.key,
    required this.party,
    this.showSlots = false,
  });

  final List<PartyMember> party;
  final bool showSlots;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      variant: StickerVariant.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.party,
            style: context.tito.cardTitle,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < party.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      showSlots
                          ? '${AppZh.partySlot(i + 1)} · ${party[i].nickname ?? localizeSpecies(party[i].species)}'
                          : party[i].nickname != null
                              ? party[i].nickname!
                              : localizeSpecies(party[i].species),
                      style: context.tito.cardBodyStrong,
                    ),
                  ),
                  if (party[i].level != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: TitoColors.cream,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: TitoColors.ink, width: 2),
                      ),
                      child: Text(
                        '${AppZh.level}${party[i].level}',
                        style: context.tito.captionStrong,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
