import 'package:flutter/material.dart';

import '../features/parser/gen4_exp.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import '../features/dex/dex_repository.dart';
import 'sticker_card.dart';
import 'tito_list_reveal.dart';
import 'tito_progress_bar.dart';
import 'tito_sprite_sticker.dart';

/// Design-spec team row: sticker sprite, name, HP + EXP bars.
class PartyTeamList extends StatelessWidget {
  const PartyTeamList({
    super.key,
    required this.party,
    this.showEmptySlots = false,
    this.onMemberTap,
    this.onEmptySlotTap,
  });

  final List<PartyMember> party;
  final bool showEmptySlots;
  final ValueChanged<int>? onMemberTap;
  final VoidCallback? onEmptySlotTap;

  @override
  Widget build(BuildContext context) {
    final slots = showEmptySlots ? 6 : party.length;
    return Column(
      children: [
        for (var index = 0; index < slots; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          TitoListReveal(
            delay: TitoListReveal.staggerDelay(index, stepMs: 40),
            child: index < party.length
                ? _PartyTeamRow(
                    member: party[index],
                    slot: index + 1,
                    onTap: onMemberTap == null
                        ? null
                        : () => onMemberTap!(index),
                  )
                : _EmptyTeamRow(onTap: onEmptySlotTap),
          ),
        ],
      ],
    );
  }
}

class _PartyTeamRow extends StatelessWidget {
  const _PartyTeamRow({required this.member, required this.slot, this.onTap});

  final PartyMember member;
  final int slot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = member.nickname ?? localizeSpecies(member.species);
    final speciesId = member.speciesId;
    final team12 = SecondaryTypography.onCard.team12;

    return StickerCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (speciesId != null)
              FutureBuilder(
                future: dexRepository.getSummary(speciesId),
                builder: (context, snapshot) {
                  return TitoSpriteSticker(
                    source: snapshot.data?.displaySpritePath,
                    size: 56,
                    shape: BoxShape.circle,
                  );
                },
              )
            else
              const TitoSpriteSticker(
                source: null,
                size: 56,
                shape: BoxShape.circle,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        AppZh.partySlot(slot),
                        style: team12.copyWith(color: TitoColors.mutedInk),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: team12,
                        ),
                      ),
                      if (member.level != null)
                        Text('${AppZh.level}${member.level}', style: team12),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (member.currentHp != null && member.maxHp != null)
                    _StatBar(
                      label: 'HP',
                      value: (member.currentHp! / member.maxHp!).clamp(
                        0.0,
                        1.0,
                      ),
                      detail: '${member.currentHp}/${member.maxHp}',
                      fillColor: TitoColors.hpGreen,
                    ),
                  if (member.experience != null && member.level != null) ...[
                    const SizedBox(height: 6),
                    _StatBar(
                      label: 'EXP',
                      value: gen4MediumFastExpProgress(
                        member.experience!,
                        member.level!,
                      ),
                      detail: null,
                      fillColor: TitoColors.expGold,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.label,
    required this.value,
    required this.fillColor,
    this.detail,
  });

  final String label;
  final double value;
  final Color fillColor;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final team12 = SecondaryTypography.onCard.team12;

    return Row(
      children: [
        SizedBox(width: 28, child: Text(label, style: team12)),
        Expanded(
          child: TitoProgressBar(
            value: value,
            height: 8,
            fillColor: fillColor,
            trackColor: TitoColors.skyBlue.withValues(alpha: 0.45),
          ),
        ),
        if (detail != null) ...[
          const SizedBox(width: 6),
          Text(detail!, style: team12),
        ],
      ],
    );
  }
}

class _EmptyTeamRow extends StatelessWidget {
  const _EmptyTeamRow({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      variant: StickerVariant.sky,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: TitoColors.card.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: TitoColors.ink.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.add_rounded,
                color: TitoColors.mutedInk.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 10),
            Text(AppZh.teamEmptySlot, style: context.tito.cardMuted),
          ],
        ),
      ),
    );
  }
}
