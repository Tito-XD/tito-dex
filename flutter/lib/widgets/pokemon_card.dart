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
                    _triggerLabel(node.triggerZh!),
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
        const SizedBox(height: 4),
        _ChildrenRow(children: node.children, highlightId: highlightId),
      ],
    );
  }
}

class _ChildrenRow extends StatelessWidget {
  const _ChildrenRow({required this.children, required this.highlightId});
  final List<EvolutionNode> children;
  final int highlightId;

  @override
  Widget build(BuildContext context) {
    if (children.length <= 3) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: TitoColors.ink,
                ),
              ),
            Flexible(child: _childCard(context, children[i])),
          ],
        ],
      );
    }
    // Many children (e.g. Eevee) → wrap layout with branching arrows.
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 4,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final child in children)
              SizedBox(
                width: (constraints.maxWidth - 4) / 2,
                child: _childCard(context, child),
              ),
          ],
        );
      },
    );
  }

  Widget _childCard(BuildContext context, EvolutionNode node) {
    if (node.children.isNotEmpty) {
      return EvolutionChainVerticalView(
        root: node,
        highlightId: highlightId,
      );
    }
    return _EvolutionCard(node: node, highlighted: node.id == highlightId);
  }
}

/// Map PokeAPI evolution trigger/item slugs to Chinese display labels.
String _triggerLabel(String raw) {
  return raw
      .replaceAll('level-up', '升级')
      .replaceAll('use-item', '使用道具')
      .replaceAll('trade', '通讯交换')
      .replaceAll('shed', '蜕皮')
      .replaceAll('spin', '旋转')
      .replaceAll('tower-of-darkness', '暗之塔')
      .replaceAll('tower-of-waters', '水之塔')
      .replaceAll('three-critical-hits', '连续3次击中要害')
      .replaceAll('take-damage', '受到伤害')
      .replaceAll('other', '特殊条件')
      .replaceAll('agile-style-move', '迅疾')
      .replaceAll('strong-style-move', '刚猛')
      .replaceAll('recoil-damage', '反伤')
      .replaceAll('Water-stone', '水之石')
      .replaceAll('Thunder-stone', '雷之石')
      .replaceAll('Fire-stone', '火之石')
      .replaceAll('Leaf-stone', '叶之石')
      .replaceAll('Moon-stone', '月之石')
      .replaceAll('Sun-stone', '日之石')
      .replaceAll('Shiny-stone', '光之石')
      .replaceAll('Dusk-stone', '暗之石')
      .replaceAll('Dawn-stone', '觉醒之石')
      .replaceAll('Ice-stone', '冰之石')
      .replaceAll('Oval-stone', '浑圆之石')
      .replaceAll('King\'s-rock', '王者之证')
      .replaceAll('Metal-coat', '金属膜')
      .replaceAll('Dragon-scale', '龙之鳞片')
      .replaceAll('Up-grade', '升级数据')
      .replaceAll('Dubious-disc', '可疑补丁')
      .replaceAll('Protector', '护具')
      .replaceAll('Electirizer', '电力增幅器')
      .replaceAll('Magmarizer', '熔岩增幅器')
      .replaceAll('Razor-claw', '锐利之爪')
      .replaceAll('Razor-fang', '锐利之牙')
      .replaceAll('Reaper-cloth', '灵界之布')
      .replaceAll('Prism-scale', '美丽鳞片')
      .replaceAll('Deep-sea-tooth', '深海之牙')
      .replaceAll('Deep-sea-scale', '深海鳞片')
      .replaceAll('Sachet', '香袋')
      .replaceAll('Whipped-dream', '泡沫奶油')
      .replaceAll('Strawberry-sweet', '草莓糖饰')
      .replaceAll('Love-sweet', '爱心糖饰')
      .replaceAll('Berry-sweet', '野莓糖饰')
      .replaceAll('Clover-sweet', '幸运草糖饰')
      .replaceAll('Flower-sweet', '花朵糖饰')
      .replaceAll('Star-sweet', '星星糖饰')
      .replaceAll('Ribbon-sweet', '蝴蝶结糖饰')
      .replaceAll('Galarica-cuff', '伽勒尔手环')
      .replaceAll('Galarica-wreath', '伽勒尔花环')
      .replaceAll('Black-augurite', '黑奇石')
      .replaceAll('Peat-block', '泥炭块')
      .replaceAll('Auspecious-armor', '庆贺之铠')
      .replaceAll('Malicious-armor', '咒术之铠')
      .replaceAll('Leader\'s-crest', '首领之证')
      .replaceAll('Unremarkable-teacup', '凡作茶碗')
      .replaceAll('Masterpiece-teacup', '杰作茶碗')
      .replaceAll('Syrupy-apple', '蜜汁苹果')
      .replaceAll('Tart-apple', '酸酸苹果')
      .replaceAll('Sweet-apple', '甜甜苹果')
      .replaceAll('Cracked-pot', '破裂的茶壶')
      .replaceAll('Chipped-pot', '缺损的茶壶')
      .replaceAll('Scroll-of-darkness', '暗之挂轴')
      .replaceAll('Scroll-of-waters', '水之挂轴')
      .replaceAll('Ability-patch', '特性膏药')
      .replaceAll('Lv.', 'Lv.')
      .replaceAll(getMegaTrigger, 'mega')
      .replaceAll('道具：', '')
      .replaceAll('Item:', '')
      .replaceAll('item: ', '')
      .trim();
}

const getMegaTrigger = 'mega';
