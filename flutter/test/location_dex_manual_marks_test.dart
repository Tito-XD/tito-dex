import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/location_index.dart';
import 'package:titodex/features/game/game_edition.dart';
import 'package:titodex/features/game/game_edition_repository.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/dex/location_dex_page.dart';

const _journey = CurrentJourney(
  game: 'Scarlet',
  trainerName: 'Tito',
  location: '',
  badges: 0,
  maxBadges: 8,
  playTime: '00:00',
  party: [],
  timeline: [],
  companion: '',
  manualDexSeenIds: [1],
  manualDexCaughtIds: [1],
);

const _area = LocationArea(
  slug: 'route-1',
  labelZh: '一号道路',
  entries: [
    LocationEncounterEntry(speciesId: 1),
    LocationEncounterEntry(speciesId: 4),
  ],
);

const _summaries = [
  PokemonSummary(id: 1, nameEn: 'bulbasaur', nameZh: '妙蛙种子', types: ['grass']),
  PokemonSummary(id: 4, nameEn: 'charmander', nameZh: '小火龙', types: ['fire']),
];

Future<void> _pumpLocationDex(WidgetTester tester) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: LocationDexPage(
            journey: _journey,
            loadOverride: () async => (areas: [_area], summaries: _summaries),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(400, 800), disableAnimations: true),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('manual caught marks count for non-save-linked editions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await gameEditionRepository.save(gameEditionFromSlug('sv')!);

    await _pumpLocationDex(tester);

    expect(find.text('已捕获 1 / 2'), findsOneWidget);

    await tester.tap(find.text('一号道路'));
    await tester.pumpAndSettle();

    // "Uncaught only" starts on, so the manually caught species is hidden.
    expect(find.text('小火龙'), findsOneWidget);
    expect(find.text('妙蛙种子'), findsNothing);
  });

  testWidgets('save-linked editions ignore manual marks', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await gameEditionRepository.save(GameEdition.hgss);

    await _pumpLocationDex(tester);

    expect(find.text('已捕获 0 / 2'), findsOneWidget);
  });
}
