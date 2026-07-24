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

  testWidgets('Dex expands in 320ms and collapses in 280ms', (tester) async {
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
    expect(titoDexTransitionDuration, const Duration(milliseconds: 320));
    expect(
      titoDexReverseTransitionDuration,
      const Duration(milliseconds: 280),
    );
    expect(route.opaque, isTrue);
    expect(route.popGestureEnabled, isFalse);
    expect(
      tester.widget<Hero>(find.byType(Hero)).transitionOnUserGestures,
      isFalse,
    );
  });

  testWidgets('Dex shell expands before its list cards fade in', (
    tester,
  ) async {
    await tester.pumpWidget(const _DexFadeHarness());
    final home = find.byKey(const ValueKey<String>('home-surface'));
    final initialPosition = tester.getTopLeft(home);

    await tester.tap(find.byKey(const ValueKey<String>('open-card')));
    await tester.pump();
    var fade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey<String>('tito-dex-content-reveal')),
    );
    expect(fade.opacity.value, lessThan(0.1));
    expect(tester.getTopLeft(home), initialPosition);

    await tester.pump(const Duration(milliseconds: 150));
    fade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey<String>('tito-dex-content-reveal')),
    );
    expect(fade.opacity.value, lessThan(0.1));
    await tester.pump(const Duration(milliseconds: 130));
    fade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey<String>('tito-dex-content-reveal')),
    );
    expect(fade.opacity.value, greaterThan(0));
    expect(fade.opacity.value, lessThan(1));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('close-page')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('open-card')), findsOneWidget);
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

class _DexFadeHarness extends StatefulWidget {
  const _DexFadeHarness();

  @override
  State<_DexFadeHarness> createState() => _DexFadeHarnessState();
}

class _DexFadeHarnessState extends State<_DexFadeHarness> {
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
                    transitionOnUserGestures: false,
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
