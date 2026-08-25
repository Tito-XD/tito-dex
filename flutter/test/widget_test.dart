import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/app.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/navigation/tito_page_transition.dart';

void main() {
  testWidgets('TitoDex app opens home without a blocking bootstrap loader', (
    tester,
  ) async {
    await tester.pumpWidget(const TitoDexApp());
    await tester.pump();

    expect(find.text(AppZh.appTitle), findsWidgets);
    expect(find.text(AppZh.bootstrapLoading), findsNothing);
    expect(find.text(AppZh.trainerNameLine('Tito')), findsOneWidget);
    expect(find.byType(Hero), findsOneWidget);
  });

  testWidgets('Dex expands in 340ms and collapses in 300ms', (tester) async {
    final page = titoDexPage<void>(
      key: const ValueKey<String>('dex-page'),
      heroTag: TitoHomeActionHero.dex,
      child: const Placeholder(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(pages: [page], onDidRemovePage: (_) {}),
      ),
    );

    expect(find.byType(Placeholder), findsOneWidget);
    expect(find.byType(Hero), findsOneWidget);
    final route = ModalRoute.of(tester.element(find.byType(Placeholder)))!;
    expect(route.transitionDuration, titoDexTransitionDuration);
    expect(route.reverseTransitionDuration, titoDexReverseTransitionDuration);
    expect(titoDexTransitionDuration, const Duration(milliseconds: 340));
    expect(titoDexReverseTransitionDuration, const Duration(milliseconds: 300));
    expect(route.opaque, isTrue);
    // This harness has no previous route, so PageRoute correctly cannot pop.
    expect(route.popGestureEnabled, isFalse);
    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.transitionOnUserGestures, isTrue);
    expect(hero.createRectTween, same(titoDexRectTween));
    expect(hero.curve, titoDexForwardCurve);
    expect(hero.reverseCurve, titoDexReverseCurve);

    // Predictive-back drags keep a runway above 0 so a full-edge commit
    // always plays the framework fade instead of vanishing instantly.
    route.handleUpdateBackGestureProgress(progress: 0.0);
    expect(route.animation?.value, greaterThan(0.0));
    route.handleUpdateBackGestureProgress(progress: 1.0);
  });

  testWidgets('direct Dex links fall back cleanly without a source Hero', (
    tester,
  ) async {
    final page = titoDexPage<void>(
      key: const ValueKey<String>('direct-dex-page'),
      child: const ColoredBox(color: Colors.blueGrey),
      content: const Text(
        'Direct Dex content',
        key: ValueKey<String>('direct-dex-content'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(pages: [page], onDidRemovePage: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Hero), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('direct-dex-content')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dex shell and list share one compact reveal timeline', (
    tester,
  ) async {
    await tester.pumpWidget(const _DexFadeHarness());
    final home = find.byKey(const ValueKey<String>('home-surface'));
    final initialPosition = tester.getTopLeft(home);

    await tester.tap(find.byKey(const ValueKey<String>('open-card')));
    await tester.pump();
    await tester.pump();
    var fade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey<String>('tito-dex-content-reveal')),
    );
    expect(fade.opacity.value, lessThan(0.1));
    expect(tester.getTopLeft(home), initialPosition);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    fade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey<String>('tito-dex-content-reveal')),
    );
    expect(fade.opacity.value, lessThan(0.1));
    final sourceLayer = tester.widget<Opacity>(
      find.byKey(const ValueKey<String>('tito-dex-flight-source')),
    );
    final targetLayer = tester.widget<Opacity>(
      find.byKey(const ValueKey<String>('tito-dex-flight-target')),
    );
    expect(sourceLayer.opacity, greaterThan(0));
    expect(targetLayer.opacity, greaterThan(0));
    final sourceFit = tester.widget<FittedBox>(
      find.byKey(const ValueKey<String>('tito-dex-flight-source-fit')),
    );
    expect(sourceFit.fit, BoxFit.scaleDown);

    await tester.pump(const Duration(milliseconds: 90));
    fade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey<String>('tito-dex-content-reveal')),
    );
    expect(fade.opacity.value, greaterThan(0));
    expect(fade.opacity.value, lessThan(1));
    await tester.pumpAndSettle();

    // With Home underneath and the route settled, Android can scrub back.
    final dexRoute = ModalRoute.of(
      tester.element(find.byKey(const ValueKey<String>('close-page'))),
    )!;
    expect(dexRoute.popGestureEnabled, isTrue);

    await tester.tap(find.byKey(const ValueKey<String>('close-page')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 25));
    fade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey<String>('tito-dex-content-reveal')),
    );
    expect(fade.opacity.value, greaterThan(0));
    expect(fade.opacity.value, lessThan(0.9));
    await tester.pump(const Duration(milliseconds: 205));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('open-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion removes the Dex content rise without a flash', (
    tester,
  ) async {
    await tester.pumpWidget(const _DexFadeHarness(disableAnimations: true));

    await tester.tap(find.byKey(const ValueKey<String>('open-card')));
    await tester.pump();
    await tester.pump();
    var fade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey<String>('tito-dex-content-reveal')),
    );
    final slide = tester.widget<SlideTransition>(
      find.byKey(const ValueKey<String>('tito-dex-content-slide')),
    );
    expect(fade.opacity.value, 0);
    expect(slide.position.value, Offset.zero);

    await tester.pump(const Duration(milliseconds: 130));
    fade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey<String>('tito-dex-content-reveal')),
    );
    expect(fade.opacity.value, greaterThan(0));
    expect(fade.opacity.value, lessThan(1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey<String>('close-page')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    fade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey<String>('tito-dex-content-reveal')),
    );
    expect(fade.opacity.value, greaterThan(0));
    expect(fade.opacity.value, lessThan(0.1));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dex list stays mounted when a nested detail drops Hero extra', (
    tester,
  ) async {
    await tester.pumpWidget(const _DexNestedRouteHarness());
    await tester.pumpAndSettle();

    final harness = tester.state<_DexNestedRouteHarnessState>(
      find.byType(_DexNestedRouteHarness),
    );
    final listState = harness.listKey.currentState!;
    listState.controller.jumpTo(720);
    await tester.pump();
    expect(listState.controller.offset, 720);

    harness.openDetail();
    await tester.pump();

    expect(harness.listKey.currentState, same(listState));
    expect(listState.controller.offset, 720);
    expect(find.byKey(const ValueKey<String>('nested-detail')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Team and Search slide from their matching screen edges', (
    tester,
  ) async {
    for (final direction in TitoSideSlideDirection.values) {
      await tester.pumpWidget(_SideSlideHarness(direction: direction));
      await tester.tap(find.byKey(const ValueKey<String>('open-side-page')));
      await tester.pump();

      final route = ModalRoute.of(
        tester.element(find.byKey(const ValueKey<String>('close-side-page'))),
      )!;
      expect(route.transitionDuration, titoSideSlideTransitionDuration);
      expect(
        route.reverseTransitionDuration,
        titoSideSlideReverseTransitionDuration,
      );
      expect(route.popGestureEnabled, isFalse);

      expect(find.byType(Hero), findsNothing);
      final slideFinder = find.byKey(
        const ValueKey<String>('tito-side-slide-transition'),
      );
      var slide = tester.widget<SlideTransition>(slideFinder);
      expect(slide.position.value.dx.abs(), lessThanOrEqualTo(0.032));
      expect(slide.position.value.dy, 0);

      await tester.pump(const Duration(milliseconds: 225));
      slide = tester.widget<SlideTransition>(slideFinder);
      expect(
        slide.position.value.dx.isNegative,
        direction == TitoSideSlideDirection.fromLeft,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('close-side-page')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 225));
      slide = tester.widget<SlideTransition>(slideFinder);
      expect(
        slide.position.value.dx.isNegative,
        direction == TitoSideSlideDirection.fromLeft,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    }
  });
}

class _DexNestedRouteHarness extends StatefulWidget {
  const _DexNestedRouteHarness();

  @override
  State<_DexNestedRouteHarness> createState() => _DexNestedRouteHarnessState();
}

class _DexNestedRouteHarnessState extends State<_DexNestedRouteHarness> {
  final listKey = GlobalKey<_TrackedDexListState>();
  bool _detailOpen = false;

  void openDetail() => setState(() => _detailOpen = true);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Navigator(
        pages: [
          titoHomePage<void>(
            key: const ValueKey<String>('nested-home'),
            child: const Material(
              child: Center(
                child: Hero(
                  tag: TitoHomeActionHero.dex,
                  child: SizedBox(width: 120, height: 72),
                ),
              ),
            ),
          ),
          titoDexPage<void>(
            key: const ValueKey<String>('nested-dex'),
            heroTag: _detailOpen ? null : TitoHomeActionHero.dex,
            child: const ColoredBox(color: Colors.blueGrey),
            content: _TrackedDexList(key: listKey),
          ),
          if (_detailOpen)
            titoMaterialPage<void>(
              key: const ValueKey<String>('nested-detail-route'),
              child: const ColoredBox(
                key: ValueKey<String>('nested-detail'),
                color: Colors.white,
              ),
            ),
        ],
        onDidRemovePage: (_) {},
      ),
    );
  }
}

class _TrackedDexList extends StatefulWidget {
  const _TrackedDexList({super.key});

  @override
  State<_TrackedDexList> createState() => _TrackedDexListState();
}

class _TrackedDexListState extends State<_TrackedDexList> {
  final controller = ScrollController(keepScrollOffset: false);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      itemExtent: 80,
      itemCount: 30,
      itemBuilder: (context, index) => Text('Entry $index'),
    );
  }
}

class _DexFadeHarness extends StatefulWidget {
  const _DexFadeHarness({this.disableAnimations = false});

  final bool disableAnimations;

  @override
  State<_DexFadeHarness> createState() => _DexFadeHarnessState();
}

class _DexFadeHarnessState extends State<_DexFadeHarness> {
  bool _open = false;
  final HeroController _heroController = HeroController();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        if (!widget.disableAnimations) {
          return child!;
        }
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        );
      },
      home: Navigator(
        observers: [_heroController],
        pages: [
          titoHomePage<void>(
            key: const ValueKey<String>('home'),
            child: Scaffold(
              body: ColoredBox(
                key: const ValueKey<String>('home-surface'),
                color: Colors.white,
                child: Center(
                  child: Hero(
                    tag: TitoHomeActionHero.dex,
                    transitionOnUserGestures: true,
                    child: SizedBox(
                      key: const ValueKey<String>('open-card'),
                      width: 120,
                      height: 72,
                      child: Material(
                        color: Colors.white,
                        child: InkWell(
                          onTap: () => setState(() => _open = true),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_open)
            titoDexPage<void>(
              key: const ValueKey<String>('dex'),
              heroTag: TitoHomeActionHero.dex,
              child: const ColoredBox(color: Colors.blueGrey),
              content: Center(
                child: TextButton(
                  key: const ValueKey<String>('close-page'),
                  onPressed: () => setState(() => _open = false),
                  child: const Text('Back'),
                ),
              ),
            ),
        ],
        onDidRemovePage: (_) {},
      ),
    );
  }
}

class _SideSlideHarness extends StatefulWidget {
  const _SideSlideHarness({required this.direction});

  final TitoSideSlideDirection direction;

  @override
  State<_SideSlideHarness> createState() => _SideSlideHarnessState();
}

class _SideSlideHarnessState extends State<_SideSlideHarness> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Navigator(
        pages: [
          titoHomePage<void>(
            key: const ValueKey<String>('home'),
            child: Material(
              child: Center(
                child: TextButton(
                  key: const ValueKey<String>('open-side-page'),
                  onPressed: () => setState(() => _open = true),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
          if (_open)
            titoSideSlidePage<void>(
              key: ValueKey<TitoSideSlideDirection>(widget.direction),
              direction: widget.direction,
              child: Material(
                color: Colors.blueGrey,
                child: Center(
                  child: TextButton(
                    key: const ValueKey<String>('close-side-page'),
                    onPressed: () => setState(() => _open = false),
                    child: const Text('Back'),
                  ),
                ),
              ),
            ),
        ],
        onDidRemovePage: (_) {},
      ),
    );
  }
}
