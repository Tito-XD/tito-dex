import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:titodex/pages/sleep_tools_page.dart';

void main() {
  testWidgets('sleep tools page is reachable and updates recipe energy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/search/sleep-tools',
      routes: [
        GoRoute(
          path: '/search/sleep-tools',
          builder: (context, state) => const Scaffold(body: SleepToolsPage()),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Pokémon Sleep 工具'), findsOneWidget);
    expect(find.text('100 / 100'), findsOneWidget);
    expect(find.text('通常料理能量 · 0'), findsOneWidget);

    await tester.tap(find.text('特选苹果 · 90'));
    await tester.pump();

    expect(find.text('通常料理能量 · 90'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
