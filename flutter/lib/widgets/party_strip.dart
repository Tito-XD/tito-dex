import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/companion/companion_art.dart';
import '../features/dex/dex_repository.dart';
import '../features/dex/shiny_odds.dart';
import '../features/dex/sprite_generation_catalog.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/retro_style.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'dex_sprite_image.dart';
import 'fallback_sprite_image.dart';
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
    final titleStyle = square
        ? context.tito.cardSectionTitle
        : context.tito.cardTitle;

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
          else if (vertical)
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
            Expanded(
              child: _PartyHomeGrid(party: party, compact: compact),
            ),
        ],
      ),
    );
  }
}

/// Compact dashboard presentation: six equal slots, with a bare sprite and
/// two aligned text lines. Empty slots stay visible as muted Poké Balls.
class _PartyHomeGrid extends StatelessWidget {
  const _PartyHomeGrid({required this.party, required this.compact});

  final List<PartyMember> party;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const slotCount = 6;
    final visibleParty = party.take(slotCount).toList(growable: false);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slotCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: compact ? 4 : 8,
        mainAxisSpacing: compact ? 3 : 6,
        childAspectRatio: compact ? 2.35 : 2.5,
      ),
      itemBuilder: (context, index) {
        if (index >= visibleParty.length) {
          return _EmptyPartyGridSlot(compact: compact);
        }
        return _PartyGridMember(member: visibleParty[index], compact: compact);
      },
    );
  }
}

class _PartyGridMember extends StatelessWidget {
  const _PartyGridMember({required this.member, required this.compact});

  final PartyMember member;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = member.nickname ?? localizeSpecies(member.species);
    final levelLabel = member.level == null
        ? '${AppZh.level}—'
        : '${AppZh.level}${member.level}';

    // Slots pass through the home container expansion animation, so width can
    // transiently be a few px — shrink the avatar instead of overflowing.
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = compact ? 3.0 : 5.0;
        final spriteSize = math.min(
          compact ? 38.0 : 48.0,
          math.max(0.0, constraints.maxWidth - gap - 4),
        );
        return Row(
          children: [
            _PartyMemberAvatar(
              member: member,
              size: spriteSize,
              label: label,
              framed: false,
            ),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tito.captionStrong,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    levelLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tito.caption.copyWith(
                      color: TitoColors.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyPartyGridSlot extends StatelessWidget {
  const _EmptyPartyGridSlot({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spriteSize = compact ? 38.0 : 48.0;
    return Row(
      children: [
        SizedBox(
          width: spriteSize,
          height: spriteSize,
          child: Icon(
            Icons.catching_pokemon_rounded,
            size: compact ? 27 : 34,
            color: TitoColors.mutedInk.withValues(alpha: 0.38),
          ),
        ),
        SizedBox(width: compact ? 3 : 5),
        const Expanded(child: _PartyTextPlaceholder()),
      ],
    );
  }
}

class _PartyTextPlaceholder extends StatelessWidget {
  const _PartyTextPlaceholder();

  @override
  Widget build(BuildContext context) {
    final lineColor = TitoColors.mutedInk.withValues(alpha: 0.2);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FractionallySizedBox(
          widthFactor: 0.88,
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: lineColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 7),
        FractionallySizedBox(
          widthFactor: 0.5,
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: lineColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ],
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
        ? Text('${AppZh.level}${member.level}', style: context.tito.caption)
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
                if (level != null) ...[const SizedBox(width: 4), level],
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
              if (level != null) ...[const SizedBox(width: 2), level],
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
    this.framed = true,
  });

  /// One roll table per app launch — opening the app is the slot machine.
  static final int _sessionSeed = DateTime.now().millisecondsSinceEpoch;

  final PartyMember member;
  final double size;
  final String label;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final speciesId = member.speciesId ?? _guessSpeciesId(member.species);
    final isShiny = speciesId != null && shinyRoll(_sessionSeed, speciesId);

    Widget sprite = speciesId != null
        ? FutureBuilder(
            future: dexRepository.getSummary(speciesId),
            builder: (context, snapshot) {
              final sprite = snapshot.data?.displaySpritePath;
              if (sprite != null && sprite.isNotEmpty) {
                if (isShiny) {
                  return FallbackSpriteImage(
                    sources: [shinySpriteUrlFor(speciesId), sprite],
                    width: size,
                    height: size,
                  );
                }
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
        : _letterFallback(label, size);

    if (isShiny) {
      sprite = GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(AppZh.shinyPartyFound(label))));
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            sprite,
            const Positioned(top: -2, right: -2, child: _SparklePulse()),
          ],
        ),
      );
    }

    if (!framed) {
      return SizedBox(width: size, height: size, child: sprite);
    }

    return ListenableBuilder(
      listenable: retroStyle,
      builder: (context, child) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: TitoColors.cream,
          shape: BoxShape.circle,
          border: Border.all(color: TitoColors.ink, width: 2),
          boxShadow: retroStyle.enabled ? TitoShadows.stickerSmall : null,
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: child,
      ),
      child: sprite,
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

/// Gentle twinkle over a shiny party sprite.
class _SparklePulse extends StatefulWidget {
  const _SparklePulse();

  @override
  State<_SparklePulse> createState() => _SparklePulseState();
}

class _SparklePulseState extends State<_SparklePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.35,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: const Icon(
        Icons.auto_awesome_rounded,
        size: 13,
        color: TitoColors.softYellow,
      ),
    );
  }
}
