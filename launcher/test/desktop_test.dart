import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex_launcher/main.dart';
import 'package:titodex_launcher/models.dart';
import 'package:titodex_launcher/home_page.dart';
import 'package:titodex_launcher/appearance.dart';

void main() {
  test(
    'upgrade preserves identity and wallpapers while installing configurable modules',
    () {
      final s = LauncherSettings.decode(
        '{"name":"Tito","photo":"/chosen.jpg","wallpaper":"photo","favorites":["a/A","b/B"]}',
      );
      expect(s.name, 'Tito');
      expect(s.photo, '/chosen.jpg');
      expect(s.favorites.toList(), ['a/A', 'b/B']);
      expect(s.modules.where((m) => m.visible).length, 3);
      s.moveFavorite('b/B', -1);
      s.recordLaunch('a/A');
      s.recordLaunch('b/B');
      s.recordLaunch('a/A');
      s.applyLayout(HomeLayout.quiet);
      s.modules.first.wide = true;
      final restored = LauncherSettings.decode(s.encode());
      expect(restored.favorites.toList(), ['b/B', 'a/A']);
      expect(restored.recent, ['a/A', 'b/B']);
      expect(restored.layout, HomeLayout.quiet);
      expect(restored.modules.first.wide, isTrue);
      expect(restored.photo, '/chosen.jpg');
    },
  );
  test('malformed layouts cannot remove TitoDex or create duplicate modules', () {
    final s = LauncherSettings.decode(
      '{"modules":[{"id":"titodex","visible":false},{"id":"titodex"},{"id":"missing"}],"opacity":0,"libraryColumns":100}',
    );
    expect(s.modules.map((m) => m.module).toSet().length, 4);
    expect(
      s.modules.singleWhere((m) => m.module == HomeModule.titodex).visible,
      isTrue,
    );
    expect(s.opacity, .7);
    expect(s.libraryColumns, 6);
  });
  for (final size in [
    const Size(360, 360),
    const Size(480, 480),
    const Size(800, 450),
  ]) {
    for (final layout in HomeLayout.values) {
      testWidgets('modules and dock remain reachable in $layout at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = LauncherSettings()..applyLayout(layout);
        final focus = FocusNode();
        addTearDown(focus.dispose);
        var opened = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: launcherTheme(s.style),
            home: Scaffold(
              body: HomePage(
                settings: s,
                apps: [],
                now: DateTime(2026, 10, 15, 22),
                titoFocus: focus,
                onTito: () {
                  opened++;
                },
                onLibrary: () {},
                onSearch: () {},
                onSettings: () {},
                onCustomize: () {},
                onApp: (_) {},
                onAppOptions: (_) {},
                onWeather: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('应用库').hitTestable(), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('launch-titodex')),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
        await tester.pump();
        expect(opened, 1);
        if (size.width == 480 && layout == HomeLayout.roam) {
          expect(
            tester.getSize(find.byKey(const ValueKey('module-titodex'))).width,
            lessThan(230),
          );
          expect(
            tester
                .getSize(find.byKey(const ValueKey('wallpaper-window')))
                .height,
            greaterThan(40),
          );
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets(
    'layout editor changes persist, hiding and width affect the actual home',
    (tester) async {
      tester.view.physicalSize = const Size(480, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? saved;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.tito.titodex.launcher/device'),
            (call) async {
              if (call.method == 'writeSettings') {
                saved = call.arguments['json'] as String;
                return null;
              }
              return switch (call.method) {
                'readSettings' => saved,
                'apps' => [],
                'status' => {'battery': 80, 'online': false},
                _ => true,
              };
            },
          );
      await tester.pumpWidget(const LauncherApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('编排'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('留白'));
      await tester.pumpAndSettle();
      expect(LauncherSettings.decode(saved).layout, HomeLayout.quiet);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('module-favorites')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const LauncherApp());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('module-favorites')), findsNothing);
      expect(find.byKey(const ValueKey('launch-titodex')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
