import 'package:flutter/material.dart';

import '../features/dex/dex_models.dart';
import '../features/game/game_catalog.dart';
import '../features/game/game_edition.dart';
import '../l10n/app_zh.dart';
import '../theme/app_visual_style.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'dex_detail_picker_sheet.dart';

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
    final selectedForm =
        forms.where((form) => form.key == selectedFormKey).firstOrNull ??
        forms.firstOrNull;
    Widget field({
      required Key key,
      required String label,
      required Widget value,
      required VoidCallback? onTap,
    }) => Semantics(
      button: onTap != null,
      enabled: onTap != null,
      child: Material(
        key: key,
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: InputDecorator(
            isFocused: false,
            decoration: decoration(label, disabled: onTap == null),
            child: DefaultTextStyle(
              style: style,
              child: Row(
                children: [
                  Expanded(child: value),
                  if (onTap != null)
                    Icon(
                      Icons.expand_more_rounded,
                      size: 22,
                      color: labelColor,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final formField = field(
      key: const ValueKey('detail-form-picker'),
      label: AppZh.dexDetailFormField,
      value: Text(
        selectedForm == null
            ? AppZh.dexDetailBaseForm
            : selectedFormLabel(selectedForm, speciesNameZh),
        overflow: TextOverflow.ellipsis,
        style: formLocked ? style.copyWith(color: disabledTextColor) : null,
      ),
      onTap: formLocked
          ? null
          : () async {
              final result = await showDexFormPicker(
                context,
                forms: forms,
                selectedFormKey: selectedForm?.key,
              );
              if (context.mounted && result != null) onFormChanged(result);
            },
    );
    final versionField = field(
      key: const ValueKey('detail-version-picker'),
      label: AppZh.dexDetailVersionField,
      value: Row(
        children: [
          GameEditionIcon(edition: edition, size: 16),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              edition.selectedFlavor == null
                  ? edition.referenceGameName
                  : edition.selectedLabel,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      onTap: () async {
        final result = await showDexEditionPicker(context, selected: edition);
        if (context.mounted && result != null) onEditionChanged(result);
      },
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
