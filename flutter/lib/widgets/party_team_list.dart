import 'package:flutter/material.dart';

import '../features/dex/dex_models.dart';
import '../features/dex/sprite_generation_catalog.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/app_visual_style.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'handheld_input.dart';
import 'sticker_card.dart';
import 'sticker_pressable.dart';
import 'tito_sprite_sticker.dart';

/// Dashed rounded-rect outline for the empty team slot (no native dashed
/// borders in Flutter).
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
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
      color != oldDelegate.color ||
      radius != oldDelegate.radius ||
      strokeWidth != oldDelegate.strokeWidth;
}

/// 3×2 party index. Tap a filled slot to select it; empty slots add a member.
class PartyTeamBoard extends StatelessWidget {
  const PartyTeamBoard({
    super.key,
    required this.party,
    this.detailsFuture,
    this.selectedIndex,
    this.onSelect,
    this.onEmptySlotTap,
  });

  final List<PartyMember> party;
  final Future<Map<int, PokemonDetail>>? detailsFuture;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onEmptySlotTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<int, PokemonDetail>>(
      future: detailsFuture,
      builder: (context, snapshot) {
        final details = snapshot.data ?? const <int, PokemonDetail>{};
        return Column(
          children: [
            for (var row = 0; row < 2; row++) ...[
              if (row > 0) const SizedBox(height: 8),
              Row(
                children: [
                  for (var col = 0; col < 3; col++) ...[
                    if (col > 0) const SizedBox(width: 8),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 0.92,
                        child: _PartyGridSlot(
                          index: row * 3 + col,
                          party: party,
                          details: details,
                          selected: selectedIndex == row * 3 + col,
                          onSelect: onSelect,
                          onEmptySlotTap: onEmptySlotTap,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

bool _canEvolveFrom(EvolutionNode? node, int id) {
  if (node == null) return false;
  if (node.id == id) return node.children.isNotEmpty;
  return node.children.any((child) => _canEvolveFrom(child, id));
}

class _PartyGridSlot extends StatelessWidget {
  const _PartyGridSlot({
    required this.index,
    required this.party,
    required this.details,
    required this.selected,
    this.onSelect,
    this.onEmptySlotTap,
  });

  final int index;
  final List<PartyMember> party;
  final Map<int, PokemonDetail> details;
  final bool selected;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onEmptySlotTap;

  @override
  Widget build(BuildContext context) {
    if (index >= party.length) {
      return _EmptyGridSlot(onTap: party.length < 6 ? onEmptySlotTap : null);
    }
    final member = party[index];
    final speciesId = member.speciesId;
    final summary = speciesId == null ? null : details[speciesId]?.summary;
    final canEvolve =
        speciesId != null &&
        _canEvolveFrom(details[speciesId]?.evolutionChain, speciesId);
    final label = member.nickname ?? localizeSpecies(member.species);
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(TitoRadii.md);
    final selectedColor = appVisualStyle.usesFlatUi
        ? scheme.primary
        : TitoColors.coral;
    return HandheldFocusDecorator(
      onActivate: onSelect == null ? null : () => onSelect!(index),
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TitoRadii.md + 2),
          border: Border.all(
            color: selected ? selectedColor : Colors.transparent,
            width: TitoBorders.card,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: StickerPressable(
            borderRadius: radius,
            ownShadow: false,
            child: StickerCard(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: InkWell(
                onTap: onSelect == null ? null : () => onSelect!(index),
                borderRadius: radius,
                child: Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TitoSpriteSticker(
                          source:
                              summary?.displaySpritePath ??
                              (speciesId == null
                                  ? null
                                  : defaultSpriteUrlFor(speciesId)),
                          size: 40,
                          radius: TitoRadii.md,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: SecondaryTypography.onCard.small12.copyWith(
                            fontWeight: FontWeight.w800,
                            color: TitoColors.deepBlue,
                          ),
                        ),
                        if (member.level != null)
                          Text(
                            '${AppZh.level}${member.level}',
                            maxLines: 1,
                            style: SecondaryTypography.onCard.small12.copyWith(
                              color: TitoColors.coral,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                    if (canEvolve)
                      const Positioned(
                        top: 0,
                        right: 0,
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: TitoColors.coral,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyGridSlot extends StatelessWidget {
  const _EmptyGridSlot({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(TitoRadii.md);
    final Color fill;
    final Color dash;
    final double stroke;
    if (appVisualStyle.usesFlatUi) {
      final scheme = Theme.of(context).colorScheme;
      fill = scheme.surfaceContainerLow;
      dash = scheme.outlineVariant;
      stroke = TitoBorders.element;
    } else if (appVisualStyle.usesSolidPlastic) {
      fill = Colors.white.withValues(alpha: 0.3);
      dash = Colors.white.withValues(alpha: 0.6);
      stroke = TitoBorders.glass;
    } else {
      fill = TitoColors.cardWarm;
      dash = TitoColors.ink.withValues(alpha: 0.45);
      stroke = TitoBorders.card;
    }
    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: radius,
      child: StickerPressable(
        borderRadius: radius,
        ownShadow: false,
        interactive: onTap != null,
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: dash,
            radius: TitoRadii.md,
            strokeWidth: stroke,
          ),
          child: Material(
            color: fill,
            borderRadius: radius,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  size: 22,
                  color: TitoColors.mutedInk.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
