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
                    Hero(
                      tag: pokemonArtworkHeroTag(_summary),
                      transitionOnUserGestures: true,
                      child: FilledButton(
                        onPressed: () => showPokemonArtworkViewer(
                          context,
                          summary: _summary,
                        ),
                        child: const Text('open-artwork'),
                      ),
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('open-artwork'));
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('pokemon-artwork-viewer')),
      findsOneWidget,
    );
    final viewerRoute = ModalRoute.of(
      tester.element(find.byKey(const ValueKey('pokemon-artwork-viewer'))),
    )!;
    expect(viewerRoute, isA<PageRoute<void>>());
    expect(viewerRoute, isNot(isA<PopupRoute<void>>()));
    expect(
      viewerRoute.transitionDuration,
      pokemonArtworkViewerTransitionDuration,
    );

    await tester.pump(const Duration(milliseconds: 120));
    final chrome = tester.widget<FadeTransition>(
      find.byKey(const ValueKey('artwork-viewer-chrome')),
    );
    expect(chrome.opacity.value, 0);
    // The test URL intentionally cannot resolve. Failed high-resolution art
    // must not replace or hide the shared-element sprite.
    expect(find.byKey(const ValueKey('artwork-high-res-reveal')), findsNothing);
    expect(find.byKey(const ValueKey('artwork-stable-hero')), findsOneWidget);
    await tester.pumpAndSettle();
    final stableHeroFade = tester.widget<Opacity>(
      find.byKey(const ValueKey('artwork-stable-hero-fade')),
    );
    expect(stableHeroFade.opacity, 1);
    expect(viewerRoute.popGestureEnabled, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pokemon-artwork-viewer')), findsNothing);
    expect(find.text('detail-still-here'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/dex/99999');
  });
}
