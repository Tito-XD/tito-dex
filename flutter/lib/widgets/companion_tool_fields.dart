import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/companion/battle_math.dart';
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
