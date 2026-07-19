import 'package:flutter/material.dart';

import '../features/parser/gen4_exp.dart';
import '../features/dex/dex_repository.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'sticker_card.dart';
import 'sticker_pressable.dart';
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
    this.expandedIndex,
    this.editorBuilder,
  });

  final List<PartyMember> party;
  final bool showEmptySlots;
  final ValueChanged<int>? onMemberTap;
  final VoidCallback? onEmptySlotTap;

  /// v0.6.7 inline editor: when [expandedIndex] points at a member and
  /// [editorBuilder] is set, that slot renders the editor card in place
  /// of the row (team template) instead of opening a bottom sheet.
  final int? expandedIndex;
  final Widget Function(BuildContext context, int index)? editorBuilder;

  @override
  Widget build(BuildContext context) {
    final slots = showEmptySlots ? 6 : party.length;
    return Column(
      children: [
        for (var index = 0; index < slots; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          TitoListReveal(
            delay: TitoListReveal.staggerDelay(index, stepMs: 40),
            child: index == expandedIndex && editorBuilder != null
                ? editorBuilder!(context, index)
                : index < party.length
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
    // v0.6.7 team template: rounded-square sprite plate, name + sub + type
    // pills, coral level on the right. HP/EXP bars only render when real
    // save data exists — manually added members (NS journeys) keep the
    // clean template look without empty bars.
    final hasVitals = member.currentHp != null && member.maxHp != null;
    final hasExp = member.experience != null && member.level != null;
    final subParts = <String>[
      if (member.level != null) '${AppZh.level}${member.level}',
      if (member.nickname != null) localizeSpecies(member.species),
    ];

    return StickerPressable(
      borderRadius: BorderRadius.circular(12),
      ownShadow: false,
      interactive: onTap != null,
      child: StickerCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (speciesId != null)
                FutureBuilder(
                  future: dexRepository.getSummary(speciesId),
                  builder: (context, snapshot) {
                    return TitoSpriteSticker(
                      source: snapshot.data?.displaySpritePath,
                      size: 46,
                      radius: 13,
                    );
                  },
                )
              else
                const TitoSpriteSticker(source: null, size: 46, radius: 13),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SecondaryTypography.onCard.h15.copyWith(
                        color: TitoColors.deepBlue,
                      ),
                    ),
                    if (subParts.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        subParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SecondaryTypography.onCard.small12.copyWith(
                          color: TitoColors.mutedInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (member.types.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          for (final type in member.types)
                            _TypePill(typeKey: type),
                        ],
                      ),
                    ],
                    if (hasVitals) ...[
                      const SizedBox(height: 8),
                      _StatBar(
                        label: 'HP',
                        value: (member.currentHp! / member.maxHp!).clamp(
                          0.0,
                          1.0,
                        ),
                        detail: '${member.currentHp}/${member.maxHp}',
                        fillColor: TitoColors.hpGreen,
                      ),
                    ],
                    if (hasExp) ...[
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
              if (member.level != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${AppZh.level}${member.level}',
                  style: SecondaryTypography.onCard.h15.copyWith(
                    color: TitoColors.coral,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny type-colored pill from the team template (火/飞行…).
class _TypePill extends StatelessWidget {
  const _TypePill({required this.typeKey});

  final String typeKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: typeTileColor(typeKey),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TitoColors.ink, width: TitoBorders.element),
      ),
      child: Text(
        typeNameZh(typeKey),
        style: SecondaryTypography.onCard.small12.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: TitoColors.ink.withValues(alpha: 0.75),
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
    // Team template: dashed warm card, centered label, no drop shadow.
    return StickerPressable(
      borderRadius: BorderRadius.circular(12),
      ownShadow: false,
      interactive: onTap != null,
      child: CustomPaint(
        painter: _DashedRRectPainter(
          color: TitoColors.ink.withValues(alpha: 0.45),
          radius: 12,
        ),
        child: Material(
          color: TitoColors.cardWarm,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: TitoColors.mutedInk.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppZh.teamEmptySlot,
                    style: SecondaryTypography.onCard.body14.copyWith(
                      color: TitoColors.mutedInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded-rect outline for the empty team slot (no native dashed
/// borders in Flutter).
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(1);
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}
