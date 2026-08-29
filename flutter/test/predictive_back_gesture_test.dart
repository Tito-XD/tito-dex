import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:titodex/navigation/back_navigation.dart';
import 'package:titodex/navigation/tito_page_transition.dart';
import 'package:titodex/theme/tito_theme.dart';

/// Locks the Android predictive-back behavior of the app's custom routes.
///
/// These tests drive the real `flutter/backgesture` platform channel (the
/// same messages the engine sends for Android 14+ edge-swipe back), against
/// a miniature of app.dart's router wiring: a ShellRoute with the PopScope
/// builder around a nested navigator holding titoHomePage, titoDexPage and
/// titoSideSlidePage. They pin three load-bearing behaviors that a refactor
/// or a framework upgrade could silently break:
///
/// 1. Team/Search side slides follow the gesture, but capped at the first
///    20% of the exit animation (the page keeps at least 80% on screen);
///    a commit continues the slide from the release point instead of
///    rewinding to 1.0 and replaying the whole slide-out.
/// 2. The Dex container-transform route shows only the standard Material
///    preview during the drag (no interactive Hero flight, no premature
///    content fade).
/// 3. A Dex commit stops the gesture before popping so the Hero collapse
///    flies exactly once, exactly like the button back - the fix for the
///    v0.9.5 "return animation replays after release" bug.
void main() {
  testWidgets('side slide drag capped at 20%, commit plays the remainder', (
    tester,
  ) async {
    final router = _buildRouter();
    addTearDown(router.dispose);
    await _pumpApp(tester, router);
    await tester.tap(find.byKey(const ValueKey('push-team')));
    await tester.pumpAndSettle();
    final teamRoute = ModalRoute.of(
      tester.element(find.byKey(const ValueKey('team-content'))),
    )!;
    expect(teamRoute.popGestureEnabled, isTrue);
    final accepted = await _startGesture(tester);
    expect(accepted, isTrue);
    await tester.pump();
    // Drag: the directed slide follows the finger, but the visual cap keeps
    // it within the first 20% of the exit animation. A controller clamp
    // would not do - the emphasized curve is nearly flat near 1.0 - so the
    // controller value itself is the curve-inverse of the capped visual.
    await _updateGesture(tester, 0.5);
    await tester.pump();
    expect(teamRoute.popGestureInProgress, isTrue);
    // Half the gesture = 10% of the slide: the page has moved left but
    // still shows 90% of itself.
    expect(_slideOffset(tester), closeTo(-0.1, 0.005));
    // A full swipe still only plays 20% of the exit - the limiter.
    await _updateGesture(tester, 1.0);
    await tester.pump();
    expect(_slideOffset(tester), closeTo(-0.2, 0.005));
    // The controller itself is well short of fully slid out.
    expect(teamRoute.animation!.value, inExclusiveRange(0.0, 0.5));
    // Cancel: the slide springs back and the page stays.
    await _cancelGesture(tester);
    await tester.pumpAndSettle();
    expect(teamRoute.animation!.value, 1.0);
    expect(find.byKey(const ValueKey('team-content')), findsOneWidget);
    // Commit: no rewind to 1.0 - the remaining slide continues from the
    // capped release point (Team exits to the left).
    await _startGesture(tester);
    await _updateGesture(tester, 0.5);
    await tester.pump();
    final releaseValue = teamRoute.animation!.value;
    expect(releaseValue, inExclusiveRange(0.0, 1.0));
    await _commitGesture(tester);
    expect(teamRoute.animation!.value, releaseValue);
    expect(teamRoute.popGestureInProgress, isTrue);
    // First frame starts the continuation clock (still at the release
    // point - no rewind to 1.0), then the remaining slide plays.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(_slideOffset(tester), lessThan(-0.5));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('team-content')), findsNothing);
    expect(find.byKey(const ValueKey('push-team')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('side slide full-edge commit plays the remaining 80%', (
    tester,
  ) async {
    final router = _buildRouter();
    addTearDown(router.dispose);
    await _pumpApp(tester, router);
    await tester.tap(find.byKey(const ValueKey('push-team')));
    await tester.pumpAndSettle();
    final teamRoute = ModalRoute.of(
      tester.element(find.byKey(const ValueKey('team-content'))),
    )!;
    await _startGesture(tester);
    // Even at the far edge the cap keeps the page on screen, so the commit
    // cannot consume a fully-played animation: it must continue the slide
    // from the capped point instead of vanishing or rewinding.
    await _updateGesture(tester, 1.0);
    await tester.pump();
    expect(_slideOffset(tester), closeTo(-0.2, 0.005));
    expect(teamRoute.animation!.value, inExclusiveRange(0.0, 0.5));
    await _commitGesture(tester);
    // The commit continues - not restarts - the slide.
    expect(teamRoute.animation!.value, inExclusiveRange(0.0, 0.5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(_slideOffset(tester), lessThan(-0.4));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('team-content')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Dex drag previews standard, commit flies the hero collapse once',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final router = _buildRouter();
      addTearDown(router.dispose);
      await _pumpApp(tester, router);
      await tester.tap(find.byKey(const ValueKey('push-dex')));
      await tester.pumpAndSettle();
      final dexRoute = ModalRoute.of(
        tester.element(find.byKey(const ValueKey('dex-content'))),
      )!;
      expect(dexRoute.popGestureEnabled, isTrue);
      final accepted = await _startGesture(tester);
      expect(accepted, isTrue);
      await tester.pump();
      // DRAG: the page shell opted out of interactive gesture flights, so
      // only the standard Material preview runs. Reverting the Hero flag
      // would make the flight appear here.
      expect(
        find.byKey(const ValueKey('tito-dex-flight-surface')),
        findsNothing,
      );
      await _updateGesture(tester, 0.5);
      await tester.pump();
      expect(dexRoute.animation!.value, closeTo(0.5, 0.001));
      // The grid reveal holds fully visible during the preview;
      // a mid-drag fade would have to snap back when the commit rewinds
      // to 1.0.
      var reveal = tester.widget<FadeTransition>(
        find.byKey(const ValueKey('tito-dex-content-reveal')),
      );
      expect(reveal.opacity.value, 1.0);
      // CANCEL: the page springs back and the reveal never flickers.
      await _cancelGesture(tester);
      await tester.pumpAndSettle();
      expect(dexRoute.animation!.value, 1.0);
      expect(find.byKey(const ValueKey('dex-content')), findsOneWidget);
      reveal = tester.widget<FadeTransition>(
        find.byKey(const ValueKey('tito-dex-content-reveal')),
      );
      expect(reveal.opacity.value, 1.0);
      // COMMIT: stopping the gesture before the pop lets didChangeTop start
      // the Hero flight (the framework default keeps the gesture alive and
      // no flight would exist here), and the rewind to 1.0 plays the
      // complete container collapse as the post-release animation.
      await _startGesture(tester);
      await _updateGesture(tester, 0.5);
      await tester.pump();
      await _commitGesture(tester);
      // The commit rewinds the controller to the collapse start point
      // (see titoDexCollapseRewindFrom in tito_page_transition.dart).
      expect(
        dexRoute.animation!.value,
        closeTo(titoDexCollapseRewindFrom, 0.001),
      );
      expect(dexRoute.popGestureInProgress, isFalse);
      // First frame ends the pop and schedules the flight; the second builds
      // the flight overlay entry. It starts at the full-page rect...
      await tester.pump();
      await tester.pump();
      final flightFinder = find.byKey(
        const ValueKey('tito-dex-flight-surface'),
      );
      expect(flightFinder, findsOneWidget);
      final fullFlight = tester.getRect(flightFinder);
      // ...then the collapse shrinks it toward the home card.
      await tester.pump(const Duration(milliseconds: 60));
      final midFlight = tester.getRect(flightFinder);
      expect(midFlight.width, lessThan(fullFlight.width));
      expect(midFlight.width, greaterThan(80));
      // The reveal fades down continuously with the collapse (no snap back
      // in).
      reveal = tester.widget<FadeTransition>(
        find.byKey(const ValueKey('tito-dex-content-reveal')),
      );
      expect(reveal.opacity.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dex-content')), findsNothing);
      expect(find.byKey(const ValueKey('home-dex-card')), findsOneWidget);
      expect(flightFinder, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Dex full-edge commit still plays the hero collapse', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = _buildRouter();
    addTearDown(router.dispose);
    await _pumpApp(tester, router);
    await tester.tap(find.byKey(const ValueKey('push-dex')));
    await tester.pumpAndSettle();
    await _startGesture(tester);
    // The runway clamps the controller above zero, so the commit's rewind
    // branch runs and the page vanishing without any collapse (the pre-fix
    // full-edge symptom) cannot regress silently.
    await _updateGesture(tester, 1.0);
    await tester.pump();
    await _commitGesture(tester);
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('tito-dex-flight-surface')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dex-content')), findsNothing);
    expect(find.byKey(const ValueKey('home-dex-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return PopScope(
            canPop: TitoBackNavigation.canPopRoute(context, state.uri.path),
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) {
                return;
              }
              TitoBackNavigation.navigateBack(context, state.uri.path);
            },
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/',
            pageBuilder:
                (context, state) => titoHomePage<void>(
                  key: state.pageKey,
                  child: Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Mirrors home_page.dart's quick-action card: the home
                          // side keeps transitionOnUserGestures true, so the
                          // drag-time "no flight" assertion below is sensitive
                          // to exactly the dex-side Hero flag.
                          Hero(
                            tag: TitoHomeActionHero.dex,
                            transitionOnUserGestures: true,
                            createRectTween: titoDexRectTween,
                            curve: titoDexForwardCurve,
                            reverseCurve: titoDexReverseCurve,
                            child: const SizedBox(
                              key: ValueKey('home-dex-card'),
                              width: 80,
                              height: 80,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            key: const ValueKey('push-dex'),
                            onPressed:
                                () => context.push(
                                  '/dex',
                                  extra: TitoHomeActionHero.dex,
                                ),
                            child: const Text('dex'),
                          ),
                          FilledButton(
                            key: const ValueKey('push-team'),
                            onPressed: () => context.push('/team'),
                            child: const Text('team'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
          GoRoute(
            path: '/team',
            pageBuilder:
                (context, state) => titoSideSlidePage<void>(
                  key: state.pageKey,
                  direction: TitoSideSlideDirection.fromLeft,
                  child: const Scaffold(
                    body: Center(
                      child: Text('team', key: ValueKey('team-content')),
                    ),
                  ),
                ),
          ),
          GoRoute(
            path: '/dex',
            pageBuilder:
                (context, state) => titoDexPage<void>(
                  key: state.pageKey,
                  heroTag: TitoHomeActionHero.forRoute('/dex', state.extra),
                  child: const ColoredBox(
                    color: Colors.blueGrey,
                    child: SizedBox.expand(),
                  ),
                  content: const Scaffold(
                    body: Center(
                      child: Text('dex', key: ValueKey('dex-content')),
                    ),
                  ),
                ),
          ),
        ],
      ),
    ],
  );
}

Future<void> _pumpApp(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: buildTitoTheme()),
  );
  await tester.pumpAndSettle();
}

Future<Object?> _send(WidgetTester tester, MethodCall call) async {
  Object? reply;
  final message = const StandardMethodCodec().encodeMethodCall(call);
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (ByteData? data) {
      if (data != null) {
        reply = const StandardMethodCodec().decodeEnvelope(data);
      }
    },
  );
  return reply;
}

Future<Object?> _startGesture(WidgetTester tester) => _send(
  tester,
  const MethodCall('startBackGesture', <String, dynamic>{
    'touchOffset': <double>[5.0, 300.0],
    'progress': 0.0,
    'swipeEdge': 0,
  }),
);

Future<Object?> _updateGesture(WidgetTester tester, double progress) => _send(
  tester,
  MethodCall('updateBackGestureProgress', <String, dynamic>{
    'touchOffset': <double>[180.0, 300.0],
    'progress': progress,
    'swipeEdge': 0,
  }),
);

Future<Object?> _cancelGesture(WidgetTester tester) =>
    _send(tester, const MethodCall('cancelBackGesture'));

Future<Object?> _commitGesture(WidgetTester tester) =>
    _send(tester, const MethodCall('commitBackGesture'));

double _slideOffset(WidgetTester tester) =>
    tester
        .widget<SlideTransition>(
          find.byKey(const ValueKey('tito-side-slide-transition')),
        )
        .position
        .value
        .dx;
