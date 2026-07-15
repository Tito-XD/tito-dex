import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/app.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/navigation/tito_page_transition.dart';

void main() {
  testWidgets('TitoDex app opens home without a blocking bootstrap loader', (
    tester,
  ) async {
    await tester.pumpWidget(const TitoDexApp());
    await tester.pump();

    expect(find.text(AppZh.appTitle), findsWidgets);
    expect(find.text(AppZh.bootstrapLoading), findsNothing);
    expect(find.text(AppZh.trainerNameLine('Tito')), findsOneWidget);
  });

  testWidgets('Home-action pages keep their content outside the Hero overlay', (
    tester,
  ) async {
    final page =
        titoMaterialPage<void>(
              key: const ValueKey<String>('team-page'),
              heroTag: TitoHomeActionHero.team,
              child: const Placeholder(),
            )
            as MaterialPage<void>;

    await tester.pumpWidget(MaterialApp(home: page.child));

    expect(find.byType(Placeholder), findsOneWidget);
    expect(find.byType(Hero), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is IgnorePointer && widget.ignoring,
      ),
      findsOneWidget,
    );
  });
}
