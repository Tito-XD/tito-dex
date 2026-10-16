import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex_launcher/main.dart';
import 'package:titodex_launcher/models.dart';

void main() {
  for (final scale in [1.0, 1.5]) {
    testWidgets(
      'small-screen X menu, favorites and module editing at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 360);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        String? saved;
        final initial = LauncherSettings()..favorites.add('org.game/Play');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.tito.titodex.launcher/device'),
              (call) async {
                if (call.method == 'writeSettings') {
                  saved = call.arguments['json'] as String;
                  return null;
                }
                return switch (call.method) {
                  'readSettings' => saved ?? initial.encode(),
                  'status' => {'battery': 70, 'online': false},
                  'apps' => [
                    {
                      'package': 'org.game',
                      'activity': 'Play',
                      'label': '掌机游戏',
                      'icon': Uint8List(0),
                    },
                    {
                      'package': 'org.other',
                      'activity': 'Play',
                      'label': '另一个游戏',
                      'icon': Uint8List(0),
                    },
                  ],
                  _ => true,
                };
              },
            );
        await tester.pumpWidget(const LauncherApp());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('应用库'));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonX);
        await tester.pumpAndSettle();
        expect(find.text('取消收藏'), findsOneWidget);
        await tester.ensureVisible(find.text('应用信息'));
        await tester.pumpAndSettle();
        expect(find.text('应用信息').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('取消收藏'));
        await tester.tap(find.text('取消收藏'));
        await tester.pumpAndSettle();
        expect(LauncherSettings.decode(saved).favorites, isEmpty);
        await tester.longPress(
          find.byKey(const ValueKey('app-org.other/Play')),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('收藏到桌面'));
        await tester.tap(find.text('收藏到桌面'));
        await tester.pumpAndSettle();
        expect(LauncherSettings.decode(saved).favorites, {'org.other/Play'});
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'org.other');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('app-org.other/Play')),
          findsOneWidget,
        );
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('回到桌面'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('编排'));
        await tester.pumpAndSettle();
        final wide = find.byKey(const ValueKey('wide-trainer'));
        await tester.ensureVisible(wide);
        await tester.pumpAndSettle();
        await tester.tap(wide);
        await tester.pumpAndSettle();
        expect(LauncherSettings.decode(saved).modules.first.wide, isTrue);
        final hide = find.byKey(const ValueKey('visible-trainer'));
        await Scrollable.ensureVisible(tester.element(hide), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(hide);
        await tester.pumpAndSettle();
        expect(LauncherSettings.decode(saved).modules.first.visible, isFalse);
        final down = find.byTooltip('训练家卡片下移');
        await Scrollable.ensureVisible(tester.element(down), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(down);
        await tester.pumpAndSettle();
        expect(
          LauncherSettings.decode(saved).modules.first.module,
          HomeModule.titodex,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('完成'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('module-trainer')), findsNothing);
        expect(find.byKey(const ValueKey('launch-titodex')), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
