import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:titodex/widgets/secondary_page_scaffold.dart';

void main() {
  testWidgets('scrolling content cannot paint over the fixed header', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: RepaintBoundary(
              key: boundaryKey,
              child: SecondaryPageScaffold(
                title: 'Header',
                showSettings: false,
                children: [
                  Container(height: 350, color: Colors.red),
                  Container(height: 700, color: Colors.blue),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final header = tester.getRect(find.byType(SecondaryPageAppBar));
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      final offset =
          (header.center.dy.floor() * image.width + header.center.dx.floor()) *
          4;
      expect(bytes.sublist(offset, offset + 4), isNot([244, 67, 54, 255]));
      image.dispose();
    });
  });

  testWidgets(
    'reference grid builds only visible cards and can reach its tail',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final built = <int>{};
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: SecondaryPageScaffold(
                title: '地点',
                showSettings: false,
                slivers: [
                  SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 66,
                        ),
                    itemCount: 200,
                    itemBuilder: (_, index) {
                      built.add(index);
                      return Text('area-$index');
                    },
                  ),
                ],
                children: const [SizedBox(height: 80, child: Text('搜索'))],
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      expect(built.length, lessThan(40));
      expect(find.text('area-199'), findsNothing);
      final titlePosition = tester.getTopLeft(find.text('地点'));
      await tester.scrollUntilVisible(
        find.text('area-199'),
        450,
        maxScrolls: 30,
      );
      await tester.pumpAndSettle();
      expect(find.text('area-199'), findsOneWidget);
      expect(tester.getTopLeft(find.text('地点')), titlePosition);
    },
  );

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
