import 'package:flutter/foundation.dart';

import '../../l10n/app_zh.dart';
import 'dex_models.dart';
import 'dex_search_terms.dart';

/// Active drill-down filter for the dex list (egg group, ability, move, …).
enum DexFormDisplay { base, all, alternate }

class DexFilter {
  const DexFilter({
    this.query = '',
    this.speciesIds,
    this.speciesLabelZh,
    this.typeSlugs = const {},
    this.formDisplay = DexFormDisplay.base,
    this.eggGroupSlug,
    this.abilityId,
    this.learnsMoveId,
    this.shapeSlug,
    this.colorSlugs = const {},
    this.sizeSlug,
    this.generation,
    this.tag,
    this.labelZh,
  });

  final String query;

  /// An explicit drill-down cohort, such as the remaining Journey species.
  /// Null means unrestricted; an empty set intentionally matches nothing.
  final Set<int>? speciesIds;

  /// Keep the cohort label separate when other reference filters are edited.
  final String? speciesLabelZh;
  final Set<String> typeSlugs;
  final DexFormDisplay formDisplay;
  final String? eggGroupSlug;
  final int? abilityId;
  final int? learnsMoveId;

  /// Species axes that combine with each other: body style × colour × size ×
  /// generation × tag. These intersect with the reference constraints to
  /// narrow the directory down to matching species.
  final String? shapeSlug;

  /// Colours are a **set**: the in-game palette has no orange, so anyone
  /// hunting an orange Pokémon needs to select 棕 and 红 together or get an
  /// empty list. Empty means "any colour".
  final Set<String> colorSlugs;

  /// Relative-size bucket slug — see `DexSizeBucket`.
  final String? sizeSlug;

  final int? generation;
  final String? tag;

  final String? labelZh;

  bool get isActive =>
      query.trim().isNotEmpty ||
      typeSlugs.isNotEmpty ||
      formDisplay != DexFormDisplay.base ||
      eggGroupSlug != null ||
      abilityId != null ||
      learnsMoveId != null ||
      speciesIds != null ||
      hasSpeciesAxis;

  /// True when at least one stackable species axis is set.
  bool get hasSpeciesAxis =>
      shapeSlug != null ||
      colorSlugs.isNotEmpty ||
      sizeSlug != null ||
      generation != null ||
      tag != null;

  static const empty = DexFilter();

  DexFilter copyWith({
    String? query,
    Set<int>? speciesIds,
    String? speciesLabelZh,
    Set<String>? typeSlugs,
    DexFormDisplay? formDisplay,
    String? eggGroupSlug,
    int? abilityId,
    int? learnsMoveId,
    String? shapeSlug,
    Set<String>? colorSlugs,
    String? sizeSlug,
    int? generation,
    String? tag,
    String? labelZh,
  }) => DexFilter(
    query: query ?? this.query,
    speciesIds: speciesIds ?? this.speciesIds,
    speciesLabelZh: speciesLabelZh ?? this.speciesLabelZh,
    typeSlugs: typeSlugs ?? this.typeSlugs,
    formDisplay: formDisplay ?? this.formDisplay,
    eggGroupSlug: eggGroupSlug ?? this.eggGroupSlug,
    abilityId: abilityId ?? this.abilityId,
    learnsMoveId: learnsMoveId ?? this.learnsMoveId,
    shapeSlug: shapeSlug ?? this.shapeSlug,
    colorSlugs: colorSlugs ?? this.colorSlugs,
    sizeSlug: sizeSlug ?? this.sizeSlug,
    generation: generation ?? this.generation,
    tag: tag ?? this.tag,
    labelZh: labelZh ?? this.labelZh,
  );

  /// Drop a single species axis — `copyWith` cannot clear a field to null.
  DexFilter without({
    bool shape = false,
    bool color = false,
    bool size = false,
    bool generation = false,
    bool tag = false,
  }) => DexFilter(
    query: query,
    speciesIds: speciesIds,
    speciesLabelZh: speciesLabelZh,
    typeSlugs: typeSlugs,
    formDisplay: formDisplay,
    eggGroupSlug: eggGroupSlug,
    abilityId: abilityId,
    learnsMoveId: learnsMoveId,
    shapeSlug: shape ? null : shapeSlug,
    colorSlugs: color ? const {} : colorSlugs,
    sizeSlug: size ? null : sizeSlug,
    generation: generation ? null : this.generation,
    tag: tag ? null : this.tag,
    labelZh: labelZh,
  );

  /// Replace the stackable species axes wholesale.
  ///
  /// The picker needs to *clear* an axis, which `copyWith` cannot express, so
  /// every value here is applied literally — null and empty included.
  DexFilter withSpeciesAxes({
    String? shapeSlug,
    Set<String> colorSlugs = const {},
    String? sizeSlug,
    int? generation,
    String? tag,
  }) => DexFilter(
    query: query,
    speciesIds: speciesIds,
    speciesLabelZh: speciesLabelZh,
    typeSlugs: typeSlugs,
    formDisplay: formDisplay,
    eggGroupSlug: eggGroupSlug,
    abilityId: abilityId,
    learnsMoveId: learnsMoveId,
    shapeSlug: shapeSlug,
    colorSlugs: colorSlugs,
    sizeSlug: sizeSlug,
    generation: generation,
    tag: tag,
    labelZh: labelZh,
  );

  /// Human-readable summary of the active species axes, e.g. 「四足 · 棕/红 · 小」.
  /// Returns null when no species axis is set.
  String? get speciesAxesLabelZh {
    if (!hasSpeciesAxis) {
      return null;
    }
    final parts = <String>[];
    if (tag != null) {
      parts.add(dexTagLabelZh(tag!) ?? tag!);
    }
    if (generation != null) {
      parts.add(AppZh.generationFilterLabel(generation!));
    }
    if (shapeSlug != null) {
      parts.add(dexShapeLabelZh(shapeSlug!) ?? shapeSlug!);
    }
    if (colorSlugs.isNotEmpty) {
      // Keep the palette's canonical order so the label is stable.
      final ordered = kDexColorSlugs.where(colorSlugs.contains);
      parts.add(ordered.map((s) => dexColorLabelZh(s) ?? s).join('/'));
    }
    if (sizeSlug != null) {
      parts.add(DexSizeBucket.fromSlug(sizeSlug!)?.label ?? sizeSlug!);
    }
    return parts.join(' · ');
  }

  /// Does this species pass every stackable axis?
  bool matchesSpeciesAxes(PokemonSummary summary) {
    if (speciesIds != null && !speciesIds!.contains(summary.id)) return false;
    if (query.trim().isNotEmpty &&
        !dexQueryMatches(parseDexSearchQuery(query), summary)) {
      return false;
    }
    if (!typeSlugs.every((type) => summary.types.contains(type))) return false;
    // Accepts the pre-Gen VI body style as well, so reclassified species
    // stay findable under the shape a HGSS player remembers.
    if (shapeSlug != null && !dexSummaryHasShape(summary, shapeSlug!)) {
      return false;
    }
    // Any selected colour counts — the set is an OR, not an AND.
    if (colorSlugs.isNotEmpty && !colorSlugs.contains(summary.colorSlug)) {
      return false;
    }
    if (sizeSlug != null &&
        DexSizeBucket.forHeightDm(summary.heightDm)?.slug != sizeSlug) {
      return false;
    }
    if (generation != null && summary.generation != generation) {
      return false;
    }
    if (tag != null && !summary.tags.contains(tag)) {
      return false;
    }
    return true;
  }
}

/// Shared filter state — reference detail sheets set this before navigating to `/dex`.
class DexFilterController extends ChangeNotifier {
  DexFilter _active = DexFilter.empty;

  DexFilter get currentFilter => _active;

  DexFilter? get active => _active.isActive ? _active : null;

  bool get hasActiveFilter => _active.isActive;

  void setFilter(DexFilter filter) {
    if (!filter.isActive) {
      clearFilter();
      return;
    }
    _active = filter;
    notifyListeners();
  }

  void clearFilter() {
    if (!_active.isActive) {
      return;
    }
    _active = DexFilter.empty;
    notifyListeners();
  }

  /// Alias kept for existing call sites.
  void clear() => clearFilter();
}

final dexFilterController = DexFilterController();
