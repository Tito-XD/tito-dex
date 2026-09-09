import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:titodex/features/dex/dex_filter.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_progress.dart';
import 'package:titodex/features/dex/location_index.dart';
import 'package:titodex/features/game/game_edition.dart';
import 'package:titodex/features/journey/journey_assistant.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/widgets/journey_assistant_panel.dart';
import 'package:titodex/widgets/journey_card.dart';
import 'package:titodex/widgets/tito_fact_grid.dart';

void main() {
  const summaries = {
    19: PokemonSummary(
      id: 19,
      nameEn: 'rattata',
      nameZh: '小拉达',
      types: ['normal'],
    ),
    20: PokemonSummary(
      id: 20,
      nameEn: 'raticate',
      nameZh: '拉达',
      types: ['normal'],
    ),
    21: PokemonSummary(
      id: 21,
      nameEn: 'spearow',
      nameZh: '烈雀',
      types: ['normal', 'flying'],
    ),
    22: PokemonSummary(
      id: 22,
      nameEn: 'fearow',
      nameZh: '大嘴雀',
      types: ['normal', 'flying'],
    ),
    156: PokemonSummary(
      id: 156,
      nameEn: 'quilava',
      nameZh: '火岩鼠',
      types: ['fire'],
    ),
  };

  const journey = CurrentJourney(
    game: 'SoulSilver',
    trainerName: 'Tito',
    location: '满金市',
    badges: 3,
    maxBadges: 8,
    playTime: '18:42',
    party: [PartyMember(species: 'Quilava', speciesId: 156, level: 24)],
    timeline: [],
    companion: 'Cyndaquil',
  );

  test('location matching merges subareas sharing the save label', () {
    final areas = _index.areasForEdition(
      GameEdition.hgss.withFlavor('soulsilver'),
    );
    expect(matchJourneyLocation(areas, '满金市'), hasLength(2));
    expect(matchJourneyLocation(areas, '满金市 宝可梦中心'), hasLength(2));
    expect(matchJourneyLocation(areas, '未知地点'), isEmpty);
  });

  test('snapshot aligns nearby, version and party advice', () {
    final snapshot = buildJourneyAssistantSnapshot(
      journey: journey,
      edition: GameEdition.hgss.withFlavor('soulsilver'),
      index: _index,
      summaries: summaries,
      progress: const DexProgress(caughtIds: {19}, seenIds: {19, 20}),
      evolutionOrTradeMissingIds: {20, 22},
      partyDetails: {156: _quilavaDetail},
    );

    expect(snapshot.locationMatched, isTrue);
    expect(snapshot.nearbyUncaughtCount, 1);
    expect(snapshot.nearbyUncaught.single.id, 20);
    expect(snapshot.versionEncounterGapCount, 1);
    expect(snapshot.versionEncounterGaps.single.id, 21);
    expect(snapshot.evolutionOrTradeMissingCount, 2);
    expect(snapshot.partyEvolutions.single.toId, 157);
    expect(snapshot.cardSummary, '附近 1 种待捕');
  });

  testWidgets('journey surfaces show assistant summary and full sections', (
    tester,
  ) async {
    final snapshot = buildJourneyAssistantSnapshot(
      journey: journey,
      edition: GameEdition.hgss.withFlavor('soulsilver'),
      index: _index,
      summaries: summaries,
      progress: const DexProgress(caughtIds: {19}, seenIds: {19, 20}),
      evolutionOrTradeMissingIds: {20, 22},
      partyDetails: {156: _quilavaDetail},
    );
    final future = Future.value(snapshot);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              SizedBox(
                height: 150,
                child: JourneyCard(
                  journey: journey,
                  onOpenDetail: () {},
                  assistantFuture: future,
                ),
              ),
              JourneyAssistantPanel(future: future),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('附近 1 种待捕'), findsOneWidget);
    expect(find.bySemanticsLabel('查看旅程详情'), findsOneWidget);
    expect(find.text('附近未捕获'), findsOneWidget);
    expect(find.text('队伍与进化'), findsNothing);
    expect(find.text('版本补全'), findsOneWidget);
    expect(find.textContaining('火岩鼠 → 火暴兽'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'completion keeps the full list and separates caught and paired species',
    () {
      final snapshot = buildJourneyAssistantSnapshot(
        journey: journey,
        edition: GameEdition.hgss.withFlavor('soulsilver'),
        index: _index,
        summaries: {
          ...summaries,
          for (var id = 30; id < 40; id++)
            id: PokemonSummary(
              id: id,
              nameEn: 'species-$id',
              nameZh: '宝可梦$id',
              types: const [],
            ),
        },
        progress: const DexProgress(caughtIds: {19}, seenIds: {}),
        evolutionOrTradeMissingIds: {
          19,
          21,
          22,
          for (var id = 30; id < 40; id++) id,
        },
      );
      expect(snapshot.versionEncounterGaps.map((p) => p.id), [21]);
      expect(snapshot.evolutionOrTradeMissing.map((p) => p.id), [
        22,
        for (var id = 30; id < 40; id++) id,
      ]);
      expect(snapshot.evolutionOrTradeMissingCount, 11);
    },
  );

  testWidgets(
    'completion grid uses the paired game and hands other species to Dex',
    (tester) async {
      final snapshot = buildJourneyAssistantSnapshot(
        journey: journey,
        edition: GameEdition.hgss.withFlavor('soulsilver'),
        index: _index,
        summaries: summaries,
        progress: const DexProgress(caughtIds: {19}, seenIds: {}),
        evolutionOrTradeMissingIds: {20, 21, 22},
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: JourneyAssistantPanel(future: Future.value(snapshot)),
              ),
            ),
          ),
          GoRoute(
            path: '/dex',
            builder: (context, state) =>
                const Scaffold(body: Text('filtered-dex')),
          ),
          GoRoute(
            path: '/dex/:id',
            builder: (context, state) =>
                Scaffold(body: Text(state.uri.toString())),
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(dexFilterController.clearFilter);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final paired = find.widgetWithText(TitoFactTile, '烈雀');
      await tester.ensureVisible(paired);
      await tester.pumpAndSettle();
      await tester.tap(paired);
      await tester.pumpAndSettle();
      expect(find.text('/dex/21?version=heartgold'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      final other = find.byKey(const Key('journey-remaining-dex'));
      await tester.ensureVisible(other);
      await tester.pumpAndSettle();
      await tester.tap(other);
      await tester.pumpAndSettle();
      expect(find.text('filtered-dex'), findsOneWidget);
      expect(dexFilterController.currentFilter.speciesIds, {20, 22});
    },
  );
}

const _index = LocationIndex(
  byVersion: {
    'soulsilver': [
      LocationArea(
        slug: 'goldenrod-game-corner',
        labelZh: '满金市',
        entries: [
          LocationEncounterEntry(speciesId: 19, maxChance: 20),
          LocationEncounterEntry(speciesId: 20, maxChance: 10),
        ],
      ),
      LocationArea(
        slug: 'goldenrod-north-gate',
        labelZh: '满金市',
        entries: [LocationEncounterEntry(speciesId: 20, maxChance: 30)],
      ),
    ],
    'heartgold': [
      LocationArea(
        slug: 'goldenrod-game-corner',
        labelZh: '满金市',
        entries: [
          LocationEncounterEntry(speciesId: 20),
          LocationEncounterEntry(speciesId: 21),
        ],
      ),
    ],
  },
);

const _quilavaDetail = PokemonDetail(
  summary: PokemonSummary(
    id: 156,
    nameEn: 'quilava',
    nameZh: '火岩鼠',
    types: ['fire'],
  ),
  genusZh: '火山宝可梦',
  heightDm: 9,
  weightHg: 190,
  weaknesses: ['water'],
  resistances: ['fire'],
  immunities: [],
  stabSuperEffective: ['grass'],
  evolutionChain: EvolutionNode(
    id: 155,
    nameEn: 'cyndaquil',
    nameZh: '火球鼠',
    children: [
      EvolutionNode(
        id: 156,
        nameEn: 'quilava',
        nameZh: '火岩鼠',
        triggerZh: '等级达到 14',
        children: [
          EvolutionNode(
            id: 157,
            nameEn: 'typhlosion',
            nameZh: '火暴兽',
            triggerZh: '等级达到 36',
          ),
        ],
      ),
    ],
  ),
);
