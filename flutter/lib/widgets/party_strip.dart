import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
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
            SizedBox(
              height: square ? 48 : (compact ? 60 : 72),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: party.length,
                separatorBuilder: (_, __) =>
                    SizedBox(width: square ? 6 : (compact ? 8 : 10)),
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

    final avatar = Container(
      width: orbSize,
      height: orbSize,
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
        style: TitoTypography.style(
          fontSize: mini ? 12 : (compact ? 16 : 18),
          fontWeight: FontWeight.w800,
          color: TitoColors.deepBlue,
        ),
      ),
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
      width: mini ? 44 : (compact ? 56 : 64),
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
