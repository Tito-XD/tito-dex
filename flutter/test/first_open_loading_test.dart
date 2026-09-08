import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/companion/battle_tools_service.dart';
import 'package:titodex/features/dex/dex_cache_store.dart';
import 'package:titodex/features/dex/dex_json_decode.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/type_chart.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/companion/battle_calc_page.dart';
import 'package:titodex/pages/companion/blind_spot_page.dart';
import 'package:titodex/pages/companion/quick_damage_page.dart';
import 'package:titodex/pages/companion/stat_calc_page.dart';
import 'package:titodex/pages/companion/type_matchup_page.dart';
import 'package:titodex/widgets/tito_loading_panel.dart';
import 'package:titodex/widgets/tito_pokeball_loading.dart';

const _move = CachedMove(
  id: 33,
  nameEn: 'tackle',
  nameZh: '撞击',
  type: 'normal',
  category: 'physical',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'unused stores do not start platform I/O without a platform host',
    () async {
      DexCacheStore();
      // Let an accidentally eager path_provider Future report an unhandled
      // missing-plugin error. No platform channel is installed in this test.
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('large and small JSON retain nested values and decode errors', () async {
    for (final count in [1, 4000]) {
      final payload = {
        'entries': List.generate(count, (i) => {'id': i, 'name': '精灵$i'}),
      };
      expect(await decodeDexJson(jsonEncode(payload)), payload);
    }
    await expectLater(decodeDexJson('['), throwsFormatException);
    await expectLater(decodeDexJson('${' ' * 40000}['), throwsFormatException);
  });

  test(
    'concurrent move reads share decoding and reload after replacement',
    () async {
      final root = await Directory.systemTemp.createTemp('titodex-loading-');
      addTearDown(() => root.delete(recursive: true));
      final paths = DexCachePaths(root);
      final store = DexCacheStore(paths: paths);
      await store.writeMoves({33: _move});
      final reads = await Future.wait(
        List.generate(6, (_) => store.readMoves()),
      );
      for (final moves in reads) {
        expect(moves, same(reads.first));
        expect(moves[33]!.nameZh, '撞击');
      }
      // Bundle installs replace files outside this store's write methods.
      await paths.movesFile.writeAsString('{}');
      expect(await store.readMoves(), isEmpty);
      await store.writeMoves({33: _move});
      expect((await store.readMoves())[33]!.nameZh, '撞击');
      await paths.movesFile.writeAsString('invalid');
      await expectLater(store.readMoves(), throwsFormatException);
      await store.writeMoves({33: _move});
      expect((await store.readMoves())[33]!.id, 33);
    },
  );

  test(
    'battle tools coalesce simultaneous cold reads and reuse ready data',
    () async {
      final store = _RelationsStore();
      final service = BattleToolsService(store: store);
      final first = service.loadTypeRelations();
      final second = service.loadTypeRelations();
      expect(store.reads, 1);
      final relations = {
        'normal': const TypeDamageRelations(
          doubleDamageTo: {},
          halfDamageTo: {'rock'},
          noDamageTo: {'ghost'},
        ),
      };
      store.ready.complete(relations);
      expect(await first, same(relations));
      expect(await second, same(relations));
      expect(service.cachedTypeRelations, same(relations));
      expect(await service.loadTypeRelations(), same(relations));
      expect(store.reads, 1);
    },
  );

  testWidgets(
    'short waits never mount the ball and long waits settle immediately',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TitoLoadingPanel())),
      );
      expect(find.byType(TitoPokeballLoading), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('ready'))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TitoPokeballLoading), findsNothing);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TitoLoadingPanel())),
      );
      await tester.pump(const Duration(milliseconds: 161));
      expect(find.byType(TitoPokeballLoading), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('ready'))),
      );
      expect(find.text('ready'), findsOneWidget);
      expect(find.byType(TitoPokeballLoading), findsNothing);
    },
  );

  testWidgets('ball rotates a stable painted silhouette without shimmer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TitoPokeballLoading(onLight: true)),
      ),
    );
    final paintFinder = find.descendant(
      of: find.byType(TitoPokeballLoading),
      matching: find.byType(CustomPaint),
    );
    final before = tester.widget<CustomPaint>(paintFinder).painter;
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.widget<CustomPaint>(paintFinder).painter, same(before));
    expect(find.byType(ShaderMask), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('opening stats does not mount the other three battle tools', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/search/companion',
      routes: [
        GoRoute(
          path: '/search/companion',
          builder: (_, _) => Scaffold(
            body: BattleCalcPage(
              journey: CurrentJourney.mock(),
              initialMode: BattleCalcMode.stats,
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.byType(StatCalcPage, skipOffstage: false), findsOneWidget);
    expect(find.byType(TypeMatchupPage, skipOffstage: false), findsNothing);
    expect(find.byType(QuickDamagePage, skipOffstage: false), findsNothing);
    expect(find.byType(BlindSpotPage, skipOffstage: false), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

class _RelationsStore extends DexCacheStore {
  _RelationsStore() : super(paths: DexCachePaths(Directory.systemTemp));
  final ready = Completer<Map<String, TypeDamageRelations>>();
  int reads = 0;

  @override
  Future<Map<String, TypeDamageRelations>> readTypeRelations() {
    reads++;
    return ready.future;
  }
}
