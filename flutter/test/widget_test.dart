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

  testWidgets('Dex uses a reversible 900ms container Hero', (tester) async {
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
    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.child, isA<Placeholder>());
    expect(hero.flightShuttleBuilder, isNotNull);
    expect(hero.transitionOnUserGestures, isTrue);
    final route = ModalRoute.of(tester.element(find.byType(Placeholder)))!;
    expect(route.transitionDuration, titoDexTransitionDuration);
    expect(route.reverseTransitionDuration, titoDexTransitionDuration);
  });

  testWidgets('Container Hero keeps a stateful full page stable both ways', (
    tester,
  ) async {
    await tester.pumpWidget(const _HomeActionFlightHarness());

    await tester.tap(find.byKey(const ValueKey<String>('open-card')));
    for (var index = 0; index < 6; index++) {
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('close-page')).last);
    for (var index = 0; index < 6; index++) {
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('open-card')), findsOneWidget);
  });

  testWidgets('Home stays fixed while the Dex container opens', (tester) async {
    await tester.pumpWidget(const _HomeActionFlightHarness());
    final home = find.byKey(const ValueKey<String>('home-surface'));
    final initialPosition = tester.getTopLeft(home);

    await tester.tap(find.byKey(const ValueKey<String>('open-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(tester.getTopLeft(home), initialPosition);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Team and Search slide from their matching screen edges', (
    tester,
  ) async {
    for (final direction in TitoSideSlideDirection.values) {
      await tester.pumpWidget(_SideSlideHarness(direction: direction));
      await tester.tap(find.byKey(const ValueKey<String>('open-side-page')));
      await tester.pump();

      expect(find.byType(Hero), findsNothing);
      final slideFinder = find.byKey(
        const ValueKey<String>('tito-side-slide-transition'),
      );
      var slide = tester.widget<SlideTransition>(slideFinder);
      expect(
        slide.position.value,
        direction == TitoSideSlideDirection.fromLeft
            ? const Offset(-1, 0)
            : const Offset(1, 0),
      );

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

class _HomeActionFlightHarness extends StatefulWidget {
  const _HomeActionFlightHarness();

  @override
  State<_HomeActionFlightHarness> createState() =>
      _HomeActionFlightHarnessState();
}

class _HomeActionFlightHarnessState extends State<_HomeActionFlightHarness> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Navigator(
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
              child: _StatefulFlightDestination(
                onClose: () => setState(() => _open = false),
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

class _StatefulFlightDestination extends StatefulWidget {
  const _StatefulFlightDestination({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_StatefulFlightDestination> createState() =>
      _StatefulFlightDestinationState();
}

class _StatefulFlightDestinationState
    extends State<_StatefulFlightDestination> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.blueGrey,
      child: SafeArea(
        child: Column(
          children: [
            TextField(controller: _controller),
            Expanded(
              child: ListView.builder(
                itemCount: 20,
                itemBuilder: (context, index) => Text('Item $index'),
              ),
            ),
            TextButton(
              key: const ValueKey<String>('close-page'),
              onPressed: widget.onClose,
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
