import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import 'sticker_card.dart';

class PartyStrip extends StatelessWidget {
  const PartyStrip({
    super.key,
    required this.party,
    this.compact = false,
    this.vertical = false,
  });

  final List<PartyMember> party;
  final bool compact;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (party.isEmpty) {
      return StickerCard(
        padding: DeviceLayout.cardPadding(context),
        child: Text(
          AppZh.currentParty,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: compact ? 14 : 16,
          ),
        ),
      );
    }

    final padding = compact ? DeviceLayout.cardPadding(context) : null;

    return StickerCard(
      padding: padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.currentParty,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 14 : null,
                ),
          ),
          SizedBox(height: compact ? 8 : 10),
          if (vertical)
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
            )
          else
            SizedBox(
              height: compact ? 60 : 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: party.length,
                separatorBuilder: (_, __) => SizedBox(width: compact ? 8 : 10),
                itemBuilder: (context, index) {
                  return _PartyOrb(
                    member: party[index],
                    compact: compact,
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
  });

  final PartyMember member;
  final bool compact;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final label = member.nickname ?? localizeSpecies(member.species);
    final orbSize = compact ? 40.0 : 48.0;

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
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: compact ? 16 : 18,
          color: TitoColors.deepBlue,
        ),
      ),
    );

    final name = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: compact ? 10 : 11,
        fontWeight: FontWeight.w700,
      ),
    );

    final level = member.level != null
        ? Text(
            '${AppZh.level}${member.level}',
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w800,
              color: TitoColors.mutedInk,
            ),
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
      width: compact ? 56 : 64,
      child: Column(
        children: [
          avatar,
          const SizedBox(height: 4),
          name,
          if (level != null) level,
        ],
      ),
    );
  }
}
