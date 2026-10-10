import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/companion/companion_repository.dart';
import 'package:titodex/features/game/game_edition_repository.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/home_page.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/motion_preferences.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/handheld_input.dart';
import 'package:titodex/widgets/app_header.dart';
import 'package:titodex/widgets/journey_card.dart';
import 'package:titodex/widgets/device_shell.dart';
import 'package:titodex/widgets/tito_page_container.dart';
import 'package:titodex/widgets/handheld_focus_geometry.dart';

FocusNode nodeFor(Finder control, WidgetTester tester) => Focus.of(
  tester.element(
    find.descendant(of: control, matching: find.byType(HandheldPressed)),
  ),
);
HandheldFocusCuePainter cue(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('handheld-focus-cue')),
            )
            .painter!
        as HandheldFocusCuePainter;

Future<void> key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Widget tile(
  String label,
  VoidCallback? action, {
  double width = 80,
  double height = 48,
}) => HandheldFocusDecorator(
  key: ValueKey(label),
  onActivate: action,
  child: SizedBox(
    width: width,
    height: height,
    child: Material(
      color: Colors.blue,
      child: InkWell(
        onTap: action,
        child: Center(child: Text(label)),
      ),
    ),
  ),
);

Widget host(Widget child, {bool reduced = false}) => MaterialApp(
  builder: (context, navigator) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: HandheldInputShell(child: navigator!),
  ),
  home: Scaffold(body: child),
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await motionPreferences.setListAnimationsEnabled(true);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() async {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
    await motionPreferences.setListAnimationsEnabled(true);
  });

  testWidgets('one visible control has one traversal stop and one activation', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(
      host(
        Column(
          children: [
            tile('first', () => activations++),
            tile('second', () => activations += 10),
          ],
        ),
      ),
    );
    await key(tester, LogicalKeyboardKey.tab);
    expect(
      nodeFor(find.byKey(const ValueKey('first')), tester).hasPrimaryFocus,
      isTrue,
    );
    await key(tester, LogicalKeyboardKey.tab);
    expect(
      nodeFor(find.byKey(const ValueKey('second')), tester).hasPrimaryFocus,
      isTrue,
    );
    await key(tester, LogicalKeyboardKey.gameButtonA);
    expect(activations, 10);
    expect(
      cue(tester).bounds,
      tester.getRect(find.byKey(const ValueKey('second'))),
    );
  });

  testWidgets(
    'disabled, offstage and transparent controls cannot steal D-pad focus',
    (tester) async {
      var activated = '';
      await tester.pumpWidget(
        host(
          Column(
            children: [
              tile('start', () => activated = 'start'),
              tile('disabled', null),
              IgnorePointer(
                child: tile('blocked', () => activated = 'blocked'),
              ),
              Offstage(child: tile('offstage', () => activated = 'offstage')),
              Opacity(
                opacity: 0,
                child: tile('transparent', () => activated = 'transparent'),
              ),
              tile('end', () => activated = 'end'),
            ],
          ),
        ),
      );
      nodeFor(find.byKey(const ValueKey('start')), tester).requestFocus();
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.gameButtonA);
      expect(activated, 'end');
      expect(
        cue(tester).bounds,
        tester.getRect(find.byKey(const ValueKey('end'))),
      );
    },
  );

  testWidgets('irregular rows use visual columns and clamp at the edge', (
    tester,
  ) async {
    var activated = '';
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 300,
          height: 240,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: tile(
                  'upper-left',
                  () => activated = 'upper-left',
                  width: 160,
                  height: 90,
                ),
              ),
              Positioned(
                left: 180,
                top: 0,
                child: tile('upper-right', () => activated = 'upper-right'),
              ),
              Positioned(
                left: 0,
                top: 120,
                child: tile('lower-left', () => activated = 'lower-left'),
              ),
              Positioned(
                left: 180,
                top: 120,
                child: tile('lower-right', () => activated = 'lower-right'),
              ),
            ],
          ),
        ),
      ),
    );
    nodeFor(find.byKey(const ValueKey('upper-right')), tester).requestFocus();
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(
      nodeFor(
        find.byKey(const ValueKey('lower-right')),
        tester,
      ).hasPrimaryFocus,
      isTrue,
    );
    await key(tester, LogicalKeyboardKey.arrowRight);
    await key(tester, LogicalKeyboardKey.gameButtonA);
    expect(activated, 'lower-right');
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(
      nodeFor(find.byKey(const ValueKey('lower-left')), tester).hasPrimaryFocus,
      isTrue,
    );
  });

  testWidgets('layout changes discard stale directional history', (
    tester,
  ) async {
    var moved = false;
    late StateSetter rearrange;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            rearrange = setState;
            return SizedBox(
              width: 300,
              height: 200,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: moved ? 120 : 0,
                    child: tile('a', () {}),
                  ),
                  Positioned(
                    left: 0,
                    top: moved ? 0 : 120,
                    child: tile('b', () {}),
                  ),
                  Positioned(left: 150, top: 0, child: tile('c', () {})),
                ],
              ),
            );
          },
        ),
      ),
    );
    nodeFor(find.byKey(const ValueKey('a')), tester).requestFocus();
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.arrowDown);
    rearrange(() => moved = true);
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.arrowUp);
    // B is now at the top; up must stay on B instead of returning to old A.
    expect(
      nodeFor(find.byKey(const ValueKey('b')), tester).hasPrimaryFocus,
      isTrue,
    );
    expect(cue(tester).bounds, tester.getRect(find.byKey(const ValueKey('b'))));
  });

  testWidgets(
    'scrolling follows the actual control and reveals cached targets',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        host(
          SizedBox(
            height: 130,
            child: ListView(
              controller: scroll,
              children: [for (var i = 0; i < 8; i++) tile('item$i', () {})],
            ),
          ),
        ),
      );
      nodeFor(find.byKey(const ValueKey('item0')), tester).requestFocus();
      await tester.pumpAndSettle();
      for (var i = 1; i < 6; i++) {
        await key(tester, LogicalKeyboardKey.arrowDown);
        expect(
          nodeFor(find.byKey(ValueKey('item$i')), tester).hasPrimaryFocus,
          isTrue,
        );
        final geometry = HandheldFocusGeometry.of(
          FocusManager.instance.primaryFocus!,
        )!;
        expect(geometry.isVisible, isTrue);
        expect(cue(tester).bounds, geometry.bounds);
      }
      expect(scroll.offset, greaterThan(0));
      scroll.jumpTo(scroll.offset - 15);
      await tester.pumpAndSettle();
      expect(
        cue(tester).bounds,
        HandheldFocusGeometry.of(FocusManager.instance.primaryFocus!)!.bounds,
      );
    },
  );

  testWidgets('arrival pulse ends and reduced motion keeps a stable outline', (
    tester,
  ) async {
    await tester.pumpWidget(host(tile('target', () {})));
    nodeFor(find.byKey(const ValueKey('target')), tester).requestFocus();
    await tester.pump();
    await tester.pump();
    expect(cue(tester).pulse, lessThan(1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(cue(tester).pulse, 1);
    expect(cue(tester).bounds, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(host(tile('target', () {}), reduced: true));
    nodeFor(find.byKey(const ValueKey('target')), tester).requestFocus();
    await tester.pumpAndSettle();
    expect(cue(tester).pulse, 1);
    expect(cue(tester).bounds, isNotNull);
  });

  testWidgets(
    'holding activation does not fire twice or leave pressed state behind',
    (tester) async {
      var count = 0;
      await tester.pumpWidget(host(tile('target', () => count++)));
      nodeFor(find.byKey(const ValueKey('target')), tester).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(count, 1);
    },
  );

  testWidgets('modal focus cannot move back into the covered home', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => tile(
            'open',
            () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                actions: [
                  TextButton(
                    autofocus: true,
                    onPressed: () {},
                    child: const Text('dialog-first'),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('dialog-second'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    nodeFor(find.byKey(const ValueKey('open')), tester).requestFocus();
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.gameButtonA);
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(
      ModalRoute.of(FocusManager.instance.primaryFocus!.context!),
      isA<PopupRoute>(),
    );
    await key(tester, LogicalKeyboardKey.gameButtonB);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      tester.widget<HandheldPressed>(find.byType(HandheldPressed)).pressed,
      isFalse,
    );
  });

  testWidgets(
    'keyboard reveals the cue and touch clears it without an idle ticker',
    (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
      await tester.pumpWidget(
        host(Column(children: [tile('a', () {}), tile('b', () {})])),
      );
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(cue(tester).bounds, isNotNull);
      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();
      expect(cue(tester).bounds, isNull);
    },
  );

  testWidgets('hidden focused controls cannot be activated', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      host(Opacity(opacity: 0, child: tile('hidden', () => count++))),
    );
    nodeFor(find.byKey(const ValueKey('hidden')), tester).requestFocus();
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.gameButtonA);
    expect(count, 0);
    expect(cue(tester).bounds, isNull);
  });

  for (final style in AppVisualStyle.values) {
    for (final size in [
      const Size(360, 360),
      const Size(640, 480),
      const Size(390, 844),
    ]) {
      testWidgets(
        '$style real Home D-pad follows visible quick actions at $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await appVisualStyle.setStyle(style);
          await companionRepository.setEnabled(false);
          await gameEditionRepository.saveSlug('hgss');
          var gameOpened = 0;
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => TitoPageContainer(
                  child: HomePage(
                    journey: const CurrentJourney(
                      game: 'SoulSilver',
                      trainerName: 'Tito',
                      location: '满金市',
                      badges: 3,
                      maxBadges: 8,
                      playTime: '1:00',
                      party: [],
                      timeline: [],
                      companion: '',
                    ),
                    onJourneyOpen: () => context.push('/journey'),
                    onGameBadgeTap: (_) => gameOpened++,
                  ),
                ),
              ),
              for (final path in [
                '/team',
                '/dex',
                '/search',
                '/settings',
                '/journey',
              ])
                GoRoute(
                  path: path,
                  builder: (context, state) => Scaffold(body: Text(path)),
                ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              theme: buildTitoTheme(style),
              routerConfig: router,
              builder: (context, child) => HandheldInputShell(
                child: DeviceShell(child: child!),
                onBack: () => router.pop(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Finder control(String label) => find.ancestor(
            of: find.text(label),
            matching: find.byType(HandheldFocusDecorator),
          );
          final team = control(AppZh.navTeam),
              dex = control(AppZh.navDex),
              search = control(AppZh.navSearch);
          expect(team, findsOneWidget);
          expect(dex, findsOneWidget);
          expect(search, findsOneWidget);
          // Read-only Trainer/Party cards and disabled cells are not stops.
          final nodes = FocusManager
              .instance
              .primaryFocus!
              .nearestScope!
              .traversalDescendants
              .where(
                (node) => HandheldFocusGeometry.of(node)?.isVisible ?? false,
              )
              .toList();
          expect(nodes.length, 6);
          nodeFor(team, tester).requestFocus();
          await tester.pumpAndSettle();
          await key(tester, LogicalKeyboardKey.arrowRight);
          expect(nodeFor(dex, tester).hasPrimaryFocus, isTrue);
          expect(cue(tester).bounds, tester.getRect(dex));
          await key(tester, LogicalKeyboardKey.arrowRight);
          expect(nodeFor(search, tester).hasPrimaryFocus, isTrue);
          await key(tester, LogicalKeyboardKey.arrowRight);
          expect(nodeFor(search, tester).hasPrimaryFocus, isTrue);
          await tester.sendKeyDownEvent(LogicalKeyboardKey.gameButtonA);
          await tester.pumpAndSettle();
          expect(find.text('/search'), findsOneWidget);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.gameButtonA);
          await tester.pumpAndSettle();
          router.pop();
          await tester.pumpAndSettle();
          expect(nodeFor(search, tester).hasPrimaryFocus, isTrue);
          expect(
            tester
                .widget<HandheldPressed>(
                  find.descendant(
                    of: search,
                    matching: find.byType(HandheldPressed),
                  ),
                )
                .pressed,
            isFalse,
          );
          expect(gameOpened, 0);
          if (size == const Size(360, 360)) {
            final settings = find.ancestor(
              of: find.byIcon(Icons.settings_rounded),
              matching: find.byType(HandheldFocusDecorator),
            );
            final game = find
                .descendant(
                  of: find.byType(AppHeader),
                  matching: find.byType(HandheldFocusDecorator),
                )
                .first;
            final journey = find.descendant(
              of: find.byType(JourneyCard),
              matching: find.byType(HandheldFocusDecorator),
            );
            await key(tester, LogicalKeyboardKey.arrowUp);
            expect(nodeFor(settings, tester).hasPrimaryFocus, isTrue);
            await key(tester, LogicalKeyboardKey.gameButtonA);
            expect(find.text('/settings'), findsOneWidget);
            router.pop();
            await tester.pumpAndSettle();
            await key(tester, LogicalKeyboardKey.arrowLeft);
            expect(nodeFor(game, tester).hasPrimaryFocus, isTrue);
            await key(tester, LogicalKeyboardKey.gameButtonA);
            expect(gameOpened, 1);
            final row = [team, dex, search];
            final gameX = tester.getRect(game).center.dx;
            final closest = row.reduce(
              (a, b) =>
                  (tester.getRect(a).center.dx - gameX).abs() <
                      (tester.getRect(b).center.dx - gameX).abs()
                  ? a
                  : b,
            );
            await key(tester, LogicalKeyboardKey.arrowDown);
            expect(nodeFor(closest, tester).hasPrimaryFocus, isTrue);
            for (var i = row.indexOf(closest); i > 0; i--) {
              await key(tester, LogicalKeyboardKey.arrowLeft);
              expect(nodeFor(row[i - 1], tester).hasPrimaryFocus, isTrue);
            }
            expect(nodeFor(team, tester).hasPrimaryFocus, isTrue);
            await key(tester, LogicalKeyboardKey.gameButtonA);
            expect(find.text('/team'), findsOneWidget);
            router.pop();
            await tester.pumpAndSettle();
            await key(tester, LogicalKeyboardKey.arrowRight);
            expect(nodeFor(dex, tester).hasPrimaryFocus, isTrue);
            await key(tester, LogicalKeyboardKey.gameButtonA);
            expect(find.text('/dex'), findsOneWidget);
            router.pop();
            await tester.pumpAndSettle();
            await key(tester, LogicalKeyboardKey.arrowLeft);
            expect(nodeFor(team, tester).hasPrimaryFocus, isTrue);
            await key(tester, LogicalKeyboardKey.arrowUp);
            expect(nodeFor(journey, tester).hasPrimaryFocus, isTrue);
            expect(cue(tester).bounds, tester.getRect(journey));
            await key(tester, LogicalKeyboardKey.gameButtonA);
            expect(find.text('/journey'), findsOneWidget);
            router.pop();
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
