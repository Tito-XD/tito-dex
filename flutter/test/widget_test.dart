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
  });

  testWidgets('Home-action pages use a reversible container Hero', (
    tester,
  ) async {
    final page =
        titoMaterialPage<void>(
              key: const ValueKey<String>('team-page'),
              heroTag: TitoHomeActionHero.team,
              child: const Placeholder(),
            )
            as MaterialPage<void>;

    await tester.pumpWidget(MaterialApp(home: page.child));

    expect(find.byType(Placeholder), findsOneWidget);
    expect(find.byType(Hero), findsOneWidget);
    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.child, isA<Placeholder>());
    expect(hero.flightShuttleBuilder, isNotNull);
    expect(hero.transitionOnUserGestures, isTrue);
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
          MaterialPage<void>(
            key: const ValueKey<String>('home'),
            child: Scaffold(
              body: Center(
                child: Hero(
                  tag: TitoHomeActionHero.team,
                  transitionOnUserGestures: true,
                  child: SizedBox(
                    key: const ValueKey<String>('open-card'),
                    width: 120,
                    height: 72,
                    child: Material(
                      color: Colors.white,
                      child: InkWell(onTap: () => setState(() => _open = true)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_open)
            titoMaterialPage<void>(
              key: const ValueKey<String>('team'),
              heroTag: TitoHomeActionHero.team,
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
