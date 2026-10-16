import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:titodex_launcher/device_bridge.dart';
import 'package:titodex_launcher/main.dart' as app;
import 'package:titodex_launcher/models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('RG device bridge, persistent preferences, real app library', (
    tester,
  ) async {
    final bridge = DeviceBridge();
    final original = await bridge.readSettings();
    try {
      final installed = await bridge.apps();
      expect(installed.any((a) => a.package == titoDexPackage), isTrue);
      expect(
        installed.every((a) => a.package != 'com.tito.titodex.launcher'),
        isTrue,
      );
      expect(installed.any((a) => a.icon.isNotEmpty), isTrue);
      final status = await bridge.status();
      expect(status['battery'], inInclusiveRange(0, 100));
      expect(status['defaultHome'], isA<bool>());
      final testSettings = LauncherSettings.decode(original)
        ..name = '掌机测试'
        ..style = LauncherStyle.plastic
        ..opacity = .7
        ..blurPanels = false
        ..libraryColumns = 5
        ..applyLayout(HomeLayout.quiet);
      testSettings.favorites.add(installed.first.id);
      await bridge.save(testSettings);
      final read = LauncherSettings.decode(await bridge.readSettings());
      expect(read.name, '掌机测试');
      expect(read.style, LauncherStyle.plastic);
      expect(read.layout, HomeLayout.quiet);
      expect(read.opacity, .7);
      expect(read.libraryColumns, 5);
      expect(read.photo, LauncherSettings.decode(original).photo);
      expect(read.favorites, testSettings.favorites);
      expect(await bridge.launch('com.tito.missing.launcher_test'), isFalse);
      await bridge.save(
        LauncherSettings.decode(original)..applyLayout(HomeLayout.roam),
      );
      await app.main();
      await tester.pumpAndSettle();
      // Native enumeration runs independently of Flutter frames.
      for (
        var i = 0;
        i < 20 &&
            find.byKey(const ValueKey('launch-titodex')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const ValueKey('launch-titodex')), findsOneWidget);
      await tester.tap(find.text('应用库'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'com.tito.titodex');
      await tester.pumpAndSettle();
      expect(find.text('TitoDex').evaluate().length, greaterThanOrEqualTo(1));
      expect(tester.takeException(), isNull);
    } finally {
      await DeviceBridge.channel.invokeMethod<void>('writeSettings', {
        'json': original ?? '{}',
      });
    }
  });
}
