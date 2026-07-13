import 'package:flutter/foundation.dart';

/// Active drill-down filter for the dex list (egg group, ability, move, …).
class DexFilter {
  const DexFilter({
    this.eggGroupSlug,
    this.abilityId,
    this.learnsMoveId,
    this.natureSlug,
    this.itemId,
    this.labelZh,
  });

  final String? eggGroupSlug;
  final int? abilityId;
  final int? learnsMoveId;
  final String? natureSlug;
  final int? itemId;
  final String? labelZh;

  bool get isActive =>
      eggGroupSlug != null ||
      abilityId != null ||
      learnsMoveId != null ||
      natureSlug != null ||
      itemId != null;

  static const empty = DexFilter();

  DexFilter copyWith({
    String? eggGroupSlug,
    int? abilityId,
    int? learnsMoveId,
    String? natureSlug,
    int? itemId,
    String? labelZh,
  }) =>
      DexFilter(
        eggGroupSlug: eggGroupSlug ?? this.eggGroupSlug,
        abilityId: abilityId ?? this.abilityId,
        learnsMoveId: learnsMoveId ?? this.learnsMoveId,
        natureSlug: natureSlug ?? this.natureSlug,
        itemId: itemId ?? this.itemId,
        labelZh: labelZh ?? this.labelZh,
      );
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
