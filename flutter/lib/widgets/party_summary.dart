import 'package:flutter/material.dart';

import '../models/journey.dart';
import '../theme/tito_colors.dart';
import 'sticker_card.dart';

class PartySummary extends StatelessWidget {
  const PartySummary({super.key, required this.party});

  final List<PartyMember> party;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      variant: StickerVariant.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Party',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          for (final member in party)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    member.nickname ?? member.species,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (member.level != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: TitoColors.card,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: TitoColors.ink, width: 1.5),
                      ),
                      child: Text(
                        'Lv ${member.level}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
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
