import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/type_chart.dart';
import 'package:titodex/features/journey/ask_motion_theme.dart';
import 'package:titodex/features/journey/ask_motion_images.dart';
import 'package:titodex/widgets/ask_answer_motion_title.dart';

const _titleKey = ValueKey('tested-title');
const _style = TextStyle(fontFamily: 'Ahem', fontSize: 12, height: 1);
const _ball = AskMotionTheme(
  topic: 'capture',
  kind: AskMotionKind.ball,
  assets: ['item-sprites/poke-ball.png'],
);
const _book = AskMotionTheme(
  topic: 'moves',
  kind: AskMotionKind.book,
  assets: ['item-sprites/sonias-book.png'],
);
const _berries = AskMotionTheme(
  topic: 'berries',
  kind: AskMotionKind.berries,
  assets: ['item-sprites/oran-berry.png', 'item-sprites/pecha-berry.png'],
);
const _types = AskMotionTheme(
  topic: 'types',
  kind: AskMotionKind.emblems,
  assets: ['assets/type_icons/fire.png', 'assets/type_icons/grass.png'],
);

Widget _host({
  String text = '1234567890',
  AskMotionTheme theme = _book,
  AskMotionOutcome? outcome,
  String stage = 'lookup',
  bool reduced = false,
  bool ticker = true,
  double width = 300,
  double scale = 1,
  bool leading = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduced,
      textScaler: TextScaler.linear(scale),
    ),
    child: Scaffold(
      body: Center(
        child: TickerMode(
          enabled: ticker,
          child: SizedBox(
            width: width,
            child: AskAnswerMotionTitle(
              key: _titleKey,
              text: text,
              theme: theme,
              outcome: outcome,
              stage: stage,
              style: _style,
              leading: leading,
              prepareImages: (_, resources) async => {
                for (final resource in resources)
                  resource: resource.startsWith('assets/')
                      ? AssetImage(resource)
                      : AskMotionImages.fallback(resource),
              },
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _start(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pump();
  // Start the animation clock after the asynchronous image preparation frame.
  await tester.pump();
}

void main() {
  testWidgets(
    'leading props cycle without restarting on stages and finish on the subject',
    (tester) async {
      await _start(tester, _host(theme: _berries, leading: true));
      ImageProvider current() => tester
          .widget<Image>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('ask-motion-leading-image')),
                  matching: find.byType(Image),
                )
                .first,
          )
          .image;
      expect(current(), const AssetImage('assets/ask_motion/oran-berry.png'));
      final position = find.byKey(
        const ValueKey('ask-motion-leading-position'),
      );
      expect(
        tester.getTopLeft(position).dx,
        tester.getTopLeft(find.byKey(_titleKey)).dx,
      );
      await tester.pump(const Duration(milliseconds: 700));
      await _start(
        tester,
        _host(theme: _berries, leading: true, stage: 'verify'),
      );
      expect(tester.widget<Transform>(position).transform.storage[13], 0);
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump();
      expect(current(), const AssetImage('assets/ask_motion/pecha-berry.png'));
      await _start(
        tester,
        _host(
          theme: _berries,
          leading: true,
          outcome: AskMotionOutcome.caught,
          text: 'Done',
        ),
      );
      await tester.pumpAndSettle();
      expect(current(), const AssetImage('assets/ask_motion/oran-berry.png'));
      expect(tester.widget<Transform>(position).transform.storage[13], 0);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pump(const Duration(seconds: 8));
      expect(current(), const AssetImage('assets/ask_motion/oran-berry.png'));
    },
  );

  testWidgets(
    'leading ball holds its final outcome and reduced motion stays still',
    (tester) async {
      await _start(tester, _host(theme: _ball, leading: true));
      await _start(
        tester,
        _host(theme: _ball, leading: true, outcome: AskMotionOutcome.escaped),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ask-motion-escaped')), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox());
      await _start(
        tester,
        _host(theme: _berries, leading: true, reduced: true),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(
        find.byKey(const ValueKey('ask-motion-leading-image')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('rolling follows actual text span at 48 px/s without sliding', (
    tester,
  ) async {
    await _start(tester, _host(theme: _ball));
    await tester.pump(const Duration(milliseconds: 250));
    Transform position() => tester.widget<Transform>(
      find.byKey(const ValueKey('ask-motion-ball-position')),
    );
    final initial = position().transform.storage[12];
    await tester.pump(const Duration(milliseconds: 500));
    expect(position().transform.storage[12] - initial, closeTo(24, .01));
    final rotation = tester
        .widget<Transform>(
          find.byKey(const ValueKey('ask-motion-ball-rotation')),
        )
        .transform;
    final angle = 48 * .75 / 7.2;
    expect(rotation.storage[0], closeTo(math.cos(angle), .0001));
    expect(rotation.storage[1], closeTo(math.sin(angle), .0001));
    expect(tester.getSize(find.byKey(_titleKey)).height, 18);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('ask-motion-ball-position')),
      findsNothing,
    );
    expect(find.text('1234567890'), findsOneWidget);
  });

  testWidgets('a shorter target still rolls across the old displayed width', (
    tester,
  ) async {
    await _start(tester, _host(theme: _ball));
    await tester.pumpAndSettle();
    final width = tester.getSize(find.text('1234567890')).width;
    final durationMs = ((width + 14.4) / 48 * 1000).ceil();
    await _start(tester, _host(theme: _ball, text: 'tiny'));
    await tester.pump(Duration(milliseconds: durationMs - 100));
    expect(
      find.byKey(const ValueKey('ask-motion-ball-position')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 110));
    expect(
      find.byKey(const ValueKey('ask-motion-ball-position')),
      findsNothing,
    );
    expect(find.text('tiny'), findsOneWidget);
  });

  testWidgets(
    'a narrow title uses the ellipsized span, not the original string',
    (tester) async {
      await _start(
        tester,
        _host(
          theme: _ball,
          width: 72,
          text: 'A very long answer title that must be truncated',
        ),
      );
      await tester.pump(const Duration(milliseconds: 1810));
      expect(
        find.byKey(const ValueKey('ask-motion-ball-position')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'interruption replaces the previous prop and retires the latest one',
    (tester) async {
      await _start(tester, _host());
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('ask-motion-book')), findsOneWidget);
      await _start(tester, _host(theme: _berries, text: 'Compare berries'));
      expect(find.byKey(const ValueKey('ask-motion-book')), findsNothing);
      expect(find.byKey(const ValueKey('ask-motion-berry-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('ask-motion-berry-1')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ask-motion-berry-0')), findsNothing);
      expect(find.text('Compare berries'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('each progress stage keeps the selected topic material', (
    tester,
  ) async {
    for (final stage in ['lookup', 'retrieve', 'verify', 'organize']) {
      await _start(tester, _host(theme: _types, stage: stage, text: stage));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('ask-motion-emblem-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('ask-motion-emblem-1')), findsOneWidget);
      final backgrounds = tester
          .widgetList<Container>(find.byType(Container))
          .map((container) => container.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.color);
      expect(
        backgrounds,
        containsAll([typeTileColor('fire'), typeTileColor('grass')]),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ask-motion-emblem-0')), findsNothing);
    }
  });

  testWidgets('success keeps the ball closed; unsupported answer opens it', (
    tester,
  ) async {
    for (final outcome in [AskMotionOutcome.caught, AskMotionOutcome.escaped]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _start(tester, _host());
      await _start(tester, _host(outcome: outcome, text: outcome.name));
      await tester.pump(const Duration(milliseconds: 650));
      expect(
        find.byKey(ValueKey('ask-motion-${outcome.name}')),
        findsOneWidget,
      );
      final lid = tester
          .widget<Transform>(find.byKey(const ValueKey('ask-motion-ball-lid')))
          .transform;
      expect(
        lid.storage[1],
        outcome == AskMotionOutcome.caught
            ? 0
            : closeTo(math.sin(-24 * math.pi / 180), .0001),
      );
      await tester.pump(const Duration(milliseconds: 540));
      expect(find.byKey(ValueKey('ask-motion-${outcome.name}')), findsNothing);
      expect(find.text(outcome.name), findsOneWidget);
      await _start(
        tester,
        _host(outcome: outcome, text: outcome.name, stage: 'late'),
      );
      expect(find.byKey(ValueKey('ask-motion-${outcome.name}')), findsNothing);
    }
  });

  testWidgets('completed history and neutral events never play catch effects', (
    tester,
  ) async {
    await _start(tester, _host(outcome: AskMotionOutcome.caught));
    expect(find.byKey(const ValueKey('ask-motion-caught')), findsNothing);
    expect(find.text('1234567890'), findsOneWidget);
    await _start(
      tester,
      _host(outcome: AskMotionOutcome.neutral, text: 'Clarify'),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.text('Clarify'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion and hidden tickers cancel without replay', (
    tester,
  ) async {
    await _start(tester, _host());
    await tester.pump(const Duration(milliseconds: 200));
    await _start(tester, _host(reduced: true));
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const ValueKey('ask-motion-book')), findsNothing);
    await _start(tester, _host(reduced: true, text: 'Verify', stage: 'verify'));
    expect(find.text('Verify'), findsOneWidget);
    await _start(tester, _host(text: 'Next', ticker: false));
    await _start(tester, _host(text: 'Next', ticker: true));
    expect(find.byKey(const ValueKey('ask-motion-book')), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('background updates remain still and resume never replays them', (
    tester,
  ) async {
    await _start(tester, _host());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _start(
      tester,
      _host(text: 'Background answer', outcome: AskMotionOutcome.caught),
    );
    expect(find.byKey(const ValueKey('ask-motion-caught')), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Background answer'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('large text grows only its line and resizing settles motion', (
    tester,
  ) async {
    await _start(tester, _host(theme: _ball));
    await tester.pump(const Duration(milliseconds: 200));
    await _start(tester, _host(theme: _ball, width: 110, scale: 2.5));
    expect(tester.getSize(find.byKey(_titleKey)).height, 30);
    expect(
      find.byKey(const ValueKey('ask-motion-ball-position')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
