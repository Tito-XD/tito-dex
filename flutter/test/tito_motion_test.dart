import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/dex/dex_browse_scope.dart';
import 'package:titodex/features/dex/dex_filter.dart';
import 'package:titodex/features/dex/dex_game_scope.dart';
import 'package:titodex/features/dex/dex_regional_picker.dart';
import 'package:titodex/features/journey/ask_titodex_settings.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/search_page.dart';
import 'package:titodex/theme/motion_preferences.dart';
import 'package:titodex/theme/tito_colors.dart';
import 'package:titodex/widgets/dex_species_filter_sheet.dart';
import 'package:titodex/widgets/tito_animated_size_switcher.dart';
import 'package:titodex/widgets/tito_list_reveal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await motionPreferences.setListAnimationsEnabled(true);
  });

  testWidgets(
    'keyed switcher animates height and follows numeric-key direction',
    (tester) async {
      final selected = ValueNotifier<int>(0);
      addTearDown(selected.dispose);

      await tester.pumpWidget(
        _motionHost(
          ValueListenableBuilder<int>(
            valueListenable: selected,
            builder: (context, value, _) => Center(
              child: SizedBox(
                width: 220,
                child: TitoAnimatedSizeSwitcher(
                  switchKey: ValueKey<int>(value),
                  child: SizedBox(
                    height: value == 0 ? 40 : 100,
                    child: Text('panel-$value'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(TitoAnimatedSizeSwitcher)).height, 40);

      selected.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final enteringForward = tester.widget<Transform>(
        find.byKey(const ValueKey<Key?>(ValueKey<int>(1))),
      );
      final forwardDx = enteringForward.transform.getTranslation().x;
      final middleHeight = tester
          .getSize(find.byType(TitoAnimatedSizeSwitcher))
          .height;
      expect(forwardDx, greaterThan(0));
      expect(forwardDx, lessThan(8));
      expect(middleHeight, greaterThan(40));
      expect(middleHeight, lessThan(100));

      await tester.pumpAndSettle();
      selected.value = 0;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final enteringBack = tester.widget<Transform>(
        find.byKey(const ValueKey<Key?>(ValueKey<int>(0))),
      );
      expect(enteringBack.transform.getTranslation().x, lessThan(0));
    },
  );

  testWidgets('keyed switcher becomes an immediate swap for reduced motion', (
    tester,
  ) async {
    final selected = ValueNotifier<int>(0);
    addTearDown(selected.dispose);

    await tester.pumpWidget(
      _motionHost(
        ValueListenableBuilder<int>(
          valueListenable: selected,
          builder: (context, value, _) => TitoAnimatedSizeSwitcher(
            switchKey: ValueKey<int>(value),
            child: Text('panel-$value'),
          ),
        ),
        disableAnimations: true,
      ),
    );

    selected.value = 1;
    await tester.pump();
    expect(find.text('panel-1'), findsOneWidget);
    expect(find.text('panel-0'), findsNothing);
    expect(find.byType(AnimatedSwitcher), findsNothing);
  });

  testWidgets('keyed switcher reacts to the UI-animation preference', (
    tester,
  ) async {
    final selected = ValueNotifier<int>(0);
    addTearDown(selected.dispose);

    await tester.pumpWidget(
      _motionHost(
        ValueListenableBuilder<int>(
          valueListenable: selected,
          builder: (context, value, _) => TitoAnimatedSizeSwitcher(
            switchKey: ValueKey<int>(value),
            child: Text('preference-panel-$value'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await motionPreferences.setListAnimationsEnabled(false);
    await tester.pump();
    selected.value = 1;
    await tester.pump();

    expect(find.text('preference-panel-1'), findsOneWidget);
    expect(find.text('preference-panel-0'), findsNothing);
    expect(find.byType(AnimatedSwitcher), findsNothing);
  });

  testWidgets('list reveal is visible on the first disabled-motion frame', (
    tester,
  ) async {
    await motionPreferences.setListAnimationsEnabled(false);
    await tester.pumpWidget(
      _motionHost(
        const TitoListReveal(
          key: ValueKey<String>('preference-disabled-row'),
          child: Text('preference-disabled'),
        ),
      ),
    );
    expect(_opacityAbove(tester, 'preference-disabled'), 1);

    await motionPreferences.setListAnimationsEnabled(true);
    await tester.pumpWidget(
      _motionHost(
        const TitoListReveal(
          key: ValueKey<String>('system-disabled-row'),
          child: Text('system-disabled'),
        ),
        disableAnimations: true,
      ),
    );
    expect(_opacityAbove(tester, 'system-disabled'), 1);
  });

  testWidgets(
    'list reveal reacts to preference and remembers lazily rebuilt rows',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _motionHost(
          SizedBox(
            height: 120,
            child: ListView.builder(
              controller: controller,
              itemExtent: 56,
              itemCount: 40,
              itemBuilder: (context, index) => TitoListReveal(
                key: ValueKey<String>('remembered-row-$index'),
                child: Text('row-$index'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(_opacityAbove(tester, 'row-0'), inExclusiveRange(0, 1));

      await motionPreferences.setListAnimationsEnabled(false);
      await tester.pump();
      expect(_opacityAbove(tester, 'row-0'), 1);

      await motionPreferences.setListAnimationsEnabled(true);
      controller.jumpTo(1000);
      await tester.pump();
      expect(find.text('row-0'), findsNothing);
      controller.jumpTo(0);
      await tester.pump();
      expect(_opacityAbove(tester, 'row-0'), 1);
    },
  );

  testWidgets('a genuinely re-keyed list result gets a fresh reveal', (
    tester,
  ) async {
    final generation = ValueNotifier<int>(0);
    addTearDown(generation.dispose);

    await tester.pumpWidget(
      _motionHost(
        ValueListenableBuilder<int>(
          valueListenable: generation,
          builder: (context, value, _) => TitoListReveal(
            key: ValueKey<String>('result-generation-$value'),
            replayKey: value,
            child: Text('generation-$value'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    generation.value = 1;
    await tester.pump();
    expect(_opacityAbove(tester, 'generation-1'), 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(_opacityAbove(tester, 'generation-1'), inExclusiveRange(0, 1));
  });

  testWidgets('Search segment and body expose a real intermediate frame', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(
          path: '/search',
          builder: (context, state) => Scaffold(
            body: SearchPage(
              journey: CurrentJourney.mock(),
              assistantDisplayMode: SearchAssistantDisplayMode.hidden,
            ),
          ),
        ),
        GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppZh.searchHubReference));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final selectedSegment = tester.widget<Transform>(
      find.byKey(const ValueKey<String>('search-segment-motion-1')),
    );
    final selectedDy = selectedSegment.transform.getTranslation().y;
    expect(selectedDy, lessThan(0));
    expect(selectedDy, greaterThan(-1));

    final enteringBody = tester.widget<Transform>(
      find.byKey(const ValueKey<Key?>(ValueKey<int>(1))),
    );
    expect(enteringBody.transform.getTranslation().x, greaterThan(0));
    expect(find.text(AppZh.searchPrompt), findsOneWidget);
    expect(find.text(AppZh.searchHubDataTitle), findsOneWidget);
  });

  testWidgets('species filter chips animate color and transform selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      _motionHost(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () =>
                showDexSpeciesFilterSheet(context, selected: DexFilter.empty),
            child: const Text('open-filter'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-filter'));
    await tester.pumpAndSettle();

    final chip = find.byKey(const ValueKey<String>('dex-shape-motion-ball'));
    await tester.tap(chip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));

    final transform = tester.widget<Transform>(chip);
    final dy = transform.transform.getTranslation().y;
    expect(dy, lessThan(0));
    expect(dy, greaterThan(-1.5));

    final ink = tester.widget<Ink>(
      find.descendant(of: chip, matching: find.byType(Ink)).first,
    );
    final color = (ink.decoration! as BoxDecoration).color;
    expect(color, isNot(TitoColors.card));
    expect(color, isNot(TitoColors.softYellow));
  });

  testWidgets('regional picker body moves forward and back by level', (
    tester,
  ) async {
    await tester.pumpWidget(
      _motionHost(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDexBrowseScopePicker(
              context,
              selected: const DexBrowseScope.region(
                DexRegionalPokedex.national,
              ),
            ),
            child: const Text('open-region'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-region'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppZh.dexBrowseByRegion));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final forward = tester.widgetList<Transform>(
      find.byKey(const ValueKey<Key?>(ValueKey<int>(1))),
    );
    expect(
      forward.any((entry) => entry.transform.getTranslation().x > 0),
      isTrue,
    );
    expect(find.text(AppZh.dexPickBrowseScope), findsOneWidget);
    expect(find.text('全国图鉴'), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final back = tester.widgetList<Transform>(
      find.byKey(const ValueKey<Key?>(ValueKey<int>(0))),
    );
    expect(back.any((entry) => entry.transform.getTranslation().x < 0), isTrue);
  });
}

Widget _motionHost(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 780),
        disableAnimations: disableAnimations,
      ),
      child: Scaffold(body: child),
    ),
  );
}

double _opacityAbove(WidgetTester tester, String text) {
  final finder = find.ancestor(
    of: find.text(text),
    matching: find.byType(Opacity),
  );
  return tester.widget<Opacity>(finder.first).opacity;
}
