import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/widgets/pokemon_artwork_viewer.dart';

const _summary = PokemonSummary(
  id: 99999,
  nameEn: 'Testmon',
  nameZh: '测试宝可梦',
  types: ['normal'],
  artworkUrl: '/tmp/titodex-missing-test-artwork.png',
);

void main() {
  testWidgets('first platform back closes artwork without leaving detail', (
    tester,
  ) async {
    final shellNavigatorKey = GlobalKey<NavigatorState>();
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/dex/99999',
      routes: [
        ShellRoute(
          navigatorKey: shellNavigatorKey,
          builder: (context, state, child) => child,
          routes: [
            GoRoute(
              path: '/dex/99999',
              builder: (context, state) => Scaffold(
                body: Column(
                  children: [
                    const Text('detail-still-here'),
                    FilledButton(
                      onPressed: () =>
                          showPokemonArtworkViewer(context, summary: _summary),
                      child: const Text('open-artwork'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('open-artwork'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('pokemon-artwork-viewer')),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('pokemon-artwork-viewer')), findsNothing);
    expect(find.text('detail-still-here'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/dex/99999');
  });
}
