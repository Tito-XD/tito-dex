import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/theme/motion_preferences.dart';
import 'package:titodex/widgets/tito_animated_number.dart';
import 'package:titodex/widgets/tito_marquee.dart';
import 'package:titodex/widgets/tito_skeleton.dart';
import 'package:titodex/widgets/tito_typewriter_text.dart';

const _numberKey = ValueKey('number');

Widget _host(Widget child, {bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: Center(child: child)),
  ),
);

String _shown(WidgetTester tester) => tester
    .state<TitoAnimatedNumberState>(find.byType(TitoAnimatedNumber))
    .displayedText
    .trim();

Widget _count(num value, {Object identity = 'a', bool reduced = false}) =>
    _host(
      TitoAnimatedNumber(
        value: value,
        identity: identity,
        countUp: true,
        fractionDigits: 1,
        suffix: '%',
        textKey: _numberKey,
      ),
      reduced: reduced,
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TitoAnimatedNumberState.debugResetMemory();
    await motionPreferences.setListAnimationsEnabled(true);
  });

  group('count up', () {
    testWidgets('first result rolls in from zero; semantics read the final', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_count(36));
      expect(_shown(tester), '0.0%');
      expect(find.bySemanticsLabel('36.0%'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(_shown(tester), isNot('0.0%'));
      await tester.pumpAndSettle();
      expect(_shown(tester), '36.0%');
      semantics.dispose();
    });

    testWidgets('a new subject rolls in again; a parameter change rolls', (
      tester,
    ) async {
      await tester.pumpWidget(_count(36));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_count(50));
      await tester.pump(const Duration(milliseconds: 60));
      expect(_shown(tester), isNot('0.0%'));
      await tester.pumpAndSettle();
      expect(_shown(tester), '50.0%');
      await tester.pumpWidget(_count(20, identity: 'b'));
      expect(_shown(tester), '0.0%');
      await tester.pumpAndSettle();
      expect(_shown(tester), '20.0%');
    });

    testWidgets('reduced motion shows the final value at once', (tester) async {
      await tester.pumpWidget(_count(36, reduced: true));
      expect(_shown(tester), '36.0%');
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('typewriter', () {
    String visible(WidgetTester tester) {
      final rich = tester.widget<RichText>(
        find.descendant(
          of: find.byType(TitoTypewriterText),
          matching: find.byType(RichText),
        ),
      );
      // Text.rich wraps our span in one carrying the default style.
      var span = rich.text as TextSpan;
      while (span.children!.length == 1) {
        span = span.children!.single as TextSpan;
      }
      return span.children!.first.toPlainText();
    }

    testWidgets('types the line out and keeps its full size', (tester) async {
      const line = '今天也一起加油吧！';
      await tester.pumpWidget(_host(const TitoTypewriterText(line)));
      final size = tester.getSize(find.byType(TitoTypewriterText));
      expect(visible(tester), isEmpty);
      await tester.pump(const Duration(milliseconds: 120));
      expect(visible(tester).length, inInclusiveRange(1, line.length - 1));
      expect(tester.getSize(find.byType(TitoTypewriterText)), size);
      await tester.pumpAndSettle();
      expect(visible(tester), line);
    });

    testWidgets('reduced motion shows the whole line', (tester) async {
      await tester.pumpWidget(
        _host(const TitoTypewriterText('你好'), reduced: true),
      );
      expect(visible(tester), '你好');
    });
  });

  group('marquee', () {
    final items = [
      for (var i = 0; i < 8; i++)
        SizedBox(width: 90, height: 20, child: Text('source $i')),
    ];

    testWidgets('overflowing items loop sideways', (tester) async {
      await tester.pumpWidget(
        _host(SizedBox(width: 300, child: TitoMarquee(children: items))),
      );
      await tester.pump();
      final start = tester.getTopLeft(find.text('source 0').first).dx;
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.getTopLeft(find.text('source 0').first).dx,
        lessThan(start),
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('fits or reduced motion: a still wrap with one copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(width: 300, child: TitoMarquee(children: items)),
          reduced: true,
        ),
      );
      expect(find.byType(Wrap), findsOneWidget);
      expect(find.text('source 7'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: TitoMarquee(children: items.take(2).toList()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(Wrap), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('skeleton shimmer', () {
    testWidgets('sweeps while loading, static under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const TitoSkeletonBox(height: 20, width: 100, shimmer: true)),
      );
      expect(find.byType(ShaderMask), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(
        _host(
          const TitoSkeletonBox(height: 20, width: 100, shimmer: true),
          reduced: true,
        ),
      );
      await tester.pump();
      expect(find.byType(ShaderMask), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
