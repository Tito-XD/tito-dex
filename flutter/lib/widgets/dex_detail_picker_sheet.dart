import 'package:flutter/material.dart';

import '../features/dex/dex_game_scope.dart';
import '../features/dex/dex_models.dart';
import '../features/game/game_catalog.dart';
import '../features/game/game_edition.dart';
import '../l10n/app_zh.dart';
import '../l10n/localized_names.dart';
import '../navigation/tito_page_transition.dart';
import '../theme/app_visual_style.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/trainer_journal.dart';
import 'dex_sprite_image.dart';

/// Reference scopes include the explicitly named DLC encounter ranges as well
/// as the base releases. These choices stay local to the detail page.
List<String> dexDetailExactVersions(GameEdition edition) => edition.isGeneral
    ? const []
    : encounterVersionsByVersionGroup[edition.dataVersionGroupKey] ??
          edition.flavorVersions;

Future<PokemonFormDetail?> showDexFormPicker(
  BuildContext context, {
  required List<PokemonFormDetail> forms,
  required String? selectedFormKey,
}) => showTitoModalBottomSheet<PokemonFormDetail>(
  context: context,
  isScrollControlled: true,
  builder: (context) => _PickerFrame(
    title: AppZh.dexDetailFormField,
    children: [
      for (final form in forms)
        _ChoiceTile(
          key: ValueKey('detail-form-choice-${form.key}'),
          label: form.displayName,
          selected: form.key == selectedFormKey,
          leading: (form.localSpritePath ?? form.spriteUrl) == null
              ? null
              : DexSpriteImage(
                  source: form.localSpritePath ?? form.spriteUrl,
                  width: 32,
                  height: 32,
                ),
          onTap: () => Navigator.pop(context, form),
        ),
    ],
  ),
);

Future<GameEdition?> showDexEditionPicker(
  BuildContext context, {
  required GameEdition selected,
  bool exactOnly = false,
}) => showTitoModalBottomSheet<GameEdition>(
  context: context,
  isScrollControlled: true,
  builder: (context) =>
      _EditionPicker(selected: selected, exactOnly: exactOnly),
);

class _EditionPicker extends StatefulWidget {
  const _EditionPicker({required this.selected, required this.exactOnly});

  final GameEdition selected;
  final bool exactOnly;

  @override
  State<_EditionPicker> createState() => _EditionPickerState();
}

class _EditionPickerState extends State<_EditionPicker> {
  late GameEdition? _group = widget.exactOnly ? widget.selected : null;

  void _chooseGroup(GameEdition edition) {
    final versions = dexDetailExactVersions(edition);
    if (versions.length < 2) {
      Navigator.pop(context, edition.withFlavor(versions.firstOrNull));
    } else {
      setState(() => _group = edition);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final current = widget.selected;
    return _PickerFrame(
      key: ValueKey(group?.slug ?? 'games'),
      title: group?.referenceGameName ?? AppZh.dexDetailVersionField,
      description: group?.referenceExpansion == null
          ? null
          : AppZh.dexDetailExpansionScopeHint,
      onBack: group == null ? null : () => setState(() => _group = null),
      children: group == null
          ? [
              for (final game in [GameEdition.general, ...GameEdition.all])
                _ChoiceTile(
                  key: ValueKey('detail-game-choice-${game.slug}'),
                  label: game.referenceGameName,
                  subtitle: game.referenceExpansion,
                  leading: GameEditionIcon(
                    edition: current.slug == game.slug ? current : game,
                    size: 28,
                  ),
                  selected: current.slug == game.slug,
                  opensGroup: dexDetailExactVersions(game).length > 1,
                  onTap: () => _chooseGroup(game),
                ),
            ]
          : [
              _ChoiceTile(
                key: ValueKey('detail-version-choice-${group.slug}:merged'),
                label: AppZh.mergedGameEdition,
                subtitle: group.referenceExpansion,
                leading: GameEditionIcon(
                  edition: group.withFlavor(null),
                  size: 28,
                ),
                selected:
                    current.slug == group.slug &&
                    current.selectedFlavor == null,
                onTap: () => Navigator.pop(context, group.withFlavor(null)),
              ),
              for (final version in dexDetailExactVersions(group))
                _ChoiceTile(
                  key: ValueKey('detail-version-choice-$version'),
                  label: flavorVersionLabelZh(version),
                  leading: GameEditionIcon(
                    edition: group.withFlavor(version),
                    size: 28,
                  ),
                  selected:
                      current.slug == group.slug &&
                      current.selectedFlavor == version,
                  onTap: () =>
                      Navigator.pop(context, group.withFlavor(version)),
                ),
            ],
    );
  }
}

/// Natural height for short form lists, bounded scrolling for long catalogs.
/// The outer surface and entrance motion belong to the App's sheet theme.
class _PickerFrame extends StatelessWidget {
  const _PickerFrame({
    super.key,
    required this.title,
    required this.children,
    this.onBack,
    this.description,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onBack;
  final String? description;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .72,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              Expanded(
                child: Text(
                  title,
                  style: SecondaryTypography.onCard.h15.copyWith(
                    color: appVisualStyle.usesFlatUi
                        ? Theme.of(context).colorScheme.onSurface
                        : TitoColors.ink,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: AppZh.close,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: children.length + (description == null ? 0 : 1),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (description == null) return children[index];
              if (index > 0) return children[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  description!,
                  style: SecondaryTypography.onCard.small12.copyWith(
                    color: appVisualStyle.usesFlatUi
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : TitoColors.mutedInk,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.opensGroup = false,
  });

  final String label;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final bool opensGroup;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final flat = appVisualStyle.usesFlatUi;
    final plastic = appVisualStyle.usesSolidPlastic;
    final foreground = flat
        ? (selected ? scheme.onSecondaryContainer : scheme.onSurface)
        : TitoColors.ink;
    final fill = flat
        ? (selected ? scheme.secondaryContainer : scheme.surfaceContainerHigh)
        : plastic
        ? (selected
              ? TitoColors.softYellow.withValues(alpha: .85)
              : Colors.white.withValues(alpha: .8))
        : (selected ? TitoColors.softYellow : TrainerJournal.paper);
    final outline = flat
        ? (selected ? scheme.primary : scheme.outlineVariant)
        : plastic
        ? Colors.white.withValues(alpha: .85)
        : (selected ? TrainerJournal.edge : TrainerJournal.smallEdge);
    final radius = BorderRadius.circular(TitoRadii.md);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: outline,
            width: plastic
                ? TitoBorders.glass
                : appVisualStyle.usesTrainerJournal
                ? (selected
                      ? TitoBorders.journalCard
                      : TitoBorders.journalElement)
                : (selected ? TitoBorders.card : TitoBorders.element),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 10)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: SecondaryTypography.onCard.body14.copyWith(
                            color: foreground,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: SecondaryTypography.onCard.small12.copyWith(
                              color: flat
                                  ? scheme.onSurfaceVariant
                                  : TitoColors.mutedInk,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (selected || opensGroup) ...[
                    const SizedBox(width: 8),
                    Icon(
                      selected
                          ? Icons.check_rounded
                          : Icons.chevron_right_rounded,
                      size: 20,
                      color: foreground,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
