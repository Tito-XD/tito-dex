import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/companion/companion_repository.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/navigation/tito_page_transition.dart';
import 'package:titodex/pages/home_page.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/motion_preferences.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/tito_entrance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await motionPreferences.setListAnimationsEnabled(true);
    await companionRepository.setEnabled(false);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/battery'),
      (call) async => call.method == 'getBatteryLevel' ? 82 : 'discharging',
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
    for (final name in [
      'dev.fluttercommunity.plus/charging',
      'dev.fluttercommunity.plus/connectivity_status',
    ]) {
      messenger.setMockStreamHandler(
        EventChannel(name),
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
    }
  });

  tearDown(() async {
    await motionPreferences.setListAnimationsEnabled(true);
    await companionRepository.setEnabled(true);
  });

  for (final style in AppVisualStyle.values) {
    testWidgets(
      '$style home staggers once across data, layout and back return',
      (tester) async {
        tester.view.physicalSize = const Size(480, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final revision = ValueNotifier(0);
        addTearDown(revision.dispose);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (_, state) => titoHomePage(
                key: state.pageKey,
                child: Scaffold(
                  body: ValueListenableBuilder<int>(
                    valueListenable: revision,
                    builder: (_, value, _) => HomePage(
                      journey: CurrentJourney.mock().copyWith(
                        playTime: '18:$value',
                      ),
                      bootstrapping: value == 0,
                      onJourneyOpen: () {},
                    ),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/team',
              builder: (_, _) => const Scaffold(body: Text('team page')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: buildTitoTheme(style),
            routerConfig: router,
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        // Bootstrap keeps a static trainer placeholder. It doesn't consume the
        // eventual real-content entrance.
        expect(_opacity(tester, 0), 1);
        revision.value = 1;
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 245));
        expect(_opacity(tester, 0), greaterThan(_opacity(tester, 3)));
        expect(_opacity(tester, 3), greaterThan(_opacity(tester, 4)));
        expect(_opacity(tester, 4), greaterThan(_opacity(tester, 5)));
        await tester.pump(const Duration(seconds: 1));
        _expectSettled(tester);
        revision.value = 2;
        await tester.pump();
        _expectSettled(tester);
        tester.view.physicalSize = const Size(390, 844);
        await tester.pump();
        _expectSettled(tester);
        router.push('/team');
        await tester.pumpAndSettle();
        router.pop();
        await tester.pump();
        await tester.pumpAndSettle();
        _expectSettled(tester);
        await tester.pump(const Duration(minutes: 1));
        _expectSettled(tester);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final system in [true, false]) {
    testWidgets(
      '${system ? 'system' : 'preference'} reduction settles entrance without replay',
      (tester) async {
        final disabled = ValueNotifier(false);
        addTearDown(disabled.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: disabled,
              builder: (_, value, _) => MediaQuery(
                data: MediaQueryData(disableAnimations: system && value),
                child: const TitoEntrance(
                  itemCount: 2,
                  child: Column(
                    children: [
                      TitoEntranceItem(index: 0, child: Text('first')),
                      TitoEntranceItem(index: 1, child: Text('second')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(_opacity(tester, 0), inExclusiveRange(0, 1));
        if (system) {
          disabled.value = true;
        } else {
          await motionPreferences.setListAnimationsEnabled(false);
        }
        await tester.pump();
        _expectSettled(tester);
        disabled.value = false;
        await motionPreferences.setListAnimationsEnabled(true);
        await tester.pump();
        _expectSettled(tester);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'disabled first frame is visible and disposal while waiting is safe',
    (tester) async {
      await motionPreferences.setListAnimationsEnabled(false);
      await tester.pumpWidget(
        const MaterialApp(
          home: TitoEntrance(
            itemCount: 1,
            child: TitoEntranceItem(index: 0, child: Text('visible')),
          ),
        ),
      );
      _expectSettled(tester);
      await tester.pumpWidget(const SizedBox());
      await motionPreferences.setListAnimationsEnabled(true);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: nav, home: const SizedBox()),
      );
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const TitoEntrance(
            itemCount: 1,
            child: TitoEntranceItem(index: 0, child: Text('waiting')),
          ),
        ),
      );
      await tester.pump();
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}

Finder _item(int index) =>
    find.byWidgetPredicate((w) => w is TitoEntranceItem && w.index == index);
double _opacity(WidgetTester tester, int index) => tester
    .widget<Opacity>(
      find.descendant(of: _item(index), matching: find.byType(Opacity)).first,
    )
    .opacity;
void _expectSettled(WidgetTester tester) {
  for (final item in tester.widgetList<TitoEntranceItem>(
    find.byType(TitoEntranceItem),
  )) {
    expect(_opacity(tester, item.index), 1);
    final transforms = tester.widgetList<Transform>(
      find.descendant(of: _item(item.index), matching: find.byType(Transform)),
    );
    expect(transforms.first.transform.getTranslation().y, 0);
    expect(transforms.elementAt(1).transform.storage[0], 1);
  }
}
