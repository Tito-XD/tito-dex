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
  });

  final List<PartyMember> party;
  final bool compact;
  final bool vertical;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final useHorizontal = square || !vertical;
    final titleStyle = square
        ? context.tito.cardSectionTitle
        : context.tito.cardTitle;

    if (party.isEmpty) {
      return StickerCard(
        padding: DeviceLayout.cardPadding(context),
        child: Text(
          AppZh.currentParty,
          style: titleStyle,
        ),
      );
    }

    final padding = (compact || square)
        ? DeviceLayout.cardPadding(context)
        : null;

    return StickerCard(
      padding: padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.currentParty,
            style: titleStyle,
          ),
          SizedBox(height: square ? 4 : (compact ? 8 : 10)),
          if (useHorizontal)
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
                separatorBuilder: (_, __) =>
                    SizedBox(height: compact ? 6 : 8),
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
    final orbSize = mini ? 30.0 : (compact ? 40.0 : 48.0);
    final slotWidth = mini ? 52.0 : (compact ? 58.0 : 64.0);

    final avatar = _PartyMemberAvatar(
      member: member,
      size: orbSize,
      label: label,
    );

    final name = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: mini
          ? context.tito.captionStrong.copyWith(fontSize: 8)
          : context.tito.captionStrong,
    );

    final level = member.level != null
        ? Text(
            '${AppZh.level}${member.level}',
            style: mini
                ? context.tito.caption.copyWith(fontSize: 8)
                : context.tito.caption,
          )
        : null;

    if (horizontal) {
      return Row(
        children: [
          avatar,
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                name,
                if (level != null) level,
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
          name,
          if (level != null) level,
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
          BoxShadow(
            color: Color(0x3818283B),
            offset: Offset(0, 3),
          ),
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
