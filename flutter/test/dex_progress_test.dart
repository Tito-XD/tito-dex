import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/features/dex/dex_game_scope.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_progress.dart';
import 'package:titodex/models/journey.dart';

void main() {
  test('DexProgress merges save flags with party species', () {
    final journey = CurrentJourney(
      game: 'SoulSilver',
      trainerName: 'Test',
      location: '满金市',
      badges: 3,
      maxBadges: 8,
      playTime: '1:00:00',
      party: const [
        PartyMember(species: 'Quilava', speciesId: 156, level: 27),
      ],
      timeline: const [],
      companion: 'Togepi',
      saveDexCaughtIds: const [25],
      saveDexSeenIds: const [1, 25, 133],
    );

    final progress = DexProgress.fromJourney(journey);

    expect(progress.caughtIds, containsAll([25, 156, 175]));
    expect(progress.seenIds, containsAll([1, 25, 133, 156, 175]));
    expect(progress.statusFor(25), DexEncounterStatus.caught);
    expect(progress.statusFor(133), DexEncounterStatus.seen);
    expect(progress.statusFor(999), DexEncounterStatus.unknown);
    expect(progress.fromSave, isTrue);
  });

  test('DexProgress statsFor national scope uses full national dex browse cap', () {
    const progress = DexProgress(
      caughtIds: {1, 493, 1025},
      seenIds: {1, 2, 493, 500},
    );

    final stats = progress.statsFor(DexRegionalScope.national);

    expect(stats.total, titodexMaxNationalDexId);
    expect(stats.caught, 3);
    expect(stats.seenOnly, 2);
    expect(stats.unseen, titodexMaxNationalDexId - 5);
  });

  test('DexProgress statsFor johto scope counts regional ids', () {
    const progress = DexProgress(
      caughtIds: {152, 155, 251},
      seenIds: {152, 155, 200, 251},
    );

    final stats = progress.statsFor(DexRegionalScope.johto);

    expect(stats.total, 100);
    expect(stats.caught, 3);
    expect(stats.seenOnly, 1);
    expect(stats.unseen, 96);
    expect(stats.seen, 4);
  });

  test('DexProgress filter matches encounter status buckets', () {
    const progress = DexProgress(
      caughtIds: {1},
      seenIds: {1, 2},
    );

    expect(progress.matchesFilter(1, DexEncounterFilter.caught), isTrue);
    expect(progress.matchesFilter(2, DexEncounterFilter.seen), isTrue);
    expect(progress.matchesFilter(1, DexEncounterFilter.seen), isTrue);
    expect(progress.matchesFilter(3, DexEncounterFilter.unseen), isTrue);
  });

  test('DexProgress manualDexMarks uses journey manual id lists', () {
    final journey = CurrentJourney(
      game: 'Scarlet',
      trainerName: 'Test',
      location: '帕底亚',
      badges: 0,
      maxBadges: 8,
      playTime: '1:00:00',
      party: const [],
      timeline: const [],
      companion: 'Sprigatito',
      manualDexSeenIds: const [1, 4],
      manualDexCaughtIds: const [7],
    );

    final progress = DexProgress.fromJourney(journey, manualDexMarks: true);

    expect(progress.statusFor(1), DexEncounterStatus.seen);
    expect(progress.statusFor(4), DexEncounterStatus.seen);
    expect(progress.statusFor(7), DexEncounterStatus.caught);
    expect(progress.statusFor(25), DexEncounterStatus.unknown);
    expect(progress.fromSave, isFalse);
  });
}
