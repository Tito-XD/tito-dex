import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/dex_page.dart';
import 'package:titodex/widgets/secondary_page_scaffold.dart';
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
  testWidgets('Dex waits for route chrome then animates tab/filter selection', (
    tester,
  ) async {
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

    double translationY(String key) => tester
        .widget<Transform>(find.byKey(ValueKey<String>(key)))
        .transform
        .getTranslation()
        .y;

    final seenMotion = 'dex-filter-chip-motion-${AppZh.dexFilterSeen}';
    expect(translationY(seenMotion), 0);
    await tester.tap(find.text(AppZh.dexFilterSeen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final filterMiddle = translationY(seenMotion);
    expect(filterMiddle, greaterThan(-1.5));
    expect(filterMiddle, lessThan(0));
    await tester.pumpAndSettle();
    expect(translationY(seenMotion), -1.5);

    final journeyMotion = 'dex-mode-tab-motion-${AppZh.dexTabJourney}';
    expect(translationY(journeyMotion), 0);
    await tester.tap(find.text(AppZh.dexTabJourney));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final tabMiddle = translationY(journeyMotion);
    expect(tabMiddle, greaterThan(-1.5));
    expect(tabMiddle, lessThan(0));
    await tester.pumpAndSettle();
    expect(translationY(journeyMotion), -1.5);
    expect(tester.takeException(), isNull);
  });
}
