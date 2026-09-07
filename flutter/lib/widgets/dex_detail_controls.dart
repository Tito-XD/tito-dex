import 'package:flutter/material.dart';

import '../features/dex/dex_models.dart';
import '../features/game/game_catalog.dart';
import '../features/game/game_edition.dart';
import '../l10n/app_zh.dart';
import '../l10n/localized_names.dart';
import '../theme/app_visual_style.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';

/// One visible context shared by every bottom tab of a Pokémon detail page.
class DexDetailControls extends StatelessWidget {
  const DexDetailControls({
    super.key,
    required this.forms,
    required this.selectedFormKey,
    required this.edition,
    required this.onFormChanged,
    required this.onEditionChanged,
    this.speciesNameZh = '',
  });

  final List<PokemonFormDetail> forms;
  final String? selectedFormKey;
  final GameEdition edition;
  final ValueChanged<PokemonFormDetail> onFormChanged;
  final ValueChanged<GameEdition> onEditionChanged;
  final String speciesNameZh;

  static String selectedFormLabel(PokemonFormDetail form, String speciesName) {
    final label =
        (speciesName.isEmpty
                ? form.nameZh
                : form.nameZh.replaceAll(speciesName, ''))
            .replaceAll(RegExp(r'[（）()]'), '')
            .replaceAll(RegExp(r'\s+'), '')
            .trim();
    return label.isEmpty ? AppZh.dexDetailBaseForm : label;
  }

  static String editionKey(GameEdition edition) =>
      '${edition.slug}:${edition.selectedFlavor ?? ''}';

  @override
  Widget build(BuildContext context) {
    final editions = [GameEdition.general, ...GameEdition.all];
    final scheme = Theme.of(context).colorScheme;
    final flat = appVisualStyle.usesFlatUi;
    final plastic = appVisualStyle.usesSolidPlastic;
    final radius = BorderRadius.circular(TitoRadii.md);
    final style = flat
        ? SecondaryTypography.onCard.body14.copyWith(
            fontSize: 13,
            color: scheme.onSurface,
          )
        : SecondaryTypography.onCard.body14.copyWith(fontSize: 13);
    final labelColor = flat ? scheme.onSurfaceVariant : TitoColors.mutedInk;
    final disabledTextColor = flat
        ? scheme.onSurfaceVariant
        : TitoColors.mutedInk;
    final menuColor = flat
        ? scheme.surfaceContainerHigh
        : plastic
        ? Colors.white.withValues(alpha: 0.96)
        : TitoColors.card;
    final Color fill;
    final Color disabledFill;
    final BoxBorder? outline;
    if (flat) {
      fill = scheme.surfaceContainerHighest;
      disabledFill = scheme.surfaceContainerHighest.withValues(alpha: 0.6);
      outline = null;
    } else if (plastic) {
      fill = Colors.white.withValues(alpha: 0.7);
      disabledFill = Colors.white.withValues(alpha: 0.45);
      outline = Border.all(
        color: Colors.white.withValues(alpha: 0.78),
        width: TitoBorders.glass,
      );
    } else {
      fill = TitoColors.card;
      disabledFill = TitoColors.cardWarm.withValues(alpha: 0.6);
      outline = Border.all(color: TitoColors.ink, width: TitoBorders.card);
    }
    // Keep inset labels on the filled surface while matching adjacent controls.
    Widget outlined(Widget child) => outline == null
        ? child
        : DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(borderRadius: radius, border: outline),
            child: child,
          );
    InputBorder noBorder() => flat
        ? OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none)
        : UnderlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide.none,
          );
    InputDecoration decoration(String label, {bool disabled = false}) =>
        InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: true,
          fillColor: disabled ? disabledFill : fill,
          labelStyle: SecondaryTypography.onCard.small12.copyWith(
            fontSize: 11,
            color: labelColor,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(9, 5, 8, 5),
          border: noBorder(),
          enabledBorder: noBorder(),
          focusedBorder: noBorder(),
          disabledBorder: noBorder(),
        );
    final formLocked = forms.length < 2;
    final formField = DropdownButtonFormField<String>(
      key: ValueKey('detail-form-$selectedFormKey'),
      initialValue: forms.any((form) => form.key == selectedFormKey)
          ? selectedFormKey
          : forms.firstOrNull?.key,
      isExpanded: true,
      menuMaxHeight: 320,
      style: style,
      dropdownColor: menuColor,
      decoration: decoration(AppZh.dexDetailFormField, disabled: formLocked),
      // A single form has nothing to pick: hide the chevron and mute the text
      // so the control reads as a label rather than a broken dropdown.
      icon: formLocked ? const SizedBox.shrink() : null,
      selectedItemBuilder: forms.isEmpty
          ? null
          : (context) => [
              for (final form in forms)
                Text(
                  selectedFormLabel(form, speciesNameZh),
                  overflow: TextOverflow.ellipsis,
                  style: formLocked
                      ? style.copyWith(color: disabledTextColor)
                      : null,
                ),
            ],
      items: forms.isEmpty
          ? [
              DropdownMenuItem(
                value: 'base',
                child: Text(AppZh.dexDetailBaseForm),
              ),
            ]
          : [
              for (final form in forms)
                DropdownMenuItem(
                  value: form.key,
                  child: Text(
                    form.displayName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
      hint: Text(
        AppZh.dexDetailBaseForm,
        style: formLocked ? style.copyWith(color: disabledTextColor) : null,
      ),
      onChanged: formLocked
          ? null
          : (key) => onFormChanged(forms.firstWhere((form) => form.key == key)),
    );
    final versionField = Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey(
              'detail-version-${editionKey(edition.withFlavor(null))}',
            ),
            initialValue: editionKey(edition.withFlavor(null)),
            isExpanded: true,
            menuMaxHeight: 340,
            itemHeight: null,
            style: style,
            dropdownColor: menuColor,
            decoration: decoration(AppZh.dexDetailVersionField),
            selectedItemBuilder: (context) => [
              for (final game in editions)
                Row(
                  children: [
                    GameEditionIcon(edition: game, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        game.referenceGameNameZh,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
            items: [
              for (final game in editions)
                DropdownMenuItem(
                  value: editionKey(game),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(game.referenceGameNameZh),
                        if (game.referenceExpansionZh != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            game.referenceExpansionZh!,
                            style: style.copyWith(
                              fontSize: 11,
                              color: labelColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
            onChanged: (key) => onEditionChanged(
              editions.firstWhere((game) => editionKey(game) == key),
            ),
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 300
            ? Column(
                children: [
                  outlined(formField),
                  const SizedBox(height: 12),
                  outlined(versionField),
                ],
              )
            : Row(
                children: [
                  Expanded(flex: 4, child: outlined(formField)),
                  const SizedBox(width: 10),
                  Expanded(flex: 6, child: outlined(versionField)),
                ],
              ),
      ),
    );
  }
}
