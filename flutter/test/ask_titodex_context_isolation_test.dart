import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/game/game_edition.dart';
import 'package:titodex/features/journey/progression_hints.dart';
import 'package:titodex/models/journey.dart';

void main() {
  group('Ask TitoDex save context isolation', () {
    test('keeps verified HGSS context for the matching exact edition', () {
      final context = AskTitoDexContext.fromJourney(
        _hgssJourney,
        GameEdition.hgss.withFlavor('soulsilver'),
        locationId: 'johto-route-36-area',
      );

      expect(context.game, 'soulsilver');
      expect(context.gameReliability, 'save_verified');
      expect(context.locationLabel, '36号道路');
      expect(context.locationId, 'johto-route-36-area');
      expect(context.badgeIds, _hgssBadgeIds);
      expect(context.badgeCount, isNull);
      expect(context.badgesReliability, 'save_verified');
      expect(context.hasVerifiedLocationContext, isTrue);
      expect(context.hasVerifiedBadgeContext, isTrue);
    });

    test('switching an HGSS save to Violet removes every save fact', () {
      final context = AskTitoDexContext.fromJourney(
        _hgssJourney,
        gameEditionFromSlug('sv')!.withFlavor('violet'),
        locationId: 'johto-route-36-area',
      );

      _expectNoSaveContext(context, game: 'violet', generation: 9);
    });

    test('switching an HGSS save to BDSP removes every save fact', () {
      final context = AskTitoDexContext.fromJourney(
        _hgssJourney,
        gameEditionFromSlug('bdsp')!.withFlavor('brilliant-diamond'),
        locationId: 'johto-route-36-area',
      );

      _expectNoSaveContext(context, game: 'brilliant-diamond', generation: 8);
    });

    test(
      'manual edition without a linked save never inherits journey facts',
      () {
        final context = AskTitoDexContext.fromJourney(
          _hgssJourneyWithoutSave,
          gameEditionFromSlug('sv')!.withFlavor('violet'),
          locationId: 'johto-route-36-area',
        );

        _expectNoSaveContext(context, game: 'violet', generation: 9);
      },
    );

    test('opposite side of a paired release is not compatible', () {
      final context = AskTitoDexContext.fromJourney(
        _hgssJourney,
        GameEdition.hgss.withFlavor('heartgold'),
        locationId: 'johto-route-36-area',
      );

      _expectNoSaveContext(context, game: 'heartgold', generation: 4);
    });

    test('merged HGSS selection accepts the exact SoulSilver save', () {
      final context = AskTitoDexContext.fromJourney(
        _hgssJourney,
        GameEdition.hgss,
        locationId: 'johto-route-36-area',
      );

      expect(context.game, 'soulsilver');
      expect(context.gameReliability, 'save_verified');
      expect(context.badgesReliability, 'save_verified');
      expect(context.badgeIds, _hgssBadgeIds);
      expect(context.locationLabel, '36号道路');
    });

    test(
      'merged save may supply a supported badge count but not a side or location',
      () {
        final journey = _hgssJourney.copyWith(
          game: 'DiamondPearl',
          location: '203号道路',
          badges: 2,
          verifiedBadgeIds: const [],
        );
        final context = AskTitoDexContext.fromJourney(
          journey,
          gameEditionFromSlug('dp')!.withFlavor('pearl'),
          locationId: 'sinnoh-route-203-area',
        );

        expect(context.game, 'pearl');
        expect(context.gameReliability, 'user_selected');
        expect(context.locationReliability, 'unknown');
        expect(context.locationLabel, isNull);
        expect(context.locationId, isNull);
        expect(context.badgesReliability, 'count_only');
        expect(context.badgeIds, isEmpty);
        expect(context.badgeCount, 2);
        expect(context.hasVerifiedBadgeContext, isTrue);
      },
    );

    test('save families without decoded badges do not expose a zero count', () {
      final journey = _hgssJourney.copyWith(
        game: 'Black2',
        location: '未知地点',
        badges: 0,
        verifiedBadgeIds: const [],
      );
      final context = AskTitoDexContext.fromJourney(
        journey,
        gameEditionFromSlug('bw2')!.withFlavor('black-2'),
      );

      expect(context.game, 'black-2');
      expect(context.gameReliability, 'save_verified');
      expect(context.locationReliability, 'unknown');
      expect(context.badgesReliability, 'unknown');
      expect(context.badgeCount, isNull);
      expect(context.includeLocation, isFalse);
      expect(context.includeBadges, isFalse);
      expect(context.hasVerifiedBadgeContext, isFalse);
    });

    test('legacy extension payload applies the same isolation boundary', () {
      final context = AskTitoDexContext.fromJourney(
        _hgssJourney,
        gameEditionFromSlug('sv')!.withFlavor('violet'),
        locationId: 'johto-route-36-area',
      );
      final extension = context.toExtensionJson(_hgssJourney);

      expect(extension['location'], {
        'id': null,
        'label': null,
        'reliability': 'unknown',
      });
      expect(extension['badges'], {
        'ids': const <String>[],
        'count': null,
        'reliability': 'unknown',
      });
      expect(extension['milestones'], {
        'ids': const <String>[],
        'reliability': 'unsupported',
      });
    });
  });

  group('Assistant edition identity', () {
    test('provides compact canonical labels for exact current versions', () {
      expect(
        assistantEditionDisplayLabel(GameEdition.hgss.withFlavor('soulsilver')),
        '魂银 · HGSS',
      );
      expect(
        assistantEditionDisplayLabel(
          gameEditionFromSlug('sv')!.withFlavor('violet'),
        ),
        '紫 · SV',
      );
      expect(
        assistantEditionDisplayLabel(
          gameEditionFromSlug('bdsp')!.withFlavor('brilliant-diamond'),
        ),
        '晶灿钻石 · BDSP',
      );
    });

    test('never guesses one side for a merged paired edition', () {
      expect(GameEdition.hgss.assistantGameKey, isNull);
      expect(gameEditionFromSlug('sv')!.assistantGameKey, isNull);
      expect(gameEditionFromSlug('bdsp')!.assistantGameKey, isNull);
      expect(
        gameEditionFromSlug('sv')!.withFlavor('violet').assistantGameKey,
        'violet',
      );
      expect(gameEditionFromSlug('pt')!.assistantGameKey, 'platinum');
    });

    test('compatibility respects exact and merged paired selections', () {
      final soulSilver = GameEdition.hgss.withFlavor('soulsilver');
      expect(
        isSaveEditionCompatible(selected: GameEdition.hgss, save: soulSilver),
        isTrue,
      );
      expect(
        isSaveEditionCompatible(
          selected: GameEdition.hgss.withFlavor('heartgold'),
          save: soulSilver,
        ),
        isFalse,
      );
      expect(
        isSaveEditionCompatible(
          selected: gameEditionFromSlug('sv')!.withFlavor('violet'),
          save: soulSilver,
        ),
        isFalse,
      );
    });
  });
}

void _expectNoSaveContext(
  AskTitoDexContext context, {
  required String game,
  required int generation,
}) {
  expect(context.game, game);
  expect(context.generation, generation);
  expect(context.gameReliability, 'user_selected');
  expect(context.locationLabel, isNull);
  expect(context.locationId, isNull);
  expect(context.locationReliability, 'unknown');
  expect(context.badgeIds, isEmpty);
  expect(context.badgeCount, isNull);
  expect(context.badgesReliability, 'unknown');
  expect(context.milestoneIds, isEmpty);
  expect(context.milestonesReliability, 'unsupported');
  expect(context.parserRevision, 0);
  expect(context.includeLocation, isFalse);
  expect(context.includeBadges, isFalse);
  expect(context.hasVerifiedLocationContext, isFalse);
  expect(context.hasVerifiedBadgeContext, isFalse);

  final request = context.toRequestJson();
  expect(request, isNot(contains('locationId')));
  expect(request, isNot(contains('badgeCount')));
  expect(request['badgeIds'], isEmpty);
  expect(request['milestoneIds'], isEmpty);
  expect(request['contextReliability'], {
    'game': 'user_selected',
    'location': 'unknown',
    'badges': 'unknown',
    'milestones': 'unsupported',
  });
}

const _hgssBadgeIds = ['zephyr_badge', 'hive_badge', 'plain_badge'];

const _hgssJourney = CurrentJourney(
  game: 'SoulSilver',
  trainerName: 'Tito',
  location: '36号道路',
  badges: 3,
  maxBadges: 16,
  playTime: '18:42',
  party: [],
  timeline: [],
  companion: 'Cyndaquil',
  saveDexHash: 'linked-save',
  verifiedBadgeIds: _hgssBadgeIds,
);

const _hgssJourneyWithoutSave = CurrentJourney(
  game: 'SoulSilver',
  trainerName: 'Tito',
  location: '36号道路',
  badges: 3,
  maxBadges: 16,
  playTime: '18:42',
  party: [],
  timeline: [],
  companion: 'Cyndaquil',
  verifiedBadgeIds: _hgssBadgeIds,
);
