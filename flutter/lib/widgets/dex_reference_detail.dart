import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dex/dex_filter.dart';
import '../features/dex/dex_game_scope.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../widgets/sticker_card.dart';

enum DexReferenceKind {
  nature,
  eggGroup,
  item,
  weather,
  terrain,
  status,
  generic,
}

DexReferenceKind referenceKindForFilename(String filename) {
  final lower = filename.toLowerCase();
  if (lower.contains('nature')) {
    return DexReferenceKind.nature;
  }
  if (lower.contains('egg_group')) {
    return DexReferenceKind.eggGroup;
  }
  if (lower.contains('item')) {
    return DexReferenceKind.item;
  }
  if (lower.contains('weather')) {
    return DexReferenceKind.weather;
  }
  if (lower.contains('terrain')) {
    return DexReferenceKind.terrain;
  }
  if (lower.contains('status')) {
    return DexReferenceKind.status;
  }
  return DexReferenceKind.generic;
}

String referencePrimaryLabel(Map<String, dynamic> entry) {
  final zh = entry['nameZh'] as String?;
  if (zh != null && zh.isNotEmpty) {
    return zh;
  }
  return entry['nameEn'] as String? ?? entry['slug'] as String? ?? '—';
}

/// Stat key or Chinese label → display label in Chinese.
String natureStatLabelZh(String? statKey) {
  if (statKey == null || statKey.isEmpty) {
    return '';
  }
  final direct = statLabelsZh[statKey];
  if (direct != null) {
    return direct;
  }
  final normalized = statKey.replaceAllMapped(
    RegExp(r'([A-Z])'),
    (match) => '-${match.group(1)!.toLowerCase()}',
  );
  return statLabelsZh[normalized] ?? statKey;
}

/// PokeAPI flavor slug → Chinese (辣/涩/甜/苦/酸).
String flavorLabelZh(String? slug) {
  if (slug == null || slug.isEmpty) {
    return '';
  }
  return flavorLabelsZh[slug] ?? slug;
}

/// Format nature stat change line, e.g. `↑ 攻击 · ↓ 特攻`.
String formatNatureStatLine({
  String? increasedStat,
  String? decreasedStat,
  String? increasedStatZh,
  String? decreasedStatZh,
}) {
  final increased = increasedStatZh?.isNotEmpty == true
      ? increasedStatZh!
      : natureStatLabelZh(increasedStat);
  final decreased = decreasedStatZh?.isNotEmpty == true
      ? decreasedStatZh!
      : natureStatLabelZh(decreasedStat);
  if (increased.isEmpty && decreased.isEmpty) {
    return AppZh.dexReferenceNatureNeutral;
  }
  final parts = <String>[];
  if (increased.isNotEmpty) {
    parts.add('↑ $increased');
  }
  if (decreased.isNotEmpty) {
    parts.add('↓ $decreased');
  }
  return parts.join(' · ');
}

String itemCategoryLabelZh(String? category) {
  if (category == null || category.isEmpty) {
    return '';
  }
  return itemCategoryLabelsZh[category] ?? category;
}

String? itemCostLabel(Object? cost) {
  if (cost == null) {
    return null;
  }
  return AppZh.dexReferenceItemCost('$cost');
}

Map<String, double>? parseTypeModifiers(Map<String, dynamic> entry) {
  final raw = entry['typeModifiers'] ?? entry['typeMultipliers'];
  if (raw is! Map) {
    return null;
  }
  final modifiers = <String, double>{};
  for (final mapEntry in raw.entries) {
    final value = mapEntry.value;
    if (value is num) {
      modifiers['${mapEntry.key}'] = value.toDouble();
    }
  }
  return modifiers.isEmpty ? null : modifiers;
}

String? referenceDescriptionZh(Map<String, dynamic> entry) {
  final direct = entry['descriptionZh'] as String?;
  if (direct != null && direct.isNotEmpty) {
    return direct;
  }
  final slug = entry['slug'] as String?;
  if (slug == null) {
    return null;
  }
  return referenceFallbackDescriptionsZh[slug];
}

Map<String, double>? referenceTypeModifiers(Map<String, dynamic> entry) {
  final parsed = parseTypeModifiers(entry);
  if (parsed != null) {
    return parsed;
  }
  final slug = entry['slug'] as String?;
  if (slug == null) {
    return null;
  }
  return referenceFallbackTypeModifiers[slug];
}

IconData referenceConditionIcon(String? slug, DexReferenceKind kind) {
  if (slug == null) {
    return Icons.info_outline_rounded;
  }
  if (kind == DexReferenceKind.weather) {
    return switch (slug) {
      'sun' || 'harsh-sunlight' => Icons.wb_sunny_rounded,
      'rain' || 'heavy-rain' => Icons.water_drop_rounded,
      'sandstorm' => Icons.grain_rounded,
      'hail' || 'snow' => Icons.ac_unit_rounded,
      'fog' => Icons.foggy,
      'strong-winds' || 'strong-winds-primal' => Icons.air_rounded,
      _ => Icons.cloud_rounded,
    };
  }
  if (kind == DexReferenceKind.terrain) {
    return switch (slug) {
      'electric' => Icons.bolt_rounded,
      'grassy' => Icons.grass_rounded,
      'psychic' => Icons.psychology_rounded,
      'misty' => Icons.blur_on_rounded,
      _ => Icons.landscape_rounded,
    };
  }
  return switch (slug) {
    'burn' => Icons.local_fire_department_outlined,
    'freeze' => Icons.ac_unit,
    'paralysis' => Icons.flash_on_rounded,
    'poison' || 'bad-poison' => Icons.science_outlined,
    'sleep' || 'yawn' => Icons.bedtime_outlined,
    'confusion' => Icons.sync_problem_rounded,
    _ => Icons.healing_outlined,
  };
}

void showJsonReferenceDetailSheet(
  BuildContext context, {
  required Map<String, dynamic> entry,
  required DexReferenceKind kind,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: DexReferenceDetailBody(entry: entry, kind: kind),
          ),
        ),
      );
    },
  );
}

class DexReferenceDetailBody extends StatelessWidget {
  const DexReferenceDetailBody({
    super.key,
    required this.entry,
    required this.kind,
  });

  final Map<String, dynamic> entry;
  final DexReferenceKind kind;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReferenceHeader(entry: entry),
        const SizedBox(height: 12),
        switch (kind) {
          DexReferenceKind.nature => NatureReferenceDetail(entry: entry),
          DexReferenceKind.eggGroup => EggGroupReferenceDetail(entry: entry),
          DexReferenceKind.item => ItemReferenceDetail(entry: entry),
          DexReferenceKind.weather ||
          DexReferenceKind.terrain ||
          DexReferenceKind.status =>
            ConditionReferenceDetail(entry: entry, kind: kind),
          DexReferenceKind.generic => GenericReferenceDetail(entry: entry),
        },
      ],
    );
  }
}

class _ReferenceHeader extends StatelessWidget {
  const _ReferenceHeader({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          referencePrimaryLabel(entry),
          style: SecondaryTypography.onCard.h15.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        if (entry['nameEn'] != null)
          Text(
            entry['nameEn'] as String,
            style: SecondaryTypography.onCard.small12.copyWith(
              color: TitoColors.mutedInk,
            ),
          ),
      ],
    );
  }
}

class NatureReferenceDetail extends StatelessWidget {
  const NatureReferenceDetail({super.key, required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final statLine = formatNatureStatLine(
      increasedStat: entry['increasedStat'] as String?,
      decreasedStat: entry['decreasedStat'] as String?,
      increasedStatZh: entry['increasedStatZh'] as String?,
      decreasedStatZh: entry['decreasedStatZh'] as String?,
    );
    final likes = flavorLabelZh(entry['likesFlavor'] as String?);
    final hates = flavorLabelZh(entry['hatesFlavor'] as String?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StickerCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppZh.dexReferenceNatureStats,
                style: SecondaryTypography.onCard.body14.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                statLine,
                style: SecondaryTypography.onCard.body14.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (likes.isNotEmpty || hates.isNotEmpty) ...[
          const SizedBox(height: 8),
          StickerCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppZh.dexReferenceNatureFlavors,
                  style: SecondaryTypography.onCard.body14.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (likes.isNotEmpty)
                  Text(
                    AppZh.dexReferenceLikesFlavor(likes),
                    style: SecondaryTypography.onCard.body14,
                  ),
                if (hates.isNotEmpty)
                  Text(
                    AppZh.dexReferenceHatesFlavor(hates),
                    style: SecondaryTypography.onCard.body14,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class EggGroupReferenceDetail extends StatelessWidget {
  const EggGroupReferenceDetail({super.key, required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final slug = entry['slug'] as String?;
    final label = referencePrimaryLabel(entry);

    return FilledButton(
      onPressed: slug == null
          ? null
          : () {
              Navigator.pop(context);
              dexFilterController.setFilter(
                DexFilter(
                  eggGroupSlug: slug,
                  labelZh: AppZh.dexFilterByEggGroup(label),
                ),
              );
              context.go('/dex');
            },
      child: Text(AppZh.dexReferenceViewEggGroupPokemon),
    );
  }
}

class ItemReferenceDetail extends StatelessWidget {
  const ItemReferenceDetail({super.key, required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final category = entry['category'] as String? ?? entry['categoryEn'] as String?;
    final categoryLabel = itemCategoryLabelZh(category);
    final costLabel = itemCostLabel(entry['cost']);
    final effect = referenceDescriptionZh(entry) ??
        entry['effectZh'] as String? ??
        entry['shortEffectZh'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (categoryLabel.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: _CategoryBadge(label: categoryLabel),
          ),
          const SizedBox(height: 8),
        ],
        if (costLabel != null) ...[
          Text(
            costLabel,
            style: SecondaryTypography.onCard.body14.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
        ],
        StickerCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppZh.dexReferenceItemEffect,
                style: SecondaryTypography.onCard.body14.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                effect?.isNotEmpty == true
                    ? effect!
                    : AppZh.dexReferenceNoEffect,
                style: SecondaryTypography.onCard.body14,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ConditionReferenceDetail extends StatelessWidget {
  const ConditionReferenceDetail({
    super.key,
    required this.entry,
    required this.kind,
  });

  final Map<String, dynamic> entry;
  final DexReferenceKind kind;

  @override
  Widget build(BuildContext context) {
    final slug = entry['slug'] as String?;
    final description = referenceDescriptionZh(entry);
    final modifiers = referenceTypeModifiers(entry);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (slug != null)
          Row(
            children: [
              Icon(
                referenceConditionIcon(slug, kind),
                color: TitoColors.ink,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  description ?? AppZh.dexReferenceNoEffect,
                  style: SecondaryTypography.onCard.body14,
                ),
              ),
            ],
          )
        else if (description != null)
          Text(description, style: SecondaryTypography.onCard.body14),
        if (modifiers != null && modifiers.isNotEmpty) ...[
          const SizedBox(height: 12),
          ReferenceTypeModifierChips(modifiers: modifiers),
        ],
      ],
    );
  }
}

class GenericReferenceDetail extends StatelessWidget {
  const GenericReferenceDetail({super.key, required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final description = referenceDescriptionZh(entry);
    if (description == null) {
      return const SizedBox.shrink();
    }
    return Text(description, style: SecondaryTypography.onCard.body14);
  }
}

class ReferenceTypeModifierChips extends StatelessWidget {
  const ReferenceTypeModifierChips({super.key, required this.modifiers});

  final Map<String, double> modifiers;

  @override
  Widget build(BuildContext context) {
    final entries = modifiers.entries.toList()
      ..sort((a, b) {
        final ai = typeGridOrder.indexOf(a.key);
        final bi = typeGridOrder.indexOf(b.key);
        return (ai == -1 ? 99 : ai).compareTo(bi == -1 ? 99 : bi);
      });

    return StickerCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.dexReferenceTypeModifiers,
            style: SecondaryTypography.onCard.body14.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: entries.map((entry) {
              return _TypeModifierChip(type: entry.key, multiplier: entry.value);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TypeModifierChip extends StatelessWidget {
  const _TypeModifierChip({required this.type, required this.multiplier});

  final String type;
  final double multiplier;

  @override
  Widget build(BuildContext context) {
    final label = _modifierLabel(multiplier);
    final color = _modifierColor(multiplier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: typeTileColor(type),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TitoColors.ink, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(typeIconData(type), size: 12, color: TitoColors.ink),
          const SizedBox(width: 3),
          Text(
            typeNameZh(type),
            style: SecondaryTypography.onCard.small12.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: SecondaryTypography.onCard.small12.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _modifierLabel(double multiplier) {
    if (multiplier == 0) {
      return '⊘';
    }
    if (multiplier >= 2) {
      return '×2';
    }
    if (multiplier <= 0.5) {
      return '×0.5';
    }
    if (multiplier > 1) {
      return '×${multiplier.toStringAsFixed(1)}';
    }
    return '×1';
  }

  Color _modifierColor(double multiplier) {
    if (multiplier >= 2) {
      return const Color(0xFF2E9E5B);
    }
    if (multiplier <= 0) {
      return TitoColors.mutedInk;
    }
    if (multiplier <= 0.5) {
      return const Color(0xFFE07B35);
    }
    return TitoColors.ink;
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: TitoColors.softYellow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TitoColors.ink, width: 2),
      ),
      child: Text(
        label,
        style: SecondaryTypography.onCard.small12.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

IconData moveCategoryIcon(String category) => switch (category) {
      'physical' => Icons.sports_martial_arts_rounded,
      'special' => Icons.auto_awesome_rounded,
      'status' => Icons.tips_and_updates_outlined,
      _ => Icons.help_outline_rounded,
    };

String moveCategoryLabelZh(String category) {
  return moveCategoryLabelsZh[category] ?? category;
}

String formatMoveStatLine({
  required String category,
  int? power,
  int? accuracy,
  int? pp,
}) {
  final parts = <String>[
    moveCategoryLabelZh(category),
  ];
  if (power != null) {
    parts.add('${AppZh.dexReferenceMovePowerSymbol} $power');
  }
  if (accuracy != null) {
    parts.add('${AppZh.dexReferenceMoveAccuracySymbol} $accuracy');
  }
  if (pp != null) {
    parts.add('${AppZh.dexReferenceMovePpSymbol} $pp');
  }
  return parts.join(' · ');
}

/// Fallback descriptions when CDN JSON has no `descriptionZh`.
const referenceFallbackDescriptionsZh = <String, String>{
  'sun': '大晴天：火属性招式威力提升，水属性招式威力降低。',
  'rain': '下雨：水属性招式威力提升，火属性招式威力降低。',
  'sandstorm': '沙暴：非岩石/地面/钢属性宝可梦每回合受到伤害。',
  'hail': '冰雹：非冰属性宝可梦每回合受到伤害。',
  'snow': '下雪：冰属性防御提升（现代世代规则）。',
  'fog': '浓雾：命中率降低（部分世代）。',
  'electric': '电气场地：电属性招式威力提升，宝可梦不会陷入睡眠。',
  'grassy': '青草场地：草属性招式威力提升，地面上的宝可梦每回合回复 HP。',
  'psychic': '精神场地：超能力属性招式威力提升，优先度招式无效。',
  'misty': '薄雾场地：龙属性招式威力降低，状态异常无法施加。',
  'burn': '灼伤：攻击减半，每回合损失 HP。',
  'freeze': '冰冻：无法行动，直到解除。',
  'paralysis': '麻痹：速度减半，有时无法行动。',
  'poison': '中毒：每回合损失 HP。',
  'bad-poison': '剧毒：每回合损失递增的 HP。',
  'sleep': '睡眠：无法行动，持续若干回合。',
  'confusion': '混乱：有时对自身造成伤害。',
};

/// Fallback attack-type modifiers keyed by weather/terrain slug.
const referenceFallbackTypeModifiers = <String, Map<String, double>>{
  'sun': {'fire': 1.5, 'water': 0.5},
  'harsh-sunlight': {'fire': 1.5, 'water': 0.5},
  'rain': {'water': 1.5, 'fire': 0.5},
  'heavy-rain': {'water': 1.5, 'fire': 0.5},
  'electric': {'electric': 1.3},
  'grassy': {'grass': 1.3},
  'psychic': {'psychic': 1.3},
  'misty': {'dragon': 0.5},
};
