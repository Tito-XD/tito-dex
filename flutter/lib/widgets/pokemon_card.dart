import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dex/dex_models.dart';
import '../l10n/app_zh.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'dex_sprite_image.dart';
import 'handheld_input.dart';
import 'sticker_card.dart';
import 'sticker_pressable.dart';
import 'type_badge.dart';

class PokemonMiniCard extends StatelessWidget {
  const PokemonMiniCard({
    super.key,
    required this.summary,
    required this.status,
    this.onTap,
    this.onLongPress,
    this.compact = false,
  });

  final PokemonSummary summary;
  final DexEncounterStatus status;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final variant = switch (status) {
      DexEncounterStatus.caught => StickerVariant.mint,
      DexEncounterStatus.seen => StickerVariant.sky,
      DexEncounterStatus.unknown => StickerVariant.cream,
    };
    final activate = onTap ?? () => context.push('/dex/${summary.id}');
    final padding = compact ? 6.0 : 10.0;
    final checkSize = compact ? 14.0 : 18.0;
    final radius = DeviceLayout.rLg(context);

    return HandheldFocusDecorator(
      onActivate: activate,
      borderRadius: BorderRadius.circular(radius),
      child: StickerPressable(
        borderRadius: BorderRadius.circular(radius),
        // StickerCard below paints the retro shadow — sink physics only.
        ownShadow: false,
        child: GestureDetector(
          onTap: activate,
          onLongPress: onLongPress,
          child: Stack(
            fit: StackFit.expand,
            children: [
              StickerCard(
                variant: variant,
                padding: EdgeInsets.fromLTRB(
                  padding,
                  padding,
                  padding,
                  padding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Flexible sprite area — absorbs any extra tile height so the
                    // card always fills its grid cell without overflowing.
                    Expanded(
                      child: DexSpriteImage(
                        source: summary.displaySpritePath,
                        height: null,
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: compact ? 2 : 4),
                    Text(
                      '#${summary.id.toString().padLeft(3, '0')}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TitoTypography.style(
                        fontSize: compact ? 10 : 12,
                        fontWeight: FontWeight.w700,
                        color: TitoColors.mutedInk,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      summary.nameZh,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TitoTypography.style(
                        fontSize: compact ? 12 : 14,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: compact ? 3 : 4),
                    TitoTypeBadgeRow(
                      typesEn: summary.types,
                      size: TypeBadgeSize.small,
                    ),
                  ],
                ),
              ),
              if (status == DexEncounterStatus.caught)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: TitoColors.mint,
                    size: checkSize,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TypeChipRow extends StatelessWidget {
  const TypeChipRow({
    super.key,
    required this.types,
    this.typeKeys,
    this.tone = TypeChipTone.neutral,
  });

  final List<String> types;
  final List<String>? typeKeys;
  final TypeChipTone tone;

  @override
  Widget build(BuildContext context) {
    if (types.isEmpty) {
      return Text(AppZh.dexNone, style: context.tito.cardMuted);
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(types.length, (index) {
        final key = typeKeys != null && index < typeKeys!.length
            ? typeKeys![index]
            : null;
        if (key != null) {
          return TitoTypeBadge(typeEn: key);
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: switch (tone) {
              TypeChipTone.weak => const Color(0xFFFFD6C8),
              TypeChipTone.resist => const Color(0xFFD4E9FF),
              TypeChipTone.immune => const Color(0xFFE6E0F0),
              TypeChipTone.neutral => TitoColors.skyBlue,
            },
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: TitoColors.ink, width: 2),
          ),
          child: Text(types[index], style: context.tito.chip),
        );
      }),
    );
  }
}

enum TypeChipTone { neutral, weak, resist, immune }

class EvolutionChainView extends StatelessWidget {
  const EvolutionChainView({
    super.key,
    required this.root,
    required this.highlightId,
  });

  final EvolutionNode root;
  final int highlightId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildNodes(context, root),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildNodes(BuildContext context, EvolutionNode node) {
    final widgets = <Widget>[
      _EvolutionCard(node: node, highlighted: node.id == highlightId),
    ];

    for (final child in node.children) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.only(top: 36),
          child: Icon(Icons.arrow_forward_rounded, color: TitoColors.ink),
        ),
      );
      widgets.addAll(_buildNodes(context, child));
    }

    return widgets;
  }
}

class _EvolutionCard extends StatelessWidget {
  const _EvolutionCard({required this.node, required this.highlighted});

  final EvolutionNode node;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final compact = DeviceLayout.useSquareDashboard(context);

    return HandheldFocusDecorator(
      onActivate: () => context.push('/dex/${node.id}'),
      borderRadius: BorderRadius.circular(DeviceLayout.rLg(context)),
      child: GestureDetector(
        onTap: () => context.push('/dex/${node.id}'),
        child: StickerCard(
          variant: highlighted ? StickerVariant.mint : StickerVariant.cream,
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: SizedBox(
            width: compact ? 84 : 96,
            child: Column(
              children: [
                DexSpriteImage(
                  source: node.displaySpritePath,
                  height: compact ? 56 : 64,
                ),
                Text(
                  node.nameZh,
                  textAlign: TextAlign.center,
                  style: context.tito.cardBodyEmphasis,
                ),
                if (node.triggerZh != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    node.triggerZh!,
                    textAlign: TextAlign.center,
                    style: context.tito.caption,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertical evolution tree — linear chains stack down, branches split sideways.
class EvolutionChainVerticalView extends StatelessWidget {
  const EvolutionChainVerticalView({
    super.key,
    required this.root,
    required this.highlightId,
  });

  final EvolutionNode root;
  final int highlightId;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: _buildNode(context, root),
    );
  }

  Widget _buildNode(BuildContext context, EvolutionNode node) {
    if (node.children.isEmpty) {
      return _EvolutionCard(node: node, highlighted: node.id == highlightId);
    }

    if (node.children.length == 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EvolutionCard(node: node, highlighted: node.id == highlightId),
          const Icon(Icons.arrow_downward_rounded, color: TitoColors.ink),
          _buildNode(context, node.children.first),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EvolutionCard(node: node, highlighted: node.id == highlightId),
        const Icon(Icons.arrow_downward_rounded, color: TitoColors.ink),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < node.children.length; i++) ...[
              if (i > 0) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: TitoColors.ink,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(child: _buildNode(context, node.children[i])),
            ],
          ],
        ),
      ],
    );
  }
}
