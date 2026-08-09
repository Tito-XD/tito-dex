import 'dex_browse_scope.dart';
import 'dex_filter.dart';
import 'dex_progress.dart';

/// Short-lived navigation state for returning from a species detail page.
///
/// This deliberately stays in memory: it protects the current browsing
/// session without turning a pixel offset into durable user configuration.
class DexBrowseSession {
  const DexBrowseSession({
    required this.scrollOffset,
    required this.loadedThrough,
    required this.filterVisibleCount,
    required this.modeName,
    required this.browseScope,
    required this.encounterFilter,
    required this.filterFingerprint,
  });

  final double scrollOffset;
  final int loadedThrough;
  final int filterVisibleCount;
  final String modeName;
  final DexBrowseScope browseScope;
  final DexEncounterFilter encounterFilter;
  final String filterFingerprint;

  bool matches(DexBrowseScope scope, DexFilter filter) =>
      browseScope == scope && filterFingerprint == dexFilterFingerprint(filter);
}

class DexBrowseSessionStore {
  DexBrowseSessionStore._();

  static DexBrowseSession? current;

  static void save(DexBrowseSession session) => current = session;

  static void clear() => current = null;
}

/// Remembers the last offset observed while the list was still attached.
///
/// Route teardown can detach a [ScrollController] before `deactivate` or
/// `dispose` saves the browse session. Passing `null` in that state must keep
/// the last real position instead of replacing it with the list default (0).
class DexBrowseScrollMemory {
  double _lastKnownOffset = 0;

  double offsetForSave(double? attachedOffset) {
    if (attachedOffset != null &&
        attachedOffset.isFinite &&
        attachedOffset >= 0) {
      _lastKnownOffset = attachedOffset;
    }
    return _lastKnownOffset;
  }

  void rememberRestoreTarget(double offset) {
    if (offset.isFinite && offset >= 0) {
      _lastKnownOffset = offset;
    }
  }
}

String dexFilterFingerprint(DexFilter filter) {
  final colors = filter.colorSlugs.toList()..sort();
  return [
    filter.eggGroupSlug,
    filter.abilityId,
    filter.learnsMoveId,
    filter.shapeSlug,
    colors.join(','),
    filter.sizeSlug,
    filter.generation,
    filter.tag,
  ].join('|');
}
