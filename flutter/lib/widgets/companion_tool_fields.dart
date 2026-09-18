import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'type_badge.dart';

import '../l10n/app_locale.dart';
import '../l10n/app_zh.dart';
import '../l10n/localized_names.dart';
import '../features/companion/battle_math.dart';
import '../features/dex/ability_type_modifiers.dart';
import '../features/dex/battle_effectiveness.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/type_chart.dart';
import '../theme/app_visual_style.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_surface_tokens.dart';
import '../theme/trainer_journal.dart';
import '../widgets/handheld_input.dart';
import '../widgets/retro_forms.dart';
import '../widgets/sticker_card.dart';

/// Compact selector for side-by-side combatant forms; long labels truncate
/// only in the field, while the menu can wrap to keep every option readable.
class CompanionSelectField<T> extends StatelessWidget {
  const CompanionSelectField({
    super.key,
    this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String? label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (label != null) ...[
        Text(
          label!,
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
      ],
      InputDecorator(
        decoration: retroInsetDecoration(context: context).copyWith(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            itemHeight: null,
            dropdownColor: TitoSurfaceTokens.of(context).cardFill,
            style: SecondaryTypography.onCard.body14,
            selectedItemBuilder: (context) => [
              for (final text in options.values)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
            items: [
              for (final entry in options.entries)
                DropdownMenuItem(
                  value: entry.key,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(entry.value),
                      ),
                    ),
                  ),
                ),
            ],
            onChanged: (next) {
              if (next != null) {
                onChanged(next);
              }
            },
          ),
        ),
      ),
    ],
  );
}

class CompanionNumberField extends StatelessWidget {
  const CompanionNumberField({
    super.key,
    required this.label,
    required this.controller,
    this.max = 999,
    this.min = 0,
    this.hint,
    this.onChanged,
    this.inline = false,
  });

  final String label;
  final TextEditingController controller;
  final int max;
  final int min;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final caption = Text(
      label,
      style: SecondaryTypography.onCard.small12.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
    final field = TextField(
      controller: controller,
      scrollPadding: const EdgeInsets.all(64),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: SecondaryTypography.onCard.body14.copyWith(
        fontWeight: FontWeight.w800,
      ),
      decoration: retroInsetDecoration(context: context, hintText: hint)
          .copyWith(
            isDense: true,
            constraints: const BoxConstraints(minHeight: 44),
            contentPadding: EdgeInsets.symmetric(
              horizontal: inline ? 8 : 12,
              vertical: 10,
            ),
          ),
      onChanged: onChanged,
    );
    if (inline) {
      return Row(
        children: [
          Expanded(child: caption),
          const SizedBox(width: 6),
          Expanded(child: field),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [caption, const SizedBox(height: 4), field],
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
            // Theme chipTheme supplies fill / selected / outline / radius.
            return FilterChip(
              selected: active,
              showCheckmark: false,
              label: Text(typeNameZh(type)),
              avatar: TypeIconImage(typeEn: type, size: 16),
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
      return AppZh.noneSelected;
    }
    return widget.selected.map(typeNameZh).join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        HandheldFocusDecorator(
          onActivate: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(TitoRadii.md),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(TitoRadii.md),
              child: Ink(
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: appVisualStyle.usesFlatUi
                      ? scheme.surfaceContainerHighest
                      : appVisualStyle.usesSolidPlastic
                      ? Colors.white.withValues(alpha: 0.8)
                      : TitoColors.card,
                  borderRadius: BorderRadius.circular(TitoRadii.md),
                  border: _companionControlBorder(context),
                ),
                child: Row(
                  children: [
                    if (widget.selected.isEmpty)
                      Icon(
                        Icons.category_rounded,
                        size: 20,
                        color: appVisualStyle.usesFlatUi
                            ? scheme.onSurfaceVariant
                            : TitoColors.mutedInk,
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final type in widget.selected) ...[
                            TypeIconImage(typeEn: type, size: 20),
                            const SizedBox(width: 4),
                          ],
                        ],
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectionLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SecondaryTypography.onCard.body14.copyWith(
                          fontWeight: FontWeight.w800,
                          color: appVisualStyle.usesFlatUi
                              ? scheme.onSurface
                              : null,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: appVisualStyle.usesFlatUi
                          ? scheme.onSurfaceVariant
                          : TitoColors.ink,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 64,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: typeGridOrder.length,
            itemBuilder: (context, index) {
              final type = typeGridOrder[index];
              final active = widget.selected.contains(type);
              return HandheldFocusDecorator(
                onActivate: () => _toggleType(type),
                borderRadius: BorderRadius.circular(TitoRadii.sm),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _toggleType(type),
                    borderRadius: BorderRadius.circular(TitoRadii.sm),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: typeTileColor(type),
                        borderRadius: BorderRadius.circular(TitoRadii.sm),
                        border: _typeTileBorder(active),
                      ),
                      child: Center(
                        child: TypeIconImage(typeEn: type, size: 22),
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

/// Outline for the collapsible picker header (field-like control).
BoxBorder? _companionControlBorder(BuildContext context) =>
    TitoSurfaceTokens.of(context).surface(TitoSurfaceRole.element).border;

/// Type grid tile outline: the selected tile always gets a full ink ring;
/// idle tiles fade the ring (TJ), use a milky hairline (Plastic), or go
/// borderless (Flat).
BoxBorder? _typeTileBorder(bool active) {
  if (active) {
    return appVisualStyle.usesTrainerJournal
        ? Border.all(
            color: TrainerJournal.selectedEdge,
            width: TitoBorders.journalElement,
          )
        : Border.all(color: TitoColors.ink, width: TitoBorders.element);
  }
  if (appVisualStyle.usesTrainerJournal) {
    return null;
  }
  if (appVisualStyle.usesSolidPlastic) {
    return Border.all(
      color: Colors.white.withValues(alpha: 0.7),
      width: TitoBorders.glass,
    );
  }
  return null;
}

class CompanionSectionCard extends StatelessWidget {
  const CompanionSectionCard({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final EdgeInsets? padding;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      padding: padding ?? const EdgeInsets.all(16),
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
          SizedBox(height: padding == null ? 12 : 8),
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
  Widget build(BuildContext context) => CompanionSelectField<NatureModifier>(
    label: AppZh.natureLabel,
    value: selected,
    options: {for (final value in battleNatures) value: value.label},
    onChanged: onChanged,
  );
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
  Widget build(BuildContext context) => CompanionSelectField<BattleStat>(
    label: AppZh.statLabel,
    value: selected,
    options: {for (final value in BattleStat.values) value: value.label},
    onChanged: onChanged,
  );
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
          ButtonSegment(value: category, label: Text(category.label)),
      ],
      selected: {selected},
      onSelectionChanged: (value) => onChanged(value.first),
    );
  }
}

String profileLine(String title, List<String> items) {
  final body = items.isEmpty
      ? AppZh.dexNone
      : items.join(AppLocale.pick(zh: '、', en: ', '));
  if (title.isEmpty) {
    return body;
  }
  return AppLocale.pick(zh: '$title：$body', en: '$title: $body');
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
          labelZh: localizedName(
            nameEn: ability.nameEn,
            nameZh: ability.nameZh,
          ),
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

const kStatRelevantAbilitySlugs = {'huge-power', 'pure-power'};

List<DefensiveAbilityOption> statAbilityOptionsFromPokemon(
  List<PokemonAbility> abilities,
) {
  return defensiveAbilityOptionsFrom(abilities)
      .where((option) => kStatRelevantAbilitySlugs.contains(option.slug))
      .toList(growable: false);
}

class PokemonSearchField extends StatelessWidget {
  const PokemonSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.suggestions,
    required this.onQueryChanged,
    required this.onPokemonSelected,
    this.prefixIcon = Icons.search_rounded,
    this.compact = false,
  });

  final TextEditingController controller;
  final String hintText;
  final List<PokemonSummary> suggestions;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<PokemonSummary> onPokemonSelected;
  final IconData prefixIcon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onQueryChanged,
          scrollPadding: const EdgeInsets.all(64),
          style: compact ? SecondaryTypography.onCard.body14 : null,
          // Fill / outline / focus come from the theme's field look.
          decoration: InputDecoration(
            isDense: compact ? true : null,
            constraints: compact ? const BoxConstraints(minHeight: 44) : null,
            hintText: compact ? AppZh.companionPokemonSearchHint : hintText,
            prefixIcon: Icon(prefixIcon, size: compact ? 18 : null),
            prefixIconConstraints: compact
                ? const BoxConstraints(minWidth: 28)
                : null,
            contentPadding: compact
                ? const EdgeInsets.symmetric(horizontal: 6, vertical: 10)
                : null,
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map(
                  (entry) => ActionChip(
                    label: Text(entry.nameZh),
                    onPressed: () => onPokemonSelected(entry),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class LinkedPokemonTypesRow extends StatelessWidget {
  const LinkedPokemonTypesRow({super.key, required this.types});

  final List<String> types;

  @override
  Widget build(BuildContext context) {
    if (types.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      '${AppZh.companionLinkedTypes}：${types.map(typeNameZh).join(' / ')}',
      style: SecondaryTypography.onCard.body14.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class LinkedOrManualTypePicker extends StatelessWidget {
  const LinkedOrManualTypePicker({
    super.key,
    required this.linkedPokemonId,
    required this.label,
    required this.selected,
    required this.onManualChanged,
    this.maxSelected = 2,
  });

  final int? linkedPokemonId;
  final String label;
  final List<String> selected;
  final ValueChanged<List<String>> onManualChanged;
  final int maxSelected;

  @override
  Widget build(BuildContext context) {
    if (linkedPokemonId != null) {
      return LinkedPokemonTypesRow(types: selected);
    }
    return CollapsibleTypePicker(
      label: label,
      selected: selected,
      maxSelected: maxSelected,
      onChanged: onManualChanged,
    );
  }
}

class CompanionAbilitySection extends StatelessWidget {
  const CompanionAbilitySection({
    super.key,
    required this.pokemonLabel,
    required this.manualLabel,
    required this.manualOptions,
    required this.pokemonOptions,
    required this.linkedPokemonId,
    required this.selectedSlug,
    required this.onChanged,
    this.compact = false,
  });

  final String pokemonLabel;
  final String manualLabel;
  final Map<String, String> manualOptions;
  final List<DefensiveAbilityOption> pokemonOptions;
  final int? linkedPokemonId;
  final String? selectedSlug;
  final ValueChanged<String?> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      if (pokemonOptions.isEmpty && linkedPokemonId != null) {
        return const SizedBox.shrink();
      }
      final options = pokemonOptions.isNotEmpty
          ? {
              for (final option in pokemonOptions)
                option.slug: option.isHidden
                    ? AppZh.companionHiddenAbilityOption(option.labelZh)
                    : option.labelZh,
            }
          : manualOptions;
      return CompanionSelectField<String>(
        label: pokemonOptions.isNotEmpty ? pokemonLabel : manualLabel,
        value: options.containsKey(selectedSlug) ? selectedSlug! : '',
        options: {'': AppZh.dexNone, ...options},
        onChanged: (value) => onChanged(value.isEmpty ? null : value),
      );
    }
    if (pokemonOptions.isNotEmpty) {
      return AbilityChipPicker(
        label: pokemonLabel,
        selectedSlug: selectedSlug,
        options: pokemonOptions,
        onChanged: onChanged,
      );
    }
    if (linkedPokemonId != null) {
      return const SizedBox.shrink();
    }
    return ManualAbilityPicker(
      label: manualLabel,
      options: manualOptions,
      selectedSlug: selectedSlug,
      onChanged: onChanged,
    );
  }
}

class AbilityChipPicker extends StatelessWidget {
  const AbilityChipPicker({
    super.key,
    required this.label,
    required this.selectedSlug,
    required this.options,
    required this.onChanged,
  });

  final String label;
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
          label,
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
                      ? AppZh.companionHiddenAbilityOption(option.labelZh)
                      : option.labelZh,
                ),
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

class DefensiveAbilityPicker extends StatelessWidget {
  const DefensiveAbilityPicker({
    super.key,
    required this.selectedSlug,
    required this.options,
    required this.onChanged,
    this.label,
  });

  final String? label;
  final String? selectedSlug;
  final List<DefensiveAbilityOption> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AbilityChipPicker(
      label: label ?? AppZh.companionDefenderAbilityPick,
      selectedSlug: selectedSlug,
      options: options,
      onChanged: onChanged,
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
              label: Text(condition.label),
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
              label: Text(condition.label),
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

    final effectiveType =
        teraType ??
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
    this.compact = false,
  });

  final BattleHeldItem selected;
  final ValueChanged<BattleHeldItem> onChanged;
  final String? typeBoostItemType;
  final ValueChanged<String?>? onTypeBoostChanged;
  final bool compact;

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
        if (compact)
          CompanionSelectField<BattleHeldItem>(
            value: selected,
            options: {
              for (final item in BattleHeldItem.values) item: item.label,
            },
            onChanged: onChanged,
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: BattleHeldItem.values.map((item) {
              return FilterChip(
                selected: selected == item,
                showCheckmark: false,
                label: Text(item.label),
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
    this.compact = false,
  });

  final BattleStatusCondition selected;
  final ValueChanged<BattleStatusCondition> onChanged;
  final bool compact;

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
        if (compact)
          CompanionSelectField<BattleStatusCondition>(
            value: selected,
            options: {
              for (final status in BattleStatusCondition.values)
                status: status.label,
            },
            onChanged: onChanged,
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: BattleStatusCondition.values.map((status) {
              return FilterChip(
                selected: selected == status,
                showCheckmark: false,
                label: Text(status.label),
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
    return BattleToggleChip(
      label: AppZh.companionContactMove,
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Shared battle-condition toggle chip (contact move, critical hit, screens…).
/// Renders as the retro pill toggle with a state dot (see battle template).
class BattleToggleChip extends StatelessWidget {
  const BattleToggleChip({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return StickerPillToggle(label: label, value: value, onChanged: onChanged);
  }
}
