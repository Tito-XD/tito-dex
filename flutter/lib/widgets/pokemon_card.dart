import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dex/dex_models.dart';
import '../features/dex/version_availability.dart';
import '../l10n/app_zh.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'dex_sprite_image.dart';
import 'handheld_input.dart';
import 'sticker_card.dart';
import 'sticker_pressable.dart';
import 'type_badge.dart';

String pokemonCardHeroTag(PokemonSummary summary) =>
    'pokemon-card-${summary.id}-${summary.spriteResourceId ?? summary.id}';

/// Shared Dex-detail header geometry. The grid→detail flight shuttle, the
/// transition (skeleton) header and the loaded header all read these so the
/// sprite lands exactly on its plate and the header never shifts when the
/// detail data arrives.
const double titoDetailHeaderLabelRowHeight = 16;
const double titoDetailHeaderLabelGap = 6;
const double titoDetailHeaderPlateGap = 12;

double titoDetailHeaderPlateSize(bool square) => square ? 84 : 92;

EdgeInsets titoDetailHeaderPadding(bool square) => EdgeInsets.symmetric(
  horizontal: square ? 10 : 12,
  vertical: square ? 8 : 10,
);

/// Typed GoRouter payload used by the Dex grid so the detail route can build
/// its shared-element destination before the full detail JSON has loaded.
class PokemonDetailTransition {
  const PokemonDetailTransition({required this.summary, this.detailFuture});

  final PokemonSummary summary;

  /// Starts the local bundle read before navigation. The detail route can let
  /// the Hero fly first while the same Future continues in the background.
  final Future<PokemonDetail>? detailFuture;
}

/// Sprite-only shared element between a Dex grid card and the detail
/// header's sprite plate. Both sides wrap just the creature artwork, so the
/// default flight IS the whole choreography: the sprite travels from its
/// grid slot to the header position while the card canvas, plate and copy
/// stay out of the flight and fade in only once the route settles (see
/// [PokemonDetailTransitionHeader]). The earlier canvas-expand shuttle
/// (which grew a hand-laid card around the sprite mid-flight) cross-faded
/// against the real header fading in with the route — the "name card
/// flashes on entry" report — and was deleted in favour of this.
class PokemonCardTransitionHero extends StatelessWidget {
  const PokemonCardTransitionHero({
    super.key,
    required this.summary,
    required this.child,
  });

  final PokemonSummary summary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: pokemonCardHeroTag(summary),
      // Android predictive back owns the interactive pop. Letting this Hero
      // scrub the same route controller could strand the sprite mid-flight
      // when a quick gesture interrupted entry. Forward navigation and normal
      // button pops still use the shared element; edge gestures stay generic.
      transitionOnUserGestures: false,
      // A direct bounds interpolation keeps the creature on a straight line
      // between the grid slot and the header plate; the default arc tween
      // drifts sideways on wide handheld layouts.
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      child: child,
    );
  }
}

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
          key: ValueKey<String>('pokemon-card-tap-${summary.id}'),
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
                    // The sprite alone is the shared element. The card shell
                    // (number, name, types) stays anchored in the grid while
                    // the creature flies to the detail header; offstaging
                    // the whole card punched a hole in the list and lost the
                    // exact sprite rect the flight must start from.
                    Expanded(
                      child: PokemonCardTransitionHero(
                        summary: summary,
                        child: DexSpriteImage(
                          source: summary.displaySpritePath,
                          height: null,
                          fit: BoxFit.contain,
                        ),
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
      final child = node.children.first;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EvolutionCard(node: node, highlighted: node.id == highlightId),
          const Icon(Icons.arrow_downward_rounded, color: TitoColors.ink),
          _EvolutionTriggerLabel(node: child),
          _buildNode(context, child),
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
                child: Icon(Icons.arrow_forward_rounded, color: TitoColors.ink),
              ),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_downward_rounded,
                    color: TitoColors.ink,
                  ),
                  _EvolutionTriggerLabel(node: children[i]),
                  _childCard(context, children[i]),
                ],
              ),
            ),
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
      return EvolutionChainVerticalView(root: node, highlightId: highlightId);
    }
    return _EvolutionCard(node: node, highlighted: node.id == highlightId);
  }
}

class _EvolutionTriggerLabel extends StatelessWidget {
  const _EvolutionTriggerLabel({required this.node});

  /// The evolution *target* — its `triggers` describe the step leading in.
  final EvolutionNode node;

  @override
  Widget build(BuildContext context) {
    final label = _evolutionStepLabel(node);
    if (label == null || label.isEmpty) return const SizedBox.shrink();
    // A link-trade-only step can never be done alone on one cartridge —
    // mark the pill so the lock is visible at a glance.
    final tradeLocked = evolutionRequiresTrade(node);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: TitoColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: tradeLocked ? TitoColors.coral : TitoColors.ink,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tradeLocked) ...[
              const Icon(
                Icons.swap_horiz_rounded,
                size: 12,
                color: TitoColors.coral,
              ),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              textAlign: TextAlign.center,
              style: context.tito.caption.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label for the step into [node]: structured triggers when the bundle has
/// them (trade-with-item shows its item, 美纳斯-style alternatives join with
/// 「/」), the flattened `triggerZh` otherwise.
String? _evolutionStepLabel(EvolutionNode node) {
  final triggers = node.triggers;
  if (triggers.isEmpty) {
    final legacy = node.triggerZh;
    return legacy == null ? null : _triggerLabel(legacy);
  }
  final labels = <String>[];
  for (final trigger in triggers) {
    final label = evolutionTriggerLabelZh(trigger);
    if (label.isNotEmpty && !labels.contains(label)) {
      labels.add(label);
    }
    if (labels.length == 2) break; // Keep the pill readable.
  }
  return labels.isEmpty ? node.triggerZh : labels.join(' / ');
}

String evolutionTriggerLabelZh(EvolutionTrigger trigger) {
  final parts = <String>[];
  if (trigger.isTrade) {
    parts.add('通讯交换');
    if (trigger.heldItem != null) {
      parts.add(_itemLabelZh(trigger.heldItem!));
    }
    if (trigger.tradeSpecies != null) {
      parts.add('与${_speciesLabelZh(trigger.tradeSpecies!)}交换');
    }
  } else if (trigger.item != null) {
    parts.add(_itemLabelZh(trigger.item!));
  } else if (trigger.minLevel != null) {
    parts.add('Lv.${trigger.minLevel}');
  } else if (trigger.trigger != null && trigger.trigger != 'level-up') {
    parts.add(_triggerLabel(trigger.trigger!));
  }
  if (trigger.minHappiness != null) {
    parts.add('亲密度');
  }
  if (trigger.minBeauty != null) {
    parts.add('美丽度');
  }
  if (trigger.minAffection != null) {
    parts.add('友好度≥${trigger.minAffection}');
  }
  if (trigger.knownMove != null) {
    parts.add('学会${_moveLabelZh(trigger.knownMove!)}');
  }
  if (trigger.knownMoveType != null) {
    parts.add('学会${_typeLabelZh(trigger.knownMoveType!)}招式');
  }
  if (trigger.location != null) {
    parts.add('在${_evolutionLocationLabelZh(trigger.location!)}');
  }
  if (trigger.partySpecies != null) {
    parts.add('同行有${_speciesLabelZh(trigger.partySpecies!)}');
  }
  if (trigger.partyType != null) {
    parts.add('同行有${_typeLabelZh(trigger.partyType!)}属性');
  }
  if (trigger.gender != null) {
    parts.add(trigger.gender == 1 ? '雌性' : '雄性');
  }
  if (trigger.relativePhysicalStats != null) {
    parts.add(switch (trigger.relativePhysicalStats!) {
      -1 => '攻击＜防御',
      0 => '攻击＝防御',
      _ => '攻击＞防御',
    });
  }
  final time = switch (trigger.timeOfDay) {
    'day' => '白天',
    'night' => '夜晚',
    _ => null,
  };
  if (time != null) {
    parts.add(time);
  }
  if (trigger.needsOverworldRain) {
    parts.add('雨天');
  }
  if (trigger.turnUpsideDown) {
    parts.add('倒置主机');
  }
  if (parts.isEmpty && trigger.trigger != null) {
    parts.add(_triggerLabel(trigger.trigger!));
  }
  return parts.join(' · ');
}

String _moveLabelZh(String slug) =>
    const {
      'ancient-power': '原始之力',
      'barb-barrage': '毒千针',
      'double-hit': '二连击',
      'dragon-cheer': '龙声鼓舞',
      'dragon-pulse': '龙之波动',
      'hyper-drill': '强力钻',
      'mimic': '模仿',
      'rollout': '滚动',
      'stomp': '踩踏',
      'taunt': '挑衅',
      'twin-beam': '双光束',
    }[slug] ??
    _humanizeSlug(slug);

String _speciesLabelZh(String slug) =>
    const {'karrablast': '盖盖虫', 'shelmet': '小嘴蜗', 'remoraid': '铁炮鱼'}[slug] ??
    _humanizeSlug(slug);

String _typeLabelZh(String slug) =>
    const {'dark': '恶', 'fairy': '妖精'}[slug] ?? _humanizeSlug(slug);

String _evolutionLocationLabelZh(String slug) =>
    const {
      'blush-mountain': '火特力山',
      'chargestone-cave': '电气石洞穴',
      'eterna-forest': '百代森林',
      'frost-cavern': '冰结洞窟',
      'kalos-route-13': '卡洛斯13号道路',
      'kalos-route-20': '卡洛斯20号道路',
      'lush-jungle': '树荫丛林',
      'mount-lanakila': '拉纳基拉山',
      'mt-coronet': '天冠山',
      'new-mauville': '新紫堇',
      'petalburg-woods': '橙华森林',
      'pinwheel-forest': '矢车森林',
      'shoal-cave': '浅滩洞穴',
      'sinnoh-route-217': '神奥217号道路',
      'twist-mountain': '螺旋山',
      'vast-poni-canyon': '波尼大峡谷',
    }[slug] ??
    _humanizeSlug(slug);

String _humanizeSlug(String slug) => slug
    .split('-')
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join(' ');

/// PokeAPI item slug → the Chinese names [_triggerLabel] already carries.
String _itemLabelZh(String slug) {
  if (slug.isEmpty) return slug;
  final capitalized = slug[0].toUpperCase() + slug.substring(1);
  return _triggerLabel(capitalized);
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
