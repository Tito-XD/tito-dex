import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dex/dex_models.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../theme/tito_colors.dart';
import 'sticker_card.dart';

class PokemonMiniCard extends StatelessWidget {
  const PokemonMiniCard({
    super.key,
    required this.summary,
    required this.status,
    this.onTap,
  });

  final PokemonSummary summary;
  final DexEncounterStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final variant = switch (status) {
      DexEncounterStatus.caught => StickerVariant.mint,
      DexEncounterStatus.seen => StickerVariant.sky,
      DexEncounterStatus.unknown => StickerVariant.cream,
    };

    return GestureDetector(
      onTap: onTap ?? () => context.push('/dex/${summary.id}'),
      child: StickerCard(
        variant: variant,
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (summary.spriteUrl != null)
              Image.network(
                summary.spriteUrl!,
                height: 56,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(height: 56),
              )
            else
              const SizedBox(height: 56),
            Text(
              '#${summary.id.toString().padLeft(3, '0')}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: TitoColors.mutedInk,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              summary.nameZh,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            Text(
              summary.types.map(typeNameZh).join('/'),
              style: const TextStyle(
                fontSize: 10,
                color: TitoColors.mutedInk,
              ),
            ),
            const Spacer(),
            Text(
              switch (status) {
                DexEncounterStatus.caught => AppZh.dexCaught,
                DexEncounterStatus.seen => AppZh.dexSeen,
                DexEncounterStatus.unknown => AppZh.dexUnknown,
              },
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TypeChipRow extends StatelessWidget {
  const TypeChipRow({
    super.key,
    required this.types,
    this.tone = TypeChipTone.neutral,
  });

  final List<String> types;
  final TypeChipTone tone;

  @override
  Widget build(BuildContext context) {
    if (types.isEmpty) {
      return Text(
        AppZh.dexNone,
        style: const TextStyle(
          color: TitoColors.mutedInk,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: types
          .map(
            (type) => Container(
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
              child: Text(
                type,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          )
          .toList(),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildNodes(context, root),
      ),
    );
  }

  List<Widget> _buildNodes(BuildContext context, EvolutionNode node) {
    final widgets = <Widget>[
      _EvolutionCard(
        node: node,
        highlighted: node.id == highlightId,
      ),
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
  const _EvolutionCard({
    required this.node,
    required this.highlighted,
  });

  final EvolutionNode node;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/dex/${node.id}'),
      child: StickerCard(
        variant: highlighted ? StickerVariant.mint : StickerVariant.cream,
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 96,
          child: Column(
            children: [
              if (node.spriteUrl != null)
                Image.network(node.spriteUrl!, height: 64, fit: BoxFit.contain)
              else
                const SizedBox(height: 64),
              Text(
                node.nameZh,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (node.triggerZh != null) ...[
                const SizedBox(height: 4),
                Text(
                  node.triggerZh!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: TitoColors.mutedInk,
                    fontWeight: FontWeight.w600,
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
