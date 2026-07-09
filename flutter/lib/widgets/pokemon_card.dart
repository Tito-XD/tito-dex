import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dex/dex_models.dart';
import '../features/dex/dex_offline_service.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'dex_sprite_image.dart';
import 'sticker_card.dart';
import 'tito_sprite_sticker.dart';

class PokemonMiniCard extends StatelessWidget {
  const PokemonMiniCard({
    super.key,
    required this.summary,
    required this.status,
    this.onTap,
    this.compact = false,
  });

  final PokemonSummary summary;
  final DexEncounterStatus status;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final variant = switch (status) {
      DexEncounterStatus.caught => StickerVariant.mint,
      DexEncounterStatus.seen => StickerVariant.sky,
      DexEncounterStatus.unknown => StickerVariant.cream,
    };
    final spriteSize = compact ? 52.0 : 64.0;
    final padding = compact ? 6.0 : 10.0;

    return GestureDetector(
      onTap: onTap ?? () => context.push('/dex/${summary.id}'),
      child: StickerCard(
        variant: variant,
        padding: EdgeInsets.all(padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TitoSpriteSticker(
              source: summary.displaySpritePath,
              size: spriteSize,
              padding: 2,
            ),
            SizedBox(height: compact ? 2 : 4),
            Text(
              '#${summary.id.toString().padLeft(3, '0')}',
              style: context.tito.dexNumber,
            ),
            const SizedBox(height: 2),
            Text(
              summary.nameZh,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.tito.chip,
            ),
            _PokemonTypeRow(types: summary.types),
            SizedBox(height: compact ? 2 : 4),
            Text(
              switch (status) {
                DexEncounterStatus.caught => AppZh.dexCaught,
                DexEncounterStatus.seen => AppZh.dexSeen,
                DexEncounterStatus.unknown => AppZh.dexUnknown,
              },
              style: context.tito.statusBadge,
            ),
          ],
        ),
      ),
    );
  }
}

class _PokemonTypeRow extends StatelessWidget {
  const _PokemonTypeRow({required this.types});

  final List<String> types;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
      future: _iconPaths(),
      builder: (context, snapshot) {
        final icons = snapshot.data ?? const {};
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: types
              .map(
                (type) => DexTypeIcon(
                  typeEn: type,
                  labelZh: typeNameZh(type),
                  iconPath: icons[type],
                  compact: true,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<Map<String, String?>> _iconPaths() async {
    final paths = <String, String?>{};
    for (final type in types) {
      paths[type] = await dexOfflineService.typeIconPath(type);
    }
    return paths;
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
      return Text(
        AppZh.dexNone,
        style: context.tito.cardMuted,
      );
    }

    return FutureBuilder<Map<String, String?>>(
      future: _iconPaths(),
      builder: (context, snapshot) {
        final icons = snapshot.data ?? const {};
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(types.length, (index) {
            final label = types[index];
            final key = typeKeys != null && index < typeKeys!.length
                ? typeKeys![index]
                : null;
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (key != null && icons[key] != null) ...[
                    DexSpriteImage(
                      source: icons[key],
                      height: 14,
                      width: 14,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: context.tito.chip,
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  Future<Map<String, String?>> _iconPaths() async {
    if (typeKeys == null) {
      return const {};
    }
    final paths = <String, String?>{};
    for (final type in typeKeys!) {
      paths[type] = await dexOfflineService.typeIconPath(type);
    }
    return paths;
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
              DexSpriteImage(
                source: node.displaySpritePath,
                height: 64,
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
    );
  }
}
