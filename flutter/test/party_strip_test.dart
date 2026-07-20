import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/widgets/party_strip.dart';

void main() {
  const party = [
    PartyMember(species: 'Alpha', level: 12),
    PartyMember(species: 'Beta', level: 34),
    PartyMember(species: 'Gamma'),
  ];

  Widget host({
    required double width,
    required double height,
    bool strip = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: PartyStrip(
              party: party,
              compact: true,
              square: true,
              gridMode: true,
              stripMode: strip,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('square grid renders level badges and keeps six slots', (
    tester,
  ) async {
    await tester.pumpWidget(host(width: 200, height: 320));

    expect(find.text('Lv12'), findsOneWidget);
    expect(find.text('Lv34'), findsOneWidget);
    // Gamma has no level — no badge for it.
    expect(find.textContaining('Lv'), findsNWidgets(2));
    // Three members + three empty slots always total six cells.
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsNWidgets(3));
  });

  testWidgets('strip mode caps cell height instead of stretching', (
    tester,
  ) async {
    await tester.pumpWidget(host(width: 700, height: 400, strip: true));

    // One row of six: the grid floats vertically centered at its capped
    // height rather than filling the whole leftover card height.
    final gridSize = tester.getSize(find.byType(GridView));
    expect(gridSize.height, lessThan(200));
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsNWidgets(3));
  });
}
