import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/dex_page.dart';
import 'package:titodex/widgets/secondary_page_scaffold.dart';
import 'package:titodex/widgets/dex_search_filter_sheet.dart';
import 'package:titodex/widgets/tito_page_container.dart';

const _journey = CurrentJourney(
  game: 'SoulSilver',
  trainerName: 'Tito',
  location: 'Route 36',
  badges: 0,
  maxBadges: 16,
  playTime: '00:00',
  party: [],
  timeline: [],
  companion: '',
);

void main() {
  testWidgets(
    'Dex waits for route chrome and keeps every scope control in the filter sheet',
    (tester) async {
      var bootstrapCalls = 0;
      late final GoRouter router;
      router = GoRouter(
        initialLocation: '/dex',
        routes: [
          GoRoute(
            path: '/dex',
            builder: (context, state) => TitoPageContainer(
              child: DexPage(
                journey: _journey,
                bootstrapOverride: () async {
                  bootstrapCalls += 1;
                },
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      expect(bootstrapCalls, 0);
      expect(find.byType(SecondaryPageSubtitle), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SecondaryPageSubtitle),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );

      await tester.pump();
      await tester.pump();
      expect(bootstrapCalls, 1);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('旅程同行'), findsNothing);
      await tester.tap(find.text('筛选'));
      await tester.pumpAndSettle();
      expect(find.byType(DexSearchFilterSheet), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/dex');
      expect(find.byKey(const ValueKey('浏览对象-false-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('世代-0-0')), findsOneWidget);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('旅程同行'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
