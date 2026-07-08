import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/tito_colors.dart';
import 'sticker_card.dart';

class PartyStrip extends StatelessWidget {
  const PartyStrip({super.key, required this.party});

  final List<PartyMember> party;

  @override
  Widget build(BuildContext context) {
    if (party.isEmpty) {
      return const SizedBox.shrink();
    }

    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.currentParty,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: party.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final member = party[index];
                return _PartyOrb(member: member);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyOrb extends StatelessWidget {
  const _PartyOrb({required this.member});

  final PartyMember member;

  @override
  Widget build(BuildContext context) {
    final label = member.nickname ?? localizeSpecies(member.species);
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: TitoColors.cream,
              shape: BoxShape.circle,
              border: Border.all(color: TitoColors.ink, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3818283B),
                  offset: Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              label.isNotEmpty ? label[0].toUpperCase() : '?',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: TitoColors.deepBlue,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (member.level != null)
            Text(
              '${AppZh.level}${member.level}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: TitoColors.mutedInk,
              ),
            ),
        ],
      ),
    );
  }
}
