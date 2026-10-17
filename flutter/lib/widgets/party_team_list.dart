import 'package:flutter/material.dart';

import '../features/parser/gen4_exp.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/sprite_generation_catalog.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_skin.dart';
import 'dex_sprite_image.dart';
import 'sticker_card.dart';
import 'sticker_pressable.dart';
import 'tito_progress_bar.dart';

/// Design-spec team row: sticker sprite, name, HP + EXP bars.
class PartyTeamList extends StatelessWidget {
  const PartyTeamList({
    super.key,
    required this.party,
    this.detailsFuture,
    this.showEmptySlots = false,
    this.onMemberTap,
    this.onEmptySlotTap,
    this.expandedIndex,
    this.editorBuilder,
  });

  final List<PartyMember> party;
  final Future<Map<int, PokemonDetail>>? detailsFuture;
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
    return FutureBuilder<Map<int, PokemonDetail>>(
      future: detailsFuture,
      builder: (context, snapshot) {
        final details = snapshot.data ?? const <int, PokemonDetail>{};
        return Column(
          children: [
            for (var index = 0; index < slots; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              if (index == expandedIndex && editorBuilder != null)
                editorBuilder!(context, index)
              else if (index < party.length)
                _PartyTeamRow(
                  member: party[index],
                  summary: details[party[index].speciesId]?.summary,
                  slot: index + 1,
                  onTap: onMemberTap == null ? null : () => onMemberTap!(index),
                )
              else
                _EmptyTeamRow(onTap: onEmptySlotTap),
            ],
          ],
        );
      },
    );
  }
}

class _PartyTeamRow extends StatelessWidget {
  const _PartyTeamRow({
    required this.member,
    required this.summary,
    required this.slot,
    this.onTap,
  });

  final PartyMember member;
  final PokemonSummary? summary;
  final int slot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    final radius = BorderRadius.circular(skin.radiusMd);
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
      borderRadius: radius,
      ownShadow: false,
      interactive: onTap != null,
      child: StickerCard.dense(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TeamSpritePlate(
                source: speciesId == null
                    ? null
                    : (summary?.displaySpritePath ??
                          defaultSpriteUrlFor(speciesId)),
              ),
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
                        color: skin.ink,
                      ),
                    ),
                    if (subParts.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        subParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SecondaryTypography.onCard.small12.copyWith(
                          color: skin.mutedInk,
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
                  style: skin.display(
                    15,
                    color: skin.accentInkOn(skin.paper),
                    weight: FontWeight.w800,
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

class _TeamSpritePlate extends StatelessWidget {
  const _TeamSpritePlate({required this.source});

  final String? source;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    final outline = skin.outline;
    final radius = skin.isFlat ? null : BorderRadius.circular(skin.radiusSm);
    return Container(
      width: 46,
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: skin.isFlat ? TitoColors.softYellow : skin.paper,
        shape: skin.isFlat ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radius,
        border: outline == null
            ? null
            : Border.all(
                color: skin.isPlastic
                    ? skin.ink.withValues(alpha: 0.28)
                    : outline,
                width: skin.outlineWidth,
              ),
      ),
      child: source == null
          ? Icon(Icons.catching_pokemon_outlined, size: 22, color: skin.mutedInk)
          : DexSpriteImage(source: source, width: 38, height: 38),
    );
  }
}

/// Tiny type-colored pill from the team template (火/飞行…).
class _TypePill extends StatelessWidget {
  const _TypePill({required this.typeKey});

  final String typeKey;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    final outline = skin.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: typeTileColor(typeKey),
        borderRadius: BorderRadius.circular(999),
        border: outline == null
            ? null
            : Border.all(color: outline, width: skin.outlineWidth),
      ),
      child: Text(
        typeNameZh(typeKey),
        style: SecondaryTypography.onCard.small12.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: skin.ink.withValues(alpha: 0.8),
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
    final skin = TitoSkin.of(context);
    final team12 = SecondaryTypography.onCard.team12.copyWith(
      color: skin.mutedInk,
    );

    return Row(
      children: [
        SizedBox(width: 28, child: Text(label, style: team12)),
        Expanded(
          child: TitoProgressBar(
            value: value,
            height: 8,
            fillColor: fillColor,
            trackColor: skin.mutedInk.withValues(alpha: 0.22),
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
    final skin = TitoSkin.of(context);
    final radius = BorderRadius.circular(skin.radiusMd);
    return StickerPressable(
      borderRadius: radius,
      ownShadow: false,
      interactive: onTap != null,
      child: StickerCard.dense(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 18, color: skin.mutedInk),
              const SizedBox(width: 6),
              Text(
                AppZh.teamEmptySlot,
                style: SecondaryTypography.onCard.body14.copyWith(
                  color: skin.mutedInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
