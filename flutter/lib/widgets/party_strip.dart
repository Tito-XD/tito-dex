import 'package:flutter/material.dart';

import '../features/companion/companion_art.dart';
import '../features/dex/dex_repository.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'dex_sprite_image.dart';
import 'sticker_card.dart';

class PartyStrip extends StatelessWidget {
  const PartyStrip({
    super.key,
    required this.party,
    this.compact = false,
    this.vertical = false,
    this.square = false,
    this.gridMode = false,
    this.listMode = false,
  });

  final List<PartyMember> party;
  final bool compact;
  final bool vertical;
  final bool square;
  final bool gridMode;
  final bool listMode;

  @override
  Widget build(BuildContext context) {
    final useHorizontal = square || !vertical;
    final titleStyle = square
        ? context.tito.cardSectionTitle
        : context.tito.cardTitle;

    if (party.isEmpty && !gridMode && !listMode) {
      return StickerCard(
        padding: DeviceLayout.cardPadding(context),
        child: Text(AppZh.currentParty, style: titleStyle),
      );
    }

    final padding = (compact || square)
        ? DeviceLayout.cardPadding(context)
        : null;

    return StickerCard(
      padding: padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppZh.currentParty, style: titleStyle),
          SizedBox(height: square ? 4 : (compact ? 8 : 10)),
          if (listMode)
            Expanded(
              child: _PartySlotList(party: party, compact: compact || square),
            )
          else if (gridMode)
            Expanded(
              child: _PartyGrid(party: party, compact: compact || square),
            )
          else if (useHorizontal)
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: party.length,
                separatorBuilder: (_, __) =>
                    SizedBox(width: square ? 4 : (compact ? 8 : 10)),
                itemBuilder: (context, index) {
                  return _PartyOrb(
                    member: party[index],
                    compact: compact || square,
                    mini: square,
                  );
                },
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: party.length,
                separatorBuilder: (_, __) => SizedBox(height: compact ? 6 : 8),
                itemBuilder: (context, index) {
                  return _PartyOrb(
                    member: party[index],
                    compact: compact,
                    horizontal: true,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PartySlotList extends StatelessWidget {
  const _PartySlotList({required this.party, required this.compact});

  final List<PartyMember> party;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const slotCount = 6;
    final visibleParty = party.take(slotCount).toList(growable: false);

    return Column(
      children: [
        for (var index = 0; index < slotCount; index++) ...[
          if (index > 0) const SizedBox(height: 3),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: index < visibleParty.length
                    ? TitoColors.card.withValues(alpha: 0.52)
                    : TitoColors.card.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(TitoRadii.sm),
                border: Border.all(
                  color: index < visibleParty.length
                      ? TitoColors.ink
                      : TitoColors.ink.withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: index < visibleParty.length
                    ? _PartyOrb(
                        member: visibleParty[index],
                        compact: compact,
                        horizontal: true,
                        mini: true,
                      )
                    : const Center(child: _EmptyPartySlot()),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PartyGrid extends StatelessWidget {
  const _PartyGrid({required this.party, required this.compact});

  final List<PartyMember> party;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const slotCount = 6;
    final visibleParty = party.take(slotCount).toList(growable: false);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slotCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 2.25,
      ),
      itemBuilder: (context, index) {
        if (index < visibleParty.length) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: TitoColors.card.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(TitoRadii.sm),
              border: Border.all(color: TitoColors.ink, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: _PartyOrb(
                member: visibleParty[index],
                compact: compact,
                horizontal: true,
                mini: true,
              ),
            ),
          );
        }
        return const _EmptyPartySlot();
      },
    );
  }
}

class _EmptyPartySlot extends StatelessWidget {
  const _EmptyPartySlot();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.add_circle_outline_rounded,
      color: TitoColors.mutedInk.withValues(alpha: 0.65),
      size: 16,
    );
  }
}

class _PartyOrb extends StatelessWidget {
  const _PartyOrb({
    required this.member,
    this.compact = false,
    this.horizontal = false,
    this.mini = false,
  });

  final PartyMember member;
  final bool compact;
  final bool horizontal;
  final bool mini;

  @override
  Widget build(BuildContext context) {
    final label = member.nickname ?? localizeSpecies(member.species);
    final orbSize = mini
        ? DeviceLayout.dim(context, 28.0)
        : (compact ? DeviceLayout.dim(context, 40.0) : 48.0);
    final slotWidth = mini
        ? DeviceLayout.dim(context, 52.0)
        : (compact ? DeviceLayout.dim(context, 58.0) : 64.0);

    final avatar = _PartyMemberAvatar(
      member: member,
      size: orbSize,
      label: label,
    );

    final name = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.tito.captionStrong,
    );

    final level = member.level != null
        ? Text(
            '${AppZh.level}${member.level}',
            style: context.tito.caption,
          )
        : null;

    if (horizontal) {
      return Row(
        children: [
          avatar,
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: [
                Expanded(child: name),
                if (level != null) ...[
                  const SizedBox(width: 4),
                  level,
                ],
              ],
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: slotWidth,
      child: Column(
        children: [
          avatar,
          SizedBox(height: mini ? 2 : 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: name),
              if (level != null) ...[
                const SizedBox(width: 2),
                level,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PartyMemberAvatar extends StatelessWidget {
  const _PartyMemberAvatar({
    required this.member,
    required this.size,
    required this.label,
  });

  final PartyMember member;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final speciesId = member.speciesId ?? _guessSpeciesId(member.species);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: TitoColors.cream,
        shape: BoxShape.circle,
        border: Border.all(color: TitoColors.ink, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x3818283B), offset: Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: speciesId != null
          ? FutureBuilder(
              future: dexRepository.getSummary(speciesId),
              builder: (context, snapshot) {
                final sprite = snapshot.data?.displaySpritePath;
                if (sprite != null && sprite.isNotEmpty) {
                  return DexSpriteImage(
                    source: sprite,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  );
                }
                return _letterFallback(label, size);
              },
            )
          : _letterFallback(label, size),
    );
  }

  Widget _letterFallback(String label, double size) {
    return Text(
      label.isNotEmpty ? label[0].toUpperCase() : '?',
      style: TitoTypography.style(
        fontSize: size * 0.42,
        fontWeight: FontWeight.w800,
        color: TitoColors.deepBlue,
      ),
    );
  }

  int? _guessSpeciesId(String species) {
    for (final entry in companionSpeciesIds.entries) {
      if (entry.key.toLowerCase() == species.toLowerCase()) {
        return entry.value;
      }
      if (localizeSpecies(entry.key) == species) {
        return entry.value;
      }
    }
    return null;
  }
}
