import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:titodex/main.dart' as app;
import 'package:titodex/pages/media_resource_page.dart';
import 'package:titodex/widgets/pokemon_card.dart';

Future<void> settle(WidgetTester tester, {int rounds = 20}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('smoke: settings/media manager + dex artwork back view', (
    tester,
  ) async {
    app.main();
    await binding.convertFlutterSurfaceToImage();

    // Home surfaces a bottom sheet offering the offline pack. Wait for it
    // (bootstrap may take a while on a cold emulator).
    var ready = false;
    for (var i = 0; i < 180; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (tester.any(find.text('去设置'))) {
        ready = true;
        break;
      }
      if (tester.any(find.text('图鉴'))) {
        ready = true;
        break;
      }
    }
    expect(ready, isTrue, reason: 'home did not become interactive in time');
    await binding.takeScreenshot('01_home');

    // Settings: the offline sheet has a 去设置 shortcut; otherwise header.
    final settingsIcon = find.byIcon(Icons.settings_rounded);
    if (tester.any(find.text('去设置'))) {
      await tester.tap(find.text('去设置'));
    } else if (settingsIcon.evaluate().isNotEmpty) {
      await tester.tap(settingsIcon.first);
    } else {
      await tester.tap(find.text('搜索'));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.settings_rounded).first);
    }
    await settle(tester);

    // Scroll to the media resource manager entry inside the companion
    // section and open it.
    var foundEntry = false;
    for (var i = 0; i < 16; i++) {
      if (tester.any(find.text('稍后'))) {
        await tester.tap(find.text('稍后'));
        await tester.pump(const Duration(milliseconds: 400));
      }
      if (tester.any(find.text('媒体资源管理'))) {
        foundEntry = true;
        break;
      }
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        await tester.drag(scrollables.first, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }
    expect(foundEntry, isTrue, reason: '媒体资源管理 entry not visible');
    await binding.takeScreenshot('02_settings');
    if (tester.any(find.text('稍后'))) {
      await tester.tap(find.text('稍后'));
      await tester.pump(const Duration(milliseconds: 400));
    }
    final entryFinder = find.text('媒体资源管理');
    await tester.ensureVisible(entryFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(entryFinder);
    await settle(tester);
    final pageOpen = tester.any(find.byType(MediaResourcePage));
    if (!pageOpen) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .take(30)
          .toList();
      debugPrint('MEDIA TEXTS: $texts');
    }
    expect(
      pageOpen,
      isTrue,
      reason: 'media resource page did not open',
    );
    await binding.takeScreenshot('03_media_resource');

    // Back to home (media page → settings → home).
    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);

    // Dex → first species → artwork viewer with the back toggle.
    await tester.tap(find.text('图鉴'));
    await settle(tester);
    expect(
      tester.any(find.byType(PokemonMiniCard)),
      isTrue,
      reason: 'dex grid did not render',
    );
    await binding.takeScreenshot('04_dex');
    await tester.tap(find.byType(PokemonMiniCard).first);
    await settle(tester);
    final artwork = find.byKey(const ValueKey('pokemon-detail-artwork'));
    expect(artwork, findsOneWidget, reason: 'detail artwork not found');
    await binding.takeScreenshot('05_detail');
    await tester.tap(artwork);
    await settle(tester);
    expect(
      tester.any(find.text('背面')),
      isTrue,
      reason: 'artwork viewer back toggle missing',
    );
    await binding.takeScreenshot('06_viewer_front');
    await tester.tap(find.text('背面'));
    await tester.pump(const Duration(milliseconds: 400));
    await binding.takeScreenshot('07_viewer_back');
  });
}
