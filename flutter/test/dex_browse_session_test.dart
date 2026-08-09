import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/features/dex/dex_browse_scope.dart';
import 'package:titodex/features/dex/dex_browse_session.dart';
import 'package:titodex/features/dex/dex_filter.dart';
import 'package:titodex/features/dex/dex_game_scope.dart';
import 'package:titodex/features/dex/dex_progress.dart';

void main() {
  tearDown(DexBrowseSessionStore.clear);

  test('keeps list depth and scroll only for the same browse context', () {
    const scope = DexBrowseScope.region(DexRegionalPokedex.national);
    const filter = DexFilter(shapeSlug: 'quadruped', colorSlugs: {'red'});
    final session = DexBrowseSession(
      scrollOffset: 1280,
      loadedThrough: 126,
      filterVisibleCount: 72,
      modeName: 'national',
      browseScope: scope,
      encounterFilter: DexEncounterFilter.unseen,
      filterFingerprint: dexFilterFingerprint(filter),
    );

    DexBrowseSessionStore.save(session);
    expect(DexBrowseSessionStore.current, same(session));
    expect(session.matches(scope, filter), isTrue);
    expect(
      session.matches(const DexBrowseScope.generation(2), filter),
      isFalse,
    );
    expect(
      session.matches(scope, const DexFilter(shapeSlug: 'quadruped')),
      isFalse,
    );
  });

  test('filter fingerprint is stable across set insertion order', () {
    const left = DexFilter(colorSlugs: {'red', 'brown'});
    const right = DexFilter(colorSlugs: {'brown', 'red'});
    expect(dexFilterFingerprint(left), dexFilterFingerprint(right));
  });

  test('detached list save keeps the last attached scroll offset', () {
    final memory = DexBrowseScrollMemory();

    expect(memory.offsetForSave(null), 0);
    expect(memory.offsetForSave(1280), 1280);
    expect(memory.offsetForSave(null), 1280);

    // A real user scroll to the top is still recorded while attached.
    expect(memory.offsetForSave(0), 0);
    expect(memory.offsetForSave(null), 0);
  });

  test('restore target survives until an attached list can consume it', () {
    final memory = DexBrowseScrollMemory();
    memory.rememberRestoreTarget(2048);

    expect(memory.offsetForSave(null), 2048);
  });
}
