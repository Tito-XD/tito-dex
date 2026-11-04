// Battle tools keep one layout while type relations load: the loading state
// lives in the pinned result slot instead of swapping the page to a plain
// list, so the inputs do not jump when the result arrives.
//
// Runs in its own isolate so `battleToolsService` starts with an empty cache.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/l10n/app_locale.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/companion/blind_spot_page.dart';
import 'package:titodex/pages/companion/type_matchup_page.dart';
import 'package:titodex/widgets/battle_result_scroll.dart';
import 'package:titodex/widgets/battle_tool_panels.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugOverride(AppUiLanguage.zh);
  });

  for (final (name, page) in [
    (
      'matchup',
      TypeMatchupPage(journey: CurrentJourney.mock(), embedded: true),
    ),
    (
      'blind spot',
      BlindSpotPage(journey: CurrentJourney.mock(), embedded: true),
    ),
  ]) {
    testWidgets('$name keeps the result layout while relations load', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));

      expect(find.byType(BattleResultScroll), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BattleResultScroll),
          matching: find.byType(BattleResultLoading),
        ),
        findsOneWidget,
      );
    });
  }
}
