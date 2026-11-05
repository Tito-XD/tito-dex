import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_encounter_labels.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/widgets/pokemon_detail_sections.dart';

void main() {
  testWidgets('encounter row lists every method, not just the first two', (
    tester,
  ) async {
    const methods = ['walk', 'surf', 'old-rod', 'good-rod'];
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ObtainLocationsCard(
              locations: [
                ObtainLocationEntry(
                  areaSlug: 'route-1',
                  areaLabelZh: '一号道路',
                  methods: methods,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final expected = methods.map(encounterMethodLabelZh).join(' · ');
    expect(find.text(expected), findsOneWidget);
    for (final method in methods) {
      expect(find.textContaining(encounterMethodLabelZh(method)), findsWidgets);
    }
  });
}
