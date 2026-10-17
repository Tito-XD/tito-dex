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
import '../theme/tito_skin.dart';
import '../theme/tito_typography.dart';
import 'dex_sprite_image.dart';
import 'fallback_sprite_image.dart';
import 'sticker_card.dart';
import 'tito_paper.dart';

class PartyStrip extends StatelessWidget {
  const PartyStrip({
    super.key,
    required this.party,
    this.compact = false,
    this.square = false,
    this.gridMode = false,
    this.stripMode = false,
  });

  final List<PartyMember> party;
  final bool compact;
  final bool square;
  final bool gridMode;

  /// Full-width bar variant of [gridMode]: one row of six upright slots
  /// instead of the 2×3 column grid. Layout intent can't be inferred from
  /// constraints alone (a tablet's half column is wider than a handheld's
  /// full bar), so the caller declares it.
  final bool stripMode;

  @override
  Widget build(BuildContext context) {
    final titleSize =
        (square
                ? context.titoHome.cardSectionTitle
                : context.titoHome.cardTitle)
            .fontSize ??
        16;
    final skin = TitoSkin.of(context);

    final padding = (compact || square)
        ? DeviceLayout.cardPadding(context)
        : null;

    return StickerCard.hero(
      role: TitoHeroRole.shelf,
      padding: padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppZh.currentParty, style: skin.heading(titleSize)),
          SizedBox(height: square ? 4 : (compact ? 8 : 10)),
          if (gridMode)
            Expanded(
              child: _PartyGrid(party: party, strip: stripMode),
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

    // Slots pass through the home container expansion animation, so width can
    // transiently be a few px — shrink the avatar instead of overflowing.
    // The level rides on the sprite as a corner badge, so the freed line goes
    // to a bigger sprite (38/48 → up to 44/54) and a full-width name.
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = compact ? 3.0 : 5.0;
        final spriteSize = math.min(
          math.min(compact ? 44.0 : 54.0, constraints.maxHeight),
          math.max(0.0, constraints.maxWidth - gap - 4),
        );
        return Row(
          children: [
            _PartyAvatarWithLevel(
              member: member,
              size: spriteSize,
              label: label,
              framed: false,
            ),
            SizedBox(width: gap),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _partyNameStyle(context),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = compact ? 3.0 : 5.0;
        final spriteSize = math.min(
          math.min(compact ? 44.0 : 54.0, constraints.maxHeight),
          math.max(0.0, constraints.maxWidth - gap - 4),
        );
        return Row(
          children: [
            SizedBox(
              width: spriteSize,
              height: spriteSize,
              child: Icon(
                Icons.catching_pokemon_rounded,
                size: spriteSize * 0.7,
                color: _partyMuted(context).withValues(alpha: 0.45),
              ),
            ),
            SizedBox(width: gap),
            const Expanded(child: _PartyTextPlaceholder()),
          ],
        );
      },
    );
  }
}

class _PartyTextPlaceholder extends StatelessWidget {
  const _PartyTextPlaceholder();

  @override
  Widget build(BuildContext context) {
    final lineColor = _partyMuted(context).withValues(alpha: 0.22);
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

class _PartyGrid extends StatelessWidget {
  const _PartyGrid({required this.party, required this.strip});

  final List<PartyMember> party;
  final bool strip;

  @override
  Widget build(BuildContext context) {
    const slotCount = 6;
    final visibleParty = party.take(slotCount).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Half-width column (save linked) → 2×3; full-width bar (no save)
        // → 6×1 like a classic party strip. Cells are upright — sprite over
        // name, level as a corner badge — so the name gets the whole cell
        // width and the sprite scales with the cell instead of a fixed 28px.
        final cols = strip ? 6 : 2;
        final rows = strip ? 1 : 3;
        const gap = 4.0;
        final cellW = (constraints.maxWidth - gap * (cols - 1)) / cols;
        // The strip card fills whatever height the screen leaves over; the
        // cells shouldn't stretch with it. Cap their height near-square and
        // let the grid float centered in the leftover space.
        final contentH = strip
            ? math.min(constraints.maxHeight, cellW * 1.2)
            : constraints.maxHeight;
        final cellH = (contentH - gap * (rows - 1)) / rows;
        final ratio = cellH > 0 && cellW > 0 ? cellW / cellH : 1.0;
        final grid = GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: slotCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            childAspectRatio: ratio,
          ),
          itemBuilder: (context, index) {
            if (index < visibleParty.length) {
              return _PartyGridCell(member: visibleParty[index]);
            }
            return const _EmptyPartyGridCell();
          },
        );
        if (contentH < constraints.maxHeight) {
          return Center(
            child: SizedBox(height: contentH, child: grid),
          );
        }
        return grid;
      },
    );
  }
}

/// Upright square-grid cell: sprite on top with the level badge on its
/// corner, name centered below across the full cell width.
class _PartyGridCell extends StatelessWidget {
  const _PartyGridCell({required this.member});

  final PartyMember member;

  @override
  Widget build(BuildContext context) {
    final label = member.nickname ?? localizeSpecies(member.species);
    return _PartySlotFrame(
      empty: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final nameStyle = _partyNameStyle(context);
          final nameH = (nameStyle.fontSize ?? 11) * 1.4;
          final spriteSize = math.max(
            16.0,
            math.min(
              72.0,
              math.min(
                constraints.maxHeight - nameH - 10,
                constraints.maxWidth - 12,
              ),
            ),
          );
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PartyAvatarWithLevel(
                member: member,
                size: spriteSize,
                label: label,
                framed: false,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: nameStyle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyPartyGridCell extends StatelessWidget {
  const _EmptyPartyGridCell();

  @override
  Widget build(BuildContext context) {
    return const _PartySlotFrame(
      empty: true,
      child: Center(child: _EmptyPartySlot()),
    );
  }
}

/// Filled slots keep a thin skin outline. Empty slots use a dashed frame
/// wherever the theme draws an outline, so the six-slot grid stays readable
/// inside the shelf hero.
class _PartySlotFrame extends StatelessWidget {
  const _PartySlotFrame({required this.empty, required this.child});

  final bool empty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    final radius = skin.radiusSm;
    final fill = skin.isFlat
        ? (empty ? skin.sheetFill.withValues(alpha: 0.72) : skin.sheetFill)
        : skin.isJournal
        ? TitoColors.card.withValues(alpha: empty ? 0.28 : 0.66)
        : Colors.white.withValues(alpha: empty ? 0.32 : 0.62);
    final outlined = skin.outline != null;
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: !outlined || empty
            ? null
            : Border.all(color: skin.outline!, width: skin.outlineWidth),
      ),
      child: child,
    );
    if (!empty || !outlined) {
      return box;
    }
    return TitoDashedFrame(
      color: skin.outline!.withValues(alpha: 0.55),
      radius: radius,
      strokeWidth: skin.isJournal ? 1.15 : skin.outlineWidth,
      child: box,
    );
  }
}

TextStyle _partyNameStyle(BuildContext context) {
  return context.titoHome.captionStrong.copyWith(color: _partyMuted(context));
}

Color _partyMuted(BuildContext context) {
  return TitoSkin.of(context).heroTint(TitoHeroRole.shelf).mutedInk;
}

/// Sprite with the level pinned to its bottom-right corner as a badge —
/// the level line disappears from the text stack, freeing that space.
class _PartyAvatarWithLevel extends StatelessWidget {
  const _PartyAvatarWithLevel({
    required this.member,
    required this.size,
    required this.label,
    this.framed = true,
  });

  final PartyMember member;
  final double size;
  final String label;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final avatar = _PartyMemberAvatar(
      member: member,
      size: size,
      label: label,
      framed: framed,
    );
    final level = member.level;
    if (level == null) {
      return avatar;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -5,
          bottom: -2,
          child: _PartyLevelBadge(level: level, spriteSize: size),
        ),
      ],
    );
  }
}

class _PartyLevelBadge extends StatelessWidget {
  const _PartyLevelBadge({required this.level, required this.spriteSize});

  final int level;
  final double spriteSize;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    final fontSize = (spriteSize * 0.24).clamp(7.5, 10.0);
    final flat = skin.isFlat;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 0.5),
      decoration: BoxDecoration(
        color: flat ? TitoColors.deepBlue : TitoColors.softYellow,
        borderRadius: BorderRadius.circular(999),
        border: skin.outline == null
            ? null
            : Border.all(color: skin.outline!, width: skin.outlineWidth),
      ),
      child: Text(
        '${AppZh.level}$level',
        style: skin.display(
          fontSize,
          color: flat ? TitoColors.card : skin.ink,
          weight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyPartySlot extends StatelessWidget {
  const _EmptyPartySlot();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.add_circle_outline_rounded,
      color: _partyMuted(context).withValues(alpha: 0.7),
      size: 16,
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
                    sources: [shinyOfficialArtworkUrlFor(speciesId), sprite],
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
              return _letterFallback(context, label, size);
            },
          )
        : _letterFallback(context, label, size);

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
      return SizedBox(
        width: size,
        height: size,
        child: ClipRect(child: sprite),
      );
    }

    return ListenableBuilder(
      listenable: retroStyle,
      builder: (context, child) {
        final skin = TitoSkin.of(context);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: skin.paper,
            shape: BoxShape.circle,
            border: skin.outline == null
                ? null
                : Border.all(color: skin.outline!, width: skin.outlineWidth),
            boxShadow: skin.cardShadow(small: true),
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: child,
        );
      },
      child: sprite,
    );
  }

  Widget _letterFallback(BuildContext context, String label, double size) {
    return Text(
      label.isNotEmpty ? label[0].toUpperCase() : '?',
      style: TitoTypography.style(
        fontSize: size * 0.42,
        fontWeight: FontWeight.w800,
        color: TitoSkin.of(context).ink,
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
