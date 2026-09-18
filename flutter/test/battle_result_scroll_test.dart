import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/battle_result_scroll.dart';

void main() {
  Widget app({bool reduceMotion = false, double resultHeight = 220}) =>
      MaterialApp(
        theme: buildTitoTheme(),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              size: const Size(400, 700),
              disableAnimations: reduceMotion,
            ),
            child: BattleResultScroll(
              storageId: 'test',
              leading: const SizedBox(height: 50, child: Text('Scope')),
              result: SizedBox(
                height: resultHeight,
                child: const Text('Full result'),
              ),
              summary: const Text('Attack 120'),
              children: const [SizedBox(height: 1100, child: Text('Inputs'))],
            ),
          ),
        ),
      );

  testWidgets(
    'one vertical scroll; summary animates and tap smoothly returns',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 700);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(Scrollable), findsOneWidget);
      final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
      final inputY = tester.getTopLeft(find.text('Inputs')).dy;
      scroll.jumpTo(310);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final transition = tester.widget<SizeTransition>(
        find.byType(SizeTransition),
      );
      expect(transition.sizeFactor.value, inExclusiveRange(0, 1));
      expect(
        tester.getTopLeft(find.text('Inputs')).dy,
        closeTo(inputY - 310, .1),
      );
      await tester.pumpAndSettle();
      expect(find.text('Attack 120'), findsOneWidget);
      expect(transition.sizeFactor.value, 1);
      await tester.tap(find.byKey(const ValueKey('battle-result-summary')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(scroll.offset, inExclusiveRange(0, 310));
      expect(transition.sizeFactor.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      expect(find.text('Attack 120'), findsNothing);
      expect(tester.getTopLeft(find.text('Inputs')).dy, inputY);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long results collapse only after leaving viewport; reduced motion is immediate',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 700);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(reduceMotion: true, resultHeight: 750));
      await tester.pumpAndSettle();
      final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
      scroll.jumpTo(400);
      await tester.pumpAndSettle();
      expect(find.text('Attack 120'), findsNothing);
      scroll.jumpTo(850);
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .widget<SizeTransition>(find.byType(SizeTransition))
            .sizeFactor
            .value,
        1,
      );
      await tester.tap(find.byKey(const ValueKey('battle-result-summary')));
      await tester.pump();
      expect(scroll.offset, 0);
      expect(
        tester
            .widget<SizeTransition>(find.byType(SizeTransition))
            .sizeFactor
            .value,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
