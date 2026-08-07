import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/widgets/pokemon_artwork_viewer.dart';

Future<void> pumpViewer(WidgetTester tester, PokemonSummary summary) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showPokemonArtworkViewer(context, summary: summary),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  const pikachu = PokemonSummary(
    id: 25,
    nameEn: 'pikachu',
    nameZh: '皮卡丘',
    types: ['electric'],
    localSpritePath: 'sprites/25.png',
  );

  testWidgets('back control belongs to an edition and never auto-selects', (
    tester,
  ) async {
    await pumpViewer(tester, pikachu);
    expect(find.text('背面'), findsNothing);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsWidgets);

    final before = tester.widgetList(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.contains('/back/'),
      ),
    );
    expect(before, isEmpty);

    await tester.tap(find.byIcon(Icons.swap_horiz_rounded).first);
    await tester.pump(const Duration(milliseconds: 200));

    final backWidgets = tester.widgetList(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.contains('/back/'),
      ),
    );
    expect(
      backWidgets,
      isNotEmpty,
      reason: 'the edition flip control should use its own /back/ sprite',
    );
  });

  testWidgets('tapping the same edition flip twice restores its front', (
    tester,
  ) async {
    await pumpViewer(tester, pikachu);
    final flip = find.byIcon(Icons.swap_horiz_rounded).first;
    await tester.tap(flip);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(flip);
    await tester.pump(const Duration(milliseconds: 200));

    final backWidgets = tester.widgetList(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.contains('/back/'),
      ),
    );
    expect(backWidgets, isEmpty);
  });
}
