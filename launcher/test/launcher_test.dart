import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex_launcher/main.dart';
import 'package:titodex_launcher/models.dart';
import 'package:titodex_launcher/weather.dart';

void main() {
  test(
    'settings survive restart and recover invalid or missing wallpaper state',
    () {
      final s = LauncherSettings()
        ..style = LauncherStyle.plastic
        ..name = 'Tito'
        ..wallpaper = Wallpaper.photo
        ..photo = '/private/image.jpg'
        ..city = const WeatherCity('上海', 31.2, 121.4)
        ..favorites.add('game/activity');
      final restored = LauncherSettings.decode(s.encode());
      expect(restored.style, LauncherStyle.plastic);
      expect(restored.name, 'Tito');
      expect(restored.city!.latitude, 31.2);
      expect(restored.favorites, {'game/activity'});
      restored.resetWallpaper();
      expect(restored.wallpaper, Wallpaper.none);
      expect(restored.effect, WallpaperEffect.clear);
      expect(restored.photo, isNull);
      expect(restored.name, 'Tito');
      expect(LauncherSettings.decode('{').style, LauncherStyle.journal);
      expect(
        LauncherSettings.decode(
          '{"wallpaper":"photo","style":"future"}',
        ).wallpaper,
        Wallpaper.none,
      );
      expect(WeatherCity.parse({'name': 'bad', 'lat': 999, 'lon': 0}), isNull);
    },
  );
  test(
    'app library filters component entries, searches packages, and puts favorites first',
    () {
      final a = LaunchApp('retro.a', 'Game', '模拟器', Uint8List(0));
      final b = LaunchApp('com.tito.titodex', 'Main', 'TitoDex', Uint8List(0));
      expect(filterApps([a, b], 'COM.TITO', {}, false), [b]);
      expect(filterApps([a, b], '', {a.id}, false).first, a);
      expect(filterApps([a, b], '', {b.id}, true), [b]);
      expect(filterApps([a, b], 'missing', {}, false), isEmpty);
      expect(filterApps([a, b], '', {b.id, a.id}, true), [b, a]);
    },
  );
  test(
    'clock uses device date, noon/midnight and weather codes stay explicit',
    () {
      expect(clockLabel(DateTime(2026, 10, 15, 0, 5), false), '12:05');
      expect(clockLabel(DateTime(2026, 10, 15, 13, 5), false), '01:05');
      expect(dateLabel(DateTime(2026, 10, 15)), '10月15日 · 星期四');
      expect(weatherDescription(95), '雷雨');
      expect(weatherDescription(800), '天气未知');
    },
  );
  for (final size in [
    const Size(480, 480),
    const Size(360, 360),
    const Size(800, 450),
  ]) {
    testWidgets('home, library, settings and D-pad work at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.tito.titodex.launcher/device'),
            (call) async {
              calls.add(call);
              return switch (call.method) {
                'readSettings' => null,
                'status' => {
                  'battery': 80,
                  'online': true,
                  'defaultHome': false,
                },
                'apps' => [
                  {
                    'package': titoDexPackage,
                    'activity': 'Main',
                    'label': 'TitoDex',
                    'icon': Uint8List(0),
                  },
                  {
                    'package': 'org.game',
                    'activity': 'Play',
                    'label': '掌机游戏',
                    'icon': Uint8List(0),
                  },
                ],
                'launch' => true,
                'writeSettings' => null,
                _ => false,
              };
            },
          );
      await tester.pumpWidget(const LauncherApp());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('launch-titodex')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
      await tester.pump();
      expect(calls.where((c) => c.method == 'launch').length, 1);
      await tester.ensureVisible(find.byKey(const ValueKey('launch-titodex')));
      await tester.tap(find.byKey(const ValueKey('launch-titodex')));
      await tester.pump();
      expect(
        calls.lastWhere((c) => c.method == 'launch').arguments['package'],
        titoDexPackage,
      );
      await tester.ensureVisible(find.text('应用库'));
      await tester.tap(find.text('应用库'));
      await tester.pumpAndSettle();
      expect(find.text('掌机游戏'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'absent');
      await tester.pumpAndSettle();
      expect(find.text('没有匹配的应用'), findsOneWidget);
      await tester.tap(find.byTooltip('回到桌面'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('设置'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('设为默认桌面'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('设为默认桌面'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('扁平贴纸'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('扁平贴纸'));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'writeSettings'), isNotEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
