import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_buttons.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/tito_fact_grid.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => appVisualStyle.setStyle(AppVisualStyle.classic));

  for (final style in AppVisualStyle.values) {
    testWidgets('${style.name} keeps enlarged actions and facts readable', (
      tester,
    ) async {
      await appVisualStyle.setStyle(style);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTitoTheme(style),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 260,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TitoPrimaryButton(
                          label: 'Ask TitoDex about this location',
                          expanded: true,
                          onPressed: () => taps++,
                        ),
                        const SizedBox(height: 8),
                        const TitoFactGrid(
                          columns: 3,
                          children: [
                            TitoFactTile(
                              title: 'Average level',
                              child: Text('24.0'),
                            ),
                            TitoFactTile(
                              title: 'Base stat total',
                              child: Text('2209'),
                            ),
                            TitoFactTile(
                              title: 'Type coverage',
                              child: Text('9/18'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Ask TitoDex about this location'), findsOneWidget);
      await tester.tap(find.byType(TitoPrimaryButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
      final cells = find.byType(TitoFactTile);
      expect(cells, findsNWidgets(3));
      expect(tester.getSize(cells.first).width, 260);
      expect(
        tester.getTopLeft(cells.at(1)).dy,
        greaterThan(tester.getBottomLeft(cells.first).dy),
      );
    });
  }
}
