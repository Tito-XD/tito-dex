import 'package:flutter/material.dart';

import '../features/dex/dex_browse_scope.dart';
import '../features/dex/dex_filter.dart';
import '../features/dex/dex_game_scope.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_progress.dart';
import '../features/dex/dex_repository.dart';
import '../features/dex/dex_search_terms.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'dex_shape_icon.dart';
import 'type_badge.dart';
import 'tito_pokeball_loading.dart';

class DexSearchFilterSelection {
  const DexSearchFilterSelection(
    this.filter,
    this.scope,
    this.encounter, {
    this.journeyOnly = false,
  });
  final bool journeyOnly;
  final DexFilter filter;
  final DexBrowseScope scope;
  final DexEncounterFilter encounter;
}

Future<DexSearchFilterSelection?> showDexSearchFilterSheet(
  BuildContext context, {
  required DexFilter filter,
  required DexBrowseScope scope,
  required DexEncounterFilter encounter,
  bool journeyOnly = false,
}) => showModalBottomSheet<DexSearchFilterSelection>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => DexSearchFilterSheet(
    filter: filter,
    scope: scope,
    encounter: encounter,
    journeyOnly: journeyOnly,
  ),
);

/// Search and every list constraint share one dismissible, keyboard-aware sheet.
/// All changes remain a draft until the user applies them.
class DexSearchFilterSheet extends StatefulWidget {
  const DexSearchFilterSheet({
    super.key,
    required this.filter,
    required this.scope,
    required this.encounter,
    this.repository,
    this.journeyOnly = false,
  });

  final DexFilter filter;
  final DexBrowseScope scope;
  final DexEncounterFilter encounter;
  final DexRepository? repository;
  final bool journeyOnly;

  @override
  State<DexSearchFilterSheet> createState() => _DexSearchFilterSheetState();
}

class _DexSearchFilterSheetState extends State<DexSearchFilterSheet> {
  late final _query = TextEditingController(text: widget.filter.query);
  late DexBrowseScope _scope = DexBrowseScope.region(
    widget.scope.region ?? DexRegionalPokedex.national,
  );
  late bool _journeyOnly = widget.journeyOnly;
  late DexEncounterFilter _encounter = widget.encounter;
  late Set<String> _types = {...widget.filter.typeSlugs};
  late Set<String> _colors = {...widget.filter.colorSlugs};
  late String? _shape = widget.filter.shapeSlug;
  late String? _size = widget.filter.sizeSlug;
  late String? _tag = widget.filter.tag;
  late int? _generation = widget.filter.generation ?? widget.scope.generation;
  late DexFormDisplay _forms = widget.filter.formDisplay;
  late int? _ability = widget.filter.abilityId;
  late int? _move = widget.filter.learnsMoveId;
  late String? _egg = widget.filter.eggGroupSlug;
  List<CachedAbility> _abilities = const [];
  List<CachedMove> _moves = const [];
  bool _referencesLoading = false;
  bool _referencesLoaded = false;
  bool _referenceError = false;
  bool _abilityValid = true;
  bool _moveValid = true;
  int _resetKey = 0;

  static const _typesAll = [
    'normal',
    'fire',
    'water',
    'electric',
    'grass',
    'ice',
    'fighting',
    'poison',
    'ground',
    'flying',
    'psychic',
    'bug',
    'rock',
    'ghost',
    'dragon',
    'dark',
    'steel',
    'fairy',
  ];
  static const _swatches = <String, Color>{
    'black': Color(0xFF3A3A3A),
    'blue': Color(0xFF4E7FD1),
    'brown': Color(0xFF9C6B4A),
    'gray': Color(0xFF9AA3AC),
    'green': Color(0xFF63B75E),
    'pink': Color(0xFFF08FB4),
    'purple': Color(0xFF9668C4),
    'red': Color(0xFFE0524A),
    'white': Color(0xFFF4F1EA),
    'yellow': Color(0xFFF2C443),
  };
  static const _eggs = eggGroupLabelsZh;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    if (_referencesLoaded || _referencesLoading) return;
    setState(() {
      _referencesLoading = true;
      _referenceError = false;
    });
    try {
      final repo = widget.repository ?? dexRepository;
      final (abilities, moves) = await (
        repo.getAllAbilities(),
        repo.getAllMoves(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _abilities = abilities;
        _moves = moves;
        _referencesLoaded = true;
        _referencesLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _referenceError = true;
          _referencesLoading = false;
        });
      }
    }
  }

  void _reset() => setState(() {
    _query.clear();
    _journeyOnly = false;
    _scope = const DexBrowseScope.region(DexRegionalPokedex.national);
    _encounter = DexEncounterFilter.all;
    _types = {};
    _colors = {};
    _shape = null;
    _size = null;
    _tag = null;
    _generation = null;
    _forms = DexFormDisplay.base;
    _ability = null;
    _move = null;
    _egg = null;
    _resetKey++;
    _abilityValid = true;
    _moveValid = true;
  });

  void _apply() {
    if (!_abilityValid || !_moveValid) return;
    final labels = <String>[
      if (_ability != null)
        AppZh.dexSearchAbilityLabel(
          _abilities.where((a) => a.id == _ability).firstOrNull?.nameZh ??
              '#$_ability',
        ),
      if (_move != null)
        AppZh.dexSearchMoveLabel(
          _moves.where((m) => m.id == _move).firstOrNull?.nameZh ?? '#$_move',
        ),
      if (_egg != null) AppZh.dexFilterByEggGroup(_eggs[_egg] ?? _egg!),
    ];
    Navigator.pop(
      context,
      DexSearchFilterSelection(
        DexFilter(
          query: _query.text.trim(),
          typeSlugs: _types,
          formDisplay: _forms,
          shapeSlug: _shape,
          colorSlugs: _colors,
          sizeSlug: _size,
          generation: _generation,
          tag: _tag,
          abilityId: _ability,
          learnsMoveId: _move,
          eggGroupSlug: _egg,
          labelZh: labels.isEmpty ? null : labels.join(' · '),
        ),
        _scope,
        _encounter,
        journeyOnly: _journeyOnly,
      ),
    );
  }

  Widget _select<T>(
    String label,
    T value,
    Map<T, String> values,
    ValueChanged<T> change,
  ) => DropdownButtonFormField<T>(
    key: ValueKey('$label-$value-$_resetKey'),
    initialValue: value,
    isExpanded: true,
    menuMaxHeight: 300,
    decoration: InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
    ),
    items: [
      for (final entry in values.entries)
        DropdownMenuItem(
          value: entry.key,
          child: Text(entry.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (v) {
      if (v != null) setState(() => change(v));
    },
  );

  Widget _chips(
    String label,
    List<String> values,
    Set<String> selected,
    String Function(String) name,
    void Function(String) change, {
    Widget Function(String)? avatar,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: SecondaryTypography.onCard.h15),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 3,
        children: [
          for (final value in values)
            // Colour, stroke and radius come from the theme's chipTheme.
            FilterChip(
              avatar: avatar?.call(value),
              label: Text(name(value)),
              selected: selected.contains(value),
              onSelected: (_) => setState(() => change(value)),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    ],
  );

  /// Type glyphs ship as white-on-transparent PNGs, which vanish on the cream
  /// unselected chip. Sit each on a small disc of its own type colour so the
  /// icon is legible in every chip state and every theme.
  Widget _typeAvatar(String typeEn) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: typeTileColor(typeEn),
      shape: BoxShape.circle,
      border: Border.all(
        color: TitoColors.ink.withValues(alpha: 0.25),
        width: TitoBorders.glass,
      ),
    ),
    alignment: Alignment.center,
    child: TypeIconImage(typeEn: typeEn, size: 14, fallbackColor: Colors.white),
  );

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final size = MediaQuery.sizeOf(context);
    final height = (size.height * .88 - keyboard).clamp(0.0, size.height);
    final compact = height < 300;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact)
              const SizedBox(height: 8)
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppZh.dexSearchSheetTitle,
                        style: SecondaryTypography.onCard.h15,
                      ),
                    ),
                    IconButton(
                      tooltip: AppZh.close,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _query,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _apply(),
                decoration: InputDecoration(
                  isDense: compact,
                  hintText: AppZh.dexSearchSheetHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: AppZh.dexSearchClearQuery,
                    onPressed: _query.clear,
                    icon: const Icon(Icons.clear_rounded),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _select(AppZh.dexSearchScopeField, _journeyOnly, {
                    false: AppZh.dexSearchAllPokemon,
                    true: AppZh.dexTabJourney,
                  }, (v) => _journeyOnly = v),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _select(
                          AppZh.searchHubRegionalDex,
                          _scope.region!,
                          {
                            for (final region in DexRegionalPokedex.values)
                              region: AppZh.dexRegionalDexTitle(region.labelZh),
                          },
                          (v) => _scope = DexBrowseScope.region(v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _select(AppZh.dexSearchGenerationField, _generation ?? 0, {
                          0: AppZh.dexSearchAllGenerations,
                          for (
                            var generation = 1;
                            generation <= 9;
                            generation++
                          )
                            generation: generationLabelZh(generation),
                        }, (v) => _generation = v == 0 ? null : v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _select(AppZh.dexSearchTagField, _tag ?? '', {
                          '': AppZh.dexSearchAllPokemon,
                          'legendary': AppZh.dexSearchTagLegendary,
                          'mythical': AppZh.dexSearchTagMythical,
                          'pseudo-legendary': AppZh.dexSearchTagPseudoLegendary,
                          'baby': AppZh.dexSearchTagBaby,
                        }, (v) => _tag = v.isEmpty ? null : v),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _select(AppZh.dexSearchFormField, _forms, {
                          DexFormDisplay.base: AppZh.dexDetailBaseForm,
                          DexFormDisplay.all: AppZh.dexFormDisplayAll,
                          DexFormDisplay.alternate: AppZh.dexFormDisplayAlternate,
                        }, (v) => _forms = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _chips(AppZh.dexSearchTypesField, _typesAll, _types, typeNameZh, (v) {
                    if (!_types.remove(v)) _types.add(v);
                  }, avatar: _typeAvatar),
                  const Divider(),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(AppZh.dexSearchSpeciesAxesTitle),
                    initiallyExpanded:
                        _shape != null || _colors.isNotEmpty || _size != null,
                    children: [
                      _chips(
                        AppZh.dexSearchShapeField,
                        kDexShapeSlugs,
                        {if (_shape != null) _shape!},
                        (v) => dexShapeLabelZh(v) ?? v,
                        (v) => _shape = _shape == v ? null : v,
                        avatar: (v) => DexShapeIcon(slug: v, size: 22),
                      ),
                      const SizedBox(height: 12),
                      _chips(
                        AppZh.dexSearchColorField,
                        kDexColorSlugs,
                        _colors,
                        (v) => dexColorLabelZh(v) ?? v,
                        (v) {
                          if (!_colors.remove(v)) _colors.add(v);
                        },
                        avatar: (v) => Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _swatches[v],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: TitoColors.ink.withValues(alpha: 0.25),
                              width: TitoBorders.glass,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _chips(
                        AppZh.dexSpeciesFilterSize,
                        DexSizeBucket.values.map((b) => b.slug).toList(),
                        {if (_size != null) _size!},
                        (v) => DexSizeBucket.fromSlug(v)!.label,
                        (v) => _size = _size == v ? null : v,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(AppZh.dexSearchReferenceTitle),
                    onExpansionChanged: (open) {
                      if (open) _loadReferences();
                    },
                    children: [
                      if (_referencesLoading) const TitoPokeballLoading(),
                      if (_referenceError)
                        TextButton(
                          onPressed: _loadReferences,
                          child: Text(AppZh.dexSearchReferenceRetry),
                        ),
                      if (_referencesLoaded) ...[
                        _ReferenceSearch(
                          key: ValueKey('ability-$_resetKey'),
                          label: AppZh.dexAbilities,
                          selected: _ability,
                          values: {for (final a in _abilities) a.id: a.nameZh},
                          onChanged: (id) => _ability = id,
                          onValidityChanged: (valid) =>
                              setState(() => _abilityValid = valid),
                        ),
                        const SizedBox(height: 12),
                        _ReferenceSearch(
                          key: ValueKey('move-$_resetKey'),
                          label: AppZh.dexTabMoves,
                          selected: _move,
                          values: {for (final m in _moves) m.id: m.nameZh},
                          onChanged: (id) => _move = id,
                          onValidityChanged: (valid) =>
                              setState(() => _moveValid = valid),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _select(AppZh.dexSearchEggGroupField, _egg ?? '', {
                        '': AppZh.dexSearchAllEggGroups,
                        ..._eggs,
                      }, (v) => _egg = v.isEmpty ? null : v),
                      const SizedBox(height: 12),
                      Text(
                        AppZh.dexSearchReferenceNote,
                        style: SecondaryTypography.onCard.small12.copyWith(
                          color: TitoColors.mutedInk,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _select(AppZh.dexSearchEncounterField, _encounter, {
                    DexEncounterFilter.all: AppZh.dexFilterAll,
                    DexEncounterFilter.caught: AppZh.dexFilterCaught,
                    DexEncounterFilter.seen: AppZh.dexEncounterSeen,
                    DexEncounterFilter.unseen: AppZh.dexEncounterUnseen,
                    DexEncounterFilter.evolutionOrTrade:
                        AppZh.dexEncounterEvolutionOrTrade,
                  }, (v) => _encounter = v),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  compact ? 2 : 8,
                  16,
                  compact ? 2 : 12,
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _reset,
                      child: Text(AppZh.dexSearchReset),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _abilityValid && _moveValid ? _apply : null,
                        child: Text(AppZh.dexSpeciesFilterApply),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceSearch extends StatelessWidget {
  const _ReferenceSearch({
    super.key,
    required this.label,
    required this.selected,
    required this.values,
    required this.onChanged,
    required this.onValidityChanged,
  });
  final String label;
  final int? selected;
  final Map<int, String> values;
  final ValueChanged<int?> onChanged;
  final ValueChanged<bool> onValidityChanged;

  @override
  Widget build(BuildContext context) => Autocomplete<int>(
    initialValue: TextEditingValue(text: values[selected] ?? ''),
    displayStringForOption: (id) => values[id] ?? '#$id',
    optionsBuilder: (text) {
      final q = text.text.trim();
      if (q.isEmpty) return const Iterable<int>.empty();
      return values.keys
          .where((id) => values[id]!.contains(q) || '$id' == q)
          .take(30);
    },
    onSelected: (id) {
      onChanged(id);
      onValidityChanged(true);
    },
    fieldViewBuilder: (context, controller, focus, submit) => TextField(
      controller: controller,
      focusNode: focus,
      onChanged: (text) {
        final exact = values.entries
            .where((e) => e.value == text.trim() || '${e.key}' == text.trim())
            .firstOrNull;
        onChanged(exact?.key);
        onValidityChanged(text.trim().isEmpty || exact != null);
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: AppZh.dexSearchReferenceHint,
        helperText: AppZh.dexSearchReferenceHelper,
        suffixIcon: IconButton(
          tooltip: AppZh.dexSearchClearField(label),
          onPressed: () {
            controller.clear();
            onChanged(null);
            onValidityChanged(true);
          },
          icon: const Icon(Icons.clear_rounded),
        ),
      ),
    ),
  );
}
