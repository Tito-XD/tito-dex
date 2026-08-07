import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/widgets/pokemon_artwork_viewer.dart';

Future<void> pumpViewer(
  WidgetTester tester,
  PokemonSummary summary,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPokemonArtworkViewer(context, summary: summary),
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

  testWidgets('viewer shows 背面 toggle and auto-selects a back edition', (
    tester,
  ) async {
    await pumpViewer(tester, pikachu);
    expect(find.text('背面'), findsOneWidget);

    await tester.tap(find.text('背面'));
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
      reason: 'back toggle should switch to a /back/ sprite source',
    );
  });

  testWidgets('toggling back twice restores the front source', (tester) async {
    await pumpViewer(tester, pikachu);
    await tester.tap(find.text('背面'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('背面'));
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
