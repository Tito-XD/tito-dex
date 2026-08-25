import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/navigation/tito_page_transition.dart';
import 'package:titodex/pages/pokemon_detail_page.dart';
import 'package:titodex/widgets/dex_sprite_image.dart';
import 'package:titodex/widgets/pokemon_card.dart';
import 'package:titodex/widgets/pokemon_detail_sections.dart';
import 'package:titodex/widgets/tito_page_container.dart';

const _summary = PokemonSummary(
  id: 1,
  nameEn: 'Bulbasaur',
  nameZh: '妙蛙种子',
  types: ['grass', 'poison'],
);

const _immediateDetail = PokemonDetail(
  summary: _summary,
  genusZh: '种子宝可梦',
  heightDm: 7,
  weightHg: 69,
  weaknesses: [],
  resistances: [],
  immunities: [],
  stabSuperEffective: [],
  evolutionChain: null,
);

Future<void> _pumpUntilRouteInserted(
  WidgetTester tester,
  Finder destination,
) async {
  for (var frame = 0; frame < 8; frame += 1) {
    await tester.pump();
    if (destination.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('GoRouter did not insert the destination after eight zero-time frames');
}

void main() {
  testWidgets(
    'Dex card keeps a first-frame Hero target through immediate detail load',
    (tester) async {
      late final GoRouter router;
      router = GoRouter(
        initialLocation: '/dex',
        routes: [
          GoRoute(
            path: '/dex',
            builder: (context, state) => Scaffold(
              body: Center(
                child: SizedBox(
                  width: 128,
                  height: 152,
                  child: PokemonMiniCard(
                    summary: _summary,
                    status: DexEncounterStatus.unknown,
                    onTap: () => context.push(
                      '/dex/1',
                      extra: const PokemonDetailTransition(summary: _summary),
                    ),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/dex/:id',
            pageBuilder: (context, state) {
              final transition = state.extra! as PokemonDetailTransition;
              return titoDexDetailPage<void>(
                key: state.pageKey,
                child: TitoPageContainer(
                  child: PokemonDetailPage(
                    pokemonId: 1,
                    transitionSummary: transition.summary,
                    initialDetail: _immediateDetail,
                  ),
                ),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pokemon-card-tap-1')));
      await _pumpUntilRouteInserted(tester, find.byType(PokemonDetailPage));
      expect(find.byType(PokemonDetailPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('tito-dex-detail-fade')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('tito-side-slide-transition')),
        findsNothing,
      );

      expect(
        find.byKey(const ValueKey('pokemon-detail-shared-element-stage')),
        findsOneWidget,
      );
      expect(find.byType(PokemonDetailTransitionHeader), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 120));
      final sourceLayer = tester.widget<Opacity>(
        find.byKey(const ValueKey('pokemon-card-flight-source')),
      );
      final targetLayer = tester.widget<Opacity>(
        find.byKey(const ValueKey('pokemon-card-flight-target')),
      );
      expect(sourceLayer.opacity, greaterThan(0));
      expect(targetLayer.opacity, greaterThan(0));
      expect(
        find.byKey(const ValueKey('pokemon-detail-shared-element-stage')),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pokemon-detail-shared-element-stage')),
        findsNothing,
      );
      expect(find.byType(PokemonDetailHeader), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pokemon-detail-content-arrival')),
        findsOneWidget,
      );
      final detailRoute = ModalRoute.of(
        tester.element(find.byType(PokemonDetailHeader)),
      )!;
      expect(detailRoute.popGestureEnabled, isTrue);
      expect(detailRoute.transitionDuration, titoDexDetailTransitionDuration);

      await tester.tap(find.byKey(const ValueKey('pokemon-detail-artwork')));
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('pokemon-artwork-viewer')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pokemon-artwork-viewer')),
        findsNothing,
      );
      expect(find.byType(PokemonDetailHeader), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _sendBackGestureMethod(
        tester,
        const MethodCall('startBackGesture', <String, dynamic>{
          'touchOffset': <double>[5, 300],
          'progress': 0.0,
          'swipeEdge': 0,
        }),
      );
      await _sendBackGestureMethod(
        tester,
        const MethodCall('updateBackGestureProgress', <String, dynamic>{
          'touchOffset': <double>[180, 300],
          'progress': 0.55,
          'swipeEdge': 0,
        }),
      );
      await tester.pump();
      expect(
        tester
            .widget<FadeTransition>(
              find.byKey(const ValueKey<String>('tito-dex-detail-fade')),
            )
            .opacity
            .value,
        inExclusiveRange(0, 1),
      );
      await _sendBackGestureMethod(
        tester,
        const MethodCall('updateBackGestureProgress', <String, dynamic>{
          'touchOffset': <double>[360, 300],
          'progress': 1.0,
          'swipeEdge': 0,
        }),
      );
      expect(detailRoute.animation!.value, greaterThan(0));
      await _sendBackGestureMethod(
        tester,
        const MethodCall('commitBackGesture'),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(const ValueKey('pokemon-detail-artwork')),
        findsNothing,
      );
      final returningHeaderLayer = find.byKey(
        const ValueKey('pokemon-card-flight-target'),
      );
      expect(returningHeaderLayer, findsOneWidget);
      expect(
        tester.widget<Opacity>(returningHeaderLayer).opacity,
        greaterThan(0),
      );
      expect(
        find.descendant(
          of: returningHeaderLayer,
          matching: find.byType(DexSpriteImage),
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(find.byType(PokemonMiniCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('detail tabs and move filters animate through a middle frame', (
    tester,
  ) async {
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/dex',
      routes: [
        GoRoute(
          path: '/dex',
          builder: (context, state) => Scaffold(
            body: Center(
              child: SizedBox(
                width: 128,
                height: 152,
                child: PokemonMiniCard(
                  summary: _summary,
                  status: DexEncounterStatus.unknown,
                  onTap: () => context.push(
                    '/dex/1',
                    extra: const PokemonDetailTransition(summary: _summary),
                  ),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/dex/:id',
          pageBuilder: (context, state) {
            final transition = state.extra! as PokemonDetailTransition;
            return titoDexDetailPage<void>(
              key: state.pageKey,
              child: TitoPageContainer(
                child: PokemonDetailPage(
                  pokemonId: 1,
                  transitionSummary: transition.summary,
                  initialDetail: _immediateDetail,
                ),
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pokemon-card-tap-1')));
    await _pumpUntilRouteInserted(tester, find.byType(PokemonDetailPage));
    await tester.pump(const Duration(milliseconds: 520));
    await tester.pump();
    await tester.pump();

    double translationY(String key) => tester
        .widget<Transform>(find.byKey(ValueKey<String>(key)))
        .transform
        .getTranslation()
        .y;

    expect(translationY('detail-tab-motion-1'), 0);
    await tester.tap(find.text(AppZh.dexTabBasic));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final tabMiddle = translationY('detail-tab-motion-1');
    expect(tabMiddle, greaterThan(-1.5));
    expect(tabMiddle, lessThan(0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(translationY('detail-tab-motion-1'), -1.5);

    await tester.tap(find.text(AppZh.dexTabMoves));
    await tester.pump(const Duration(milliseconds: 450));
    expect(translationY('move-filter-motion-1'), 0);
    await tester.tap(find.text(AppZh.dexMoveFilterMachine));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final moveMiddle = translationY('move-filter-motion-1');
    expect(moveMiddle, greaterThan(-1.5));
    expect(moveMiddle, lessThan(0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(translationY('move-filter-motion-1'), -1.5);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _sendBackGestureMethod(
  WidgetTester tester,
  MethodCall call,
) async {
  final message = const StandardMethodCodec().encodeMethodCall(call);
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (_) {},
  );
}
