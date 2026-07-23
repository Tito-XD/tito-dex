import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:titodex/widgets/secondary_page_scaffold.dart';

void main() {
  testWidgets('secondary page title stays fixed while body scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SecondaryPageScaffold(
              title: '固定标题',
              showSettings: false,
              children: [SizedBox(height: 1200, child: Text('长内容'))],
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    final title = find.text('固定标题');
    final titleTopBefore = tester.getTopLeft(title).dy;

    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(title).dy, titleTopBefore);
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(0),
    );
  });
}
