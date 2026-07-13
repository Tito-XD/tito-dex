import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_zh.dart';
import '../features/companion/battle_math.dart';
import '../features/dex/ability_type_modifiers.dart';
import '../features/dex/battle_effectiveness.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/type_chart.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../widgets/sticker_card.dart';

class CompanionNumberField extends StatelessWidget {
  const CompanionNumberField({
    super.key,
    required this.label,
    required this.controller,
    this.max = 999,
    this.min = 0,
    this.hint,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final int max;
  final int min;
  final String? hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: SecondaryTypography.onCard.body14.copyWith(
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: TitoColors.card,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: TitoColors.ink, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: TitoColors.ink, width: 2),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  int parsedValue({int fallback = 0}) {
    final value = int.tryParse(controller.text.trim());
    if (value == null) {
      return fallback;
    }
    return value.clamp(min, max);
  }
}

class TypeChipPicker extends StatelessWidget {
  const TypeChipPicker({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.maxSelected = 2,
  });

  final String label;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final int maxSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: typeGridOrder.map((type) {
            final active = selected.contains(type);
            return FilterChip(
              selected: active,
              showCheckmark: false,
              label: Text(typeNameZh(type)),
              avatar: Icon(
                typeIconData(type),
                size: 16,
                color: TitoColors.ink,
              ),
              selectedColor: typeTileColor(type),
              backgroundColor: TitoColors.card,
              side: const BorderSide(color: TitoColors.ink, width: 2),
              onSelected: (next) {
                final updated = List<String>.from(selected);
                if (next) {
                  if (updated.length >= maxSelected) {
                    if (maxSelected == 1) {
                      updated
                        ..clear()
                        ..add(type);
                    } else {
                      updated.removeAt(0);
                      updated.add(type);
                    }
                  } else {
                    updated.add(type);
                  }
                } else {
                  updated.remove(type);
                }
                onChanged(updated);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class CollapsibleTypePicker extends StatefulWidget {
  const CollapsibleTypePicker({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.maxSelected = 2,
  });

  final String label;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final int maxSelected;

  @override
  State<CollapsibleTypePicker> createState() => _CollapsibleTypePickerState();
}

class _CollapsibleTypePickerState extends State<CollapsibleTypePicker> {
  bool _expanded = false;

  void _toggleType(String type) {
    final updated = List<String>.from(widget.selected);
    if (updated.contains(type)) {
      updated.remove(type);
    } else if (widget.maxSelected == 1) {
      updated
        ..clear()
        ..add(type);
    } else if (updated.length >= widget.maxSelected) {
      updated
        ..removeAt(0)
        ..add(type);
    } else {
      updated.add(type);
    }
    widget.onChanged(updated);
  }

  String get _selectionLabel {
    if (widget.selected.isEmpty) {
      return '未选择';
    }
    return widget.selected.map(typeNameZh).join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: TitoColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: TitoColors.ink, width: 2),
              ),
              child: Row(
                children: [
                  if (widget.selected.isEmpty)
                    Icon(
                      Icons.category_rounded,
                      size: 20,
                      color: TitoColors.mutedInk,
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final type in widget.selected) ...[
                          Icon(
                            typeIconData(type),
                            size: 20,
                            color: TitoColors.ink,
                          ),
                          const SizedBox(width: 4),
                        ],
                      ],
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectionLabel,
                      style: SecondaryTypography.onCard.body14.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: TitoColors.ink,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: typeGridOrder.length,
            itemBuilder: (context, index) {
              final type = typeGridOrder[index];
              final active = widget.selected.contains(type);
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _toggleType(type),
                  borderRadius: BorderRadius.circular(8),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: typeTileColor(type),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active ? TitoColors.ink : TitoColors.ink.withValues(alpha: 0.35),
                        width: active ? 3 : 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        typeIconData(type),
                        size: 22,
                        color: TitoColors.ink,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class CompanionSectionCard extends StatelessWidget {
  const CompanionSectionCard({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: SecondaryTypography.onCard.h15),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class NaturePicker extends StatelessWidget {
  const NaturePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final NatureModifier selected;
  final ValueChanged<NatureModifier> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '性格',
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        DropdownMenu<NatureModifier>(
          initialSelection: selected,
          dropdownMenuEntries: [
            for (final nature in battleNatures)
              DropdownMenuEntry(
                value: nature,
                label: nature.labelZh,
              ),
          ],
          onSelected: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
          textStyle: SecondaryTypography.onCard.body14.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class StatPicker extends StatelessWidget {
  const StatPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final BattleStat selected;
  final ValueChanged<BattleStat> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '能力',
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        DropdownMenu<BattleStat>(
          initialSelection: selected,
          dropdownMenuEntries: [
            for (final stat in BattleStat.values)
              DropdownMenuEntry(
                value: stat,
                label: stat.labelZh,
              ),
          ],
          onSelected: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
          textStyle: SecondaryTypography.onCard.body14.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class MoveCategoryPicker extends StatelessWidget {
  const MoveCategoryPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final MoveCategory selected;
  final ValueChanged<MoveCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MoveCategory>(
      segments: [
        for (final category in MoveCategory.values)
          ButtonSegment(
            value: category,
            label: Text(category.labelZh),
          ),
      ],
      selected: {selected},
      onSelectionChanged: (value) => onChanged(value.first),
    );
  }
}

String profileLine(String title, List<String> items) {
  if (items.isEmpty) {
    return '$title：无';
  }
  return '$title：${items.join('、')}';
}

class DefensiveAbilityOption {
  const DefensiveAbilityOption({
    required this.slug,
    required this.labelZh,
    this.isHidden = false,
  });

  final String slug;
  final String labelZh;
  final bool isHidden;
}

List<DefensiveAbilityOption> defensiveAbilityOptionsFrom(
  List<PokemonAbility> abilities,
) {
  return abilities
      .map(
        (ability) => DefensiveAbilityOption(
          slug: abilitySlugFromNameEn(ability.nameEn),
          labelZh: ability.nameZh,
          isHidden: ability.isHidden,
        ),
      )
      .toList(growable: false);
}

/// Auto-select when the Pokémon has exactly one ability (e.g. Cresselia → Levitate).
String? defaultAbilitySlugForOptions(List<DefensiveAbilityOption> options) {
  if (options.length == 1) {
    return options.first.slug;
  }
  return null;
}

List<DefensiveAbilityOption> attackerAbilityOptionsFromPokemon(
  List<PokemonAbility> abilities,
) {
  return defensiveAbilityOptionsFrom(abilities)
      .where((option) => kManualAttackerAbilityOptions.containsKey(option.slug))
      .toList(growable: false);
}

class DefensiveAbilityPicker extends StatelessWidget {
  const DefensiveAbilityPicker({
    super.key,
    required this.selectedSlug,
    required this.options,
    required this.onChanged,
  });

  final String? selectedSlug;
  final List<DefensiveAbilityOption> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppZh.companionDefenderAbilityPick,
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final option in options)
              FilterChip(
                selected: selectedSlug == option.slug,
                showCheckmark: false,
                label: Text(
                  option.isHidden
                      ? '${option.labelZh}（隐藏）'
                      : option.labelZh,
                ),
                selectedColor: TitoColors.mint,
                backgroundColor: TitoColors.card,
                side: const BorderSide(color: TitoColors.ink, width: 2),
                onSelected: (next) {
                  onChanged(next ? option.slug : null);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class ManualAbilityPicker extends StatelessWidget {
  const ManualAbilityPicker({
    super.key,
    required this.label,
    required this.options,
    required this.selectedSlug,
    required this.onChanged,
  });

  final String label;
  final Map<String, String> options;
  final String? selectedSlug;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: options.entries.map((entry) {
            return FilterChip(
              selected: selectedSlug == entry.key,
              showCheckmark: false,
              label: Text(entry.value),
              selectedColor: TitoColors.mint,
              backgroundColor: TitoColors.card,
              side: const BorderSide(color: TitoColors.ink, width: 2),
              onSelected: (next) => onChanged(next ? entry.key : null),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class FieldConditionPicker extends StatelessWidget {
  const FieldConditionPicker({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final FieldCondition selected;
  final ValueChanged<FieldCondition> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: FieldCondition.values.map((condition) {
            return FilterChip(
              selected: selected == condition,
              showCheckmark: false,
              label: Text(condition.labelZh),
              selectedColor: TitoColors.softYellow,
              backgroundColor: TitoColors.card,
              side: const BorderSide(color: TitoColors.ink, width: 2),
              onSelected: (_) => onChanged(condition),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class TerrainConditionPicker extends StatelessWidget {
  const TerrainConditionPicker({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final TerrainCondition selected;
  final ValueChanged<TerrainCondition> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: TerrainCondition.values.map((condition) {
            return FilterChip(
              selected: selected == condition,
              showCheckmark: false,
              label: Text(condition.labelZh),
              selectedColor: TitoColors.softYellow,
              backgroundColor: TitoColors.card,
              side: const BorderSide(color: TitoColors.ink, width: 2),
              onSelected: (_) => onChanged(condition),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class TerastalPicker extends StatelessWidget {
  const TerastalPicker({
    super.key,
    required this.label,
    required this.enabled,
    required this.terastallized,
    required this.teraType,
    required this.fallbackTypes,
    required this.generation,
    required this.onTerastallizedChanged,
    required this.onTeraTypeChanged,
  });

  final String label;
  final bool enabled;
  final bool terastallized;
  final String? teraType;
  final List<String> fallbackTypes;
  final int generation;
  final ValueChanged<bool> onTerastallizedChanged;
  final ValueChanged<String?> onTeraTypeChanged;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const SizedBox.shrink();
    }

    final effectiveType = teraType ??
        (fallbackTypes.isNotEmpty
            ? defaultTeraTypeFor(fallbackTypes, generation)
            : 'normal');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        FilterChip(
          selected: terastallized,
          showCheckmark: false,
          label: Text(AppZh.companionTerastalToggle),
          avatar: Icon(
            Icons.diamond_rounded,
            size: 16,
            color: terastallized ? TitoColors.ink : TitoColors.mutedInk,
          ),
          selectedColor: TitoColors.softYellow,
          backgroundColor: TitoColors.card,
          side: const BorderSide(color: TitoColors.ink, width: 2),
          onSelected: (next) {
            onTerastallizedChanged(next);
            if (next && teraType == null) {
              onTeraTypeChanged(effectiveType);
            }
          },
        ),
        if (terastallized) ...[
          const SizedBox(height: 8),
          CollapsibleTypePicker(
            label: AppZh.companionTerastalType,
            selected: [effectiveType],
            maxSelected: 1,
            onChanged: (types) {
              if (types.isNotEmpty) {
                onTeraTypeChanged(types.first);
              }
            },
          ),
        ],
      ],
    );
  }
}

class HeldItemPicker extends StatelessWidget {
  const HeldItemPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.typeBoostItemType,
    this.onTypeBoostChanged,
  });

  final BattleHeldItem selected;
  final ValueChanged<BattleHeldItem> onChanged;
  final String? typeBoostItemType;
  final ValueChanged<String?>? onTypeBoostChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppZh.companionHeldItemPick,
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: BattleHeldItem.values.map((item) {
            return FilterChip(
              selected: selected == item,
              showCheckmark: false,
              label: Text(item.labelZh),
              selectedColor: TitoColors.mint,
              backgroundColor: TitoColors.card,
              side: const BorderSide(color: TitoColors.ink, width: 2),
              onSelected: (_) => onChanged(item),
            );
          }).toList(),
        ),
        if (selected == BattleHeldItem.typeBoost &&
            onTypeBoostChanged != null) ...[
          const SizedBox(height: 8),
          CollapsibleTypePicker(
            label: AppZh.companionTypeBoostItemType,
            selected: [typeBoostItemType ?? 'normal'],
            maxSelected: 1,
            onChanged: (types) {
              if (types.isNotEmpty) {
                onTypeBoostChanged!(types.first);
              }
            },
          ),
        ],
      ],
    );
  }
}

class StatusConditionPicker extends StatelessWidget {
  const StatusConditionPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final BattleStatusCondition selected;
  final ValueChanged<BattleStatusCondition> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppZh.companionStatusPick,
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: BattleStatusCondition.values.map((status) {
            return FilterChip(
              selected: selected == status,
              showCheckmark: false,
              label: Text(status.labelZh),
              selectedColor: TitoColors.softYellow,
              backgroundColor: TitoColors.card,
              side: const BorderSide(color: TitoColors.ink, width: 2),
              onSelected: (_) => onChanged(status),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class ContactMoveToggle extends StatelessWidget {
  const ContactMoveToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: value,
      showCheckmark: false,
      label: Text(AppZh.companionContactMove),
      selectedColor: TitoColors.mint,
      backgroundColor: TitoColors.card,
      side: const BorderSide(color: TitoColors.ink, width: 2),
      onSelected: onChanged,
    );
  }
}
