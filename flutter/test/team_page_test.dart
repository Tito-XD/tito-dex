import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/features/game/game_edition.dart';
import 'package:titodex/features/game/game_edition_repository.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/team_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await gameEditionRepository.save(defaultGameEdition);
  });

  testWidgets('team heading follows the selected game flavor', (tester) async {
    await gameEditionRepository.save(GameEdition.hgss.withFlavor('heartgold'));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TeamPage(
              journey: CurrentJourney.mock().copyWith(
                game: 'SoulSilver',
                party: const [],
                saveSyncedParty: const [],
              ),
              onSaveJourney: (_) {},
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('${AppZh.navTeam} · 心金'), findsOneWidget);
    expect(find.textContaining('魂银'), findsNothing);
  });

  testWidgets('team rows are present on the first painted frame', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TeamPage(
              journey: CurrentJourney.mock().copyWith(
                party: const [PartyMember(species: 'Cyndaquil', level: 5)],
              ),
              onSaveJourney: (_) {},
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.text('火球鼠'), findsOneWidget);
    expect(find.text(AppZh.teamSummaryTitle), findsOneWidget);
  });

  testWidgets('team editor saves a user override and removes a member', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var journey = CurrentJourney.mock().copyWith(
      party: const [PartyMember(species: 'Cyndaquil', level: 5)],
    );
    late StateSetter rebuild;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return TeamPage(
                  journey: journey,
                  onSaveJourney: (updated) {
                    journey = updated;
                    rebuild(() {});
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await tester.tap(find.text('火球鼠').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.widgetWithText(TextField, AppZh.teamEditNickname),
      '小火',
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppZh.teamEditLevel),
      '12',
    );
    final confirm = find.text(AppZh.confirm).last;
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pump(const Duration(milliseconds: 300));

    expect(journey.partyUserOverride, isTrue);
    expect(journey.party.single.nickname, '小火');
    expect(journey.party.single.level, 12);

    final renamedMember = find.text('小火').first;
    await tester.ensureVisible(renamedMember);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(renamedMember);
    await tester.pump(const Duration(milliseconds: 300));
    final delete = find.text(AppZh.teamEditDelete);
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pump(const Duration(milliseconds: 300));
    expect(journey.party, isEmpty);
  });
}
