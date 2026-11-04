import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:titodex/features/companion/battle_tools_service.dart';
import 'package:titodex/features/dex/dex_cache_store.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_repository.dart';
import 'package:titodex/features/dex/type_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/l10n/app_locale.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/handheld_input.dart';
import 'package:titodex/widgets/party_team_list.dart';
import 'package:titodex/widgets/team_summary_card.dart';
import 'package:titodex/widgets/tito_loading_panel.dart';
import 'package:titodex/features/game/game_edition.dart';
import 'package:titodex/features/game/game_edition_repository.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/team_page.dart';

const _auditFont = String.fromEnvironment('UI_AUDIT_CJK_FONT');
const _exportScreenshots = bool.fromEnvironment('APP_LAYOUT_SCREENSHOTS');
const _auditBoundary = Key('team-layout-audit-boundary');
const _auditTackle = CachedMove(
  id: 33,
  nameEn: 'Tackle',
  nameZh: '撞击',
  type: 'normal',
  category: 'physical',
  power: 40,
);
const _auditSummaries = [
  PokemonSummary(
    id: 155,
    nameEn: 'Cyndaquil',
    nameZh: '火球鼠',
    types: ['fire'],
    spriteUrl: '',
  ),
  PokemonSummary(
    id: 158,
    nameEn: 'Totodile',
    nameZh: '小锯鳄',
    types: ['water'],
    spriteUrl: '',
  ),
  PokemonSummary(
    id: 152,
    nameEn: 'Chikorita',
    nameZh: '菊草叶',
    types: ['grass'],
    spriteUrl: '',
  ),
  PokemonSummary(
    id: 25,
    nameEn: 'Pikachu',
    nameZh: '皮卡丘',
    types: ['electric'],
    spriteUrl: '',
  ),
  PokemonSummary(
    id: 133,
    nameEn: 'Eevee',
    nameZh: '伊布',
    types: ['normal'],
    spriteUrl: '',
  ),
  PokemonSummary(
    id: 214,
    nameEn: 'Heracross',
    nameZh: '赫拉克罗斯',
    types: ['bug', 'fighting'],
    spriteUrl: '',
  ),
];
const _auditBaseStats = [
  PokemonBaseStats(
    hp: 39,
    attack: 52,
    defense: 43,
    specialAttack: 60,
    specialDefense: 50,
    speed: 65,
  ),
  PokemonBaseStats(
    hp: 50,
    attack: 65,
    defense: 64,
    specialAttack: 44,
    specialDefense: 48,
    speed: 43,
  ),
  PokemonBaseStats(
    hp: 45,
    attack: 49,
    defense: 65,
    specialAttack: 49,
    specialDefense: 65,
    speed: 45,
  ),
  PokemonBaseStats(
    hp: 35,
    attack: 55,
    defense: 40,
    specialAttack: 50,
    specialDefense: 50,
    speed: 90,
  ),
  PokemonBaseStats(
    hp: 55,
    attack: 55,
    defense: 50,
    specialAttack: 45,
    specialDefense: 65,
    speed: 55,
  ),
  PokemonBaseStats(
    hp: 80,
    attack: 125,
    defense: 75,
    specialAttack: 40,
    specialDefense: 95,
    speed: 85,
  ),
];

// Synthetic members, never imported from a user's save. Empty sprite URLs keep
// the fixture independent of downloaded artwork and external HTTP requests.
final _auditParty = [
  for (var index = 0; index < _auditSummaries.length; index++)
    PartyMember(
      species: _auditSummaries[index].nameEn,
      speciesId: _auditSummaries[index].id,
      nickname: const [
        'Alpha',
        'Beta',
        'Gamma',
        'Delta',
        'Epsilon',
        'Zeta',
      ][index],
      level: 10 + index * 10,
      types: _auditSummaries[index].types,
      abilityId: index == 0 ? 66 : null,
      moveIds: index == 0 ? const [33] : const [],
      movePp: index == 0 ? const [35] : const [],
      heldItemId: index == 0 ? 1 : null,
      currentHp: index == 0 ? 30 : null,
      maxHp: index == 0 ? 39 : null,
    ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Synthetic offline data, isolated from the user's installed bundle/saves.
    final fixture = Directory('build/team-layout-fixture').absolute;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => fixture.path,
        );
    final store = DexCacheStore();
    await store.writeTypeRelations({
      for (final type in typeGridOrder)
        type: const TypeDamageRelations(
          doubleDamageTo: {},
          halfDamageTo: {},
          noDamageTo: {},
        ),
    });
    await store.writeSummaries(_auditSummaries);
    await store.writeMoves({33: _auditTackle});
    for (var index = 0; index < _auditSummaries.length; index++) {
      final summary = _auditSummaries[index];
      await store.writeDetail(
        summary.id,
        PokemonDetail(
          summary: summary,
          genusZh: '',
          heightDm: 5,
          weightHg: 100,
          weaknesses: const [],
          resistances: const [],
          immunities: const [],
          stabSuperEffective: const [],
          evolutionChain: null,
          baseStats: _auditBaseStats[index],
          abilities: index == 0
              ? const [
                  PokemonAbility(
                    nameEn: 'Blaze',
                    nameZh: '猛火',
                    descriptionZh: '',
                  ),
                ]
              : const [],
          moveSet: index == 0
              ? const PokemonMoveSet(
                  levelUp: [
                    PokemonMove(move: _auditTackle, method: 'level-up'),
                  ],
                )
              : const PokemonMoveSet(),
        ),
      );
    }
    final paths = await DexCachePaths.resolve();
    await paths.abilitiesFile.writeAsString(
      '{"66":{"id":66,"nameEn":"Blaze","nameZh":"猛火"}}',
    );
    await paths
        .jsonFile('items.json')
        .writeAsString('[{"id":1,"nameZh":"测试道具","nameEn":"Fixture item"}]');
    await store.writeManifest(
      const DexCacheManifest(
        version: DexCacheManifest.currentVersion,
        complete: false,
        preferOffline: true,
        pokemonCount: 6,
      ),
    );
    await battleToolsService.loadTypeRelations();
    await dexRepository.getAllMoves();
    await dexRepository.getAllAbilities();
    for (final summary in _auditSummaries) {
      await dexRepository.getSummary(summary.id);
      await dexRepository.getDetail(summary.id);
    }
    // This catalog is not memoized by the repository. Check the isolated copy
    // now; each inspector load below also drains its real file I/O explicitly.
    expect(await dexRepository.getReferenceEntries('items.json'), hasLength(1));
    await _loadAuditFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await gameEditionRepository.save(defaultGameEdition);
    AppLocale.instance.debugOverride(AppUiLanguage.zh);
    await appVisualStyle.setStyle(AppVisualStyle.classic);
  });

  tearDown(() async {
    AppLocale.instance.debugOverride(AppUiLanguage.zh);
    await appVisualStyle.setStyle(AppVisualStyle.classic);
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
    expect(find.byKey(const Key('team-summary-header')), findsOneWidget);
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
    expect(
      find.widgetWithText(TextField, AppZh.teamEditNickname),
      findsNothing,
    );
    final edit = find.text(AppZh.teamEditAction);
    await tester.ensureVisible(edit);
    await tester.tap(edit);
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
    // Commit TextField/caret layout before calculating the scroll target.
    await tester.pump();
    await tester.ensureVisible(confirm);
    await tester.pump();
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
    await tester.tap(find.text(AppZh.teamEditAction));
    await tester.pump(const Duration(milliseconds: 300));
    final delete = find.text(AppZh.teamEditDelete);
    await tester.ensureVisible(delete);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(delete);
    await tester.pump(const Duration(milliseconds: 300));
    expect(journey.party, isEmpty);
  });

  testWidgets(
    'member details can collapse and reopen without editing the team',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var saves = 0;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TeamPage(
                journey: CurrentJourney.mock().copyWith(
                  party: const [PartyMember(species: 'Cyndaquil', level: 5)],
                ),
                onSaveJourney: (_) => saves++,
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(const Duration(milliseconds: 300));
      final collapse = find.byKey(const Key('team-inspector-collapse'));
      expect(collapse, findsNothing);
      await tester.tap(find.text('火球鼠'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(collapse);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(collapse);
      await tester.pump(const Duration(milliseconds: 300));
      expect(collapse, findsNothing);
      expect(find.text(AppZh.teamEditAction), findsNothing);
      await tester.ensureVisible(find.text('火球鼠'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('火球鼠'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(collapse, findsOneWidget);
      expect(saves, 0);
    },
  );

  for (final style in AppVisualStyle.values) {
    testWidgets('team panes adapt to usable space and text size: ${style.name}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await appVisualStyle.setStyle(style);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => TeamPage(
              journey: CurrentJourney.mock().copyWith(
                party: _auditParty,
                saveSyncedParty: const [],
              ),
              onSaveJourney: (_) {},
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      const cases =
          <({Size viewport, double scale, double? width, bool split})>[
            (viewport: Size(900, 600), scale: 1, width: null, split: true),
            (viewport: Size(800, 480), scale: 1, width: null, split: true),
            (viewport: Size(480, 480), scale: 1, width: null, split: false),
            (viewport: Size(390, 844), scale: 1, width: null, split: false),
            (viewport: Size(600, 360), scale: 1, width: null, split: false),
            (viewport: Size(900, 600), scale: 1.6, width: null, split: false),
            // A large window can still host a narrow App pane.
            (viewport: Size(1200, 700), scale: 1, width: 520, split: false),
          ];
      for (final layout in cases) {
        tester.view.physicalSize = layout.viewport;
        AppLocale.instance.debugOverride(
          layout.scale > 1 ? AppUiLanguage.en : AppUiLanguage.zh,
        );
        await tester.pumpWidget(
          _adaptiveTeamApp(
            router,
            style,
            scale: layout.scale,
            width: layout.width,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final roster = tester.getRect(
          find.byKey(const Key('team-roster-pane')),
        );
        final details = tester.getRect(
          find.byKey(const Key('team-details-pane')),
        );
        if (layout.split) {
          expect(details.left, greaterThanOrEqualTo(roster.right + 13));
          expect(details.top, closeTo(roster.top, .01));
        } else {
          expect(details.left, closeTo(roster.left, .01));
          expect(details.top, greaterThanOrEqualTo(roster.bottom + 13));
        }
        // Six slots keep a compact two-row board instead of growing with width.
        expect(roster.height, lessThan(300 * layout.scale));
        expect(
          find.descendant(
            of: find.byType(PartyTeamBoard),
            matching: find.byType(HandheldFocusDecorator),
          ),
          findsNWidgets(6),
        );
        expect(tester.takeException(), isNull);
        final member = find.descendant(
          of: find.byType(PartyTeamBoard),
          matching: find.text('Alpha'),
        );
        await tester.ensureVisible(member);
        await tester.pump();
        await tester.tap(member);
        await _waitForTeamDetails(tester);
        final edit = find.text(AppZh.teamEditAction);
        await tester.ensureVisible(edit);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        if (_exportScreenshots &&
            layout.scale == 1 &&
            layout.width == null &&
            (layout.viewport == const Size(390, 844) ||
                layout.viewport == const Size(800, 480))) {
          final name =
              '${style.name}-${layout.viewport.width.toInt()}x${layout.viewport.height.toInt()}';
          if (layout.split) {
            // Show the summary and both panes together, not a viewport already
            // scrolled down to the selected inspector's edit action.
            await tester.ensureVisible(find.byType(TeamSummaryCard));
            await tester.pump(const Duration(milliseconds: 300));
          }
          await _captureTeam(tester, '$name-details');
          await tester.ensureVisible(edit);
          await tester.pump();
          await tester.tap(edit);
          await tester.pump(const Duration(milliseconds: 300));
          final nickname = find.widgetWithText(
            TextField,
            AppZh.teamEditNickname,
          );
          await tester.ensureVisible(nickname);
          await tester.pump(const Duration(milliseconds: 300));
          await _captureTeam(tester, '$name-editor');
          final cancel = find.byTooltip(AppZh.cancel);
          await tester.ensureVisible(cancel);
          await tester.pump();
          await tester.tap(cancel);
          await tester.pump(const Duration(milliseconds: 300));
        }
        final collapse = find.byKey(const Key('team-inspector-collapse'));
        await tester.ensureVisible(collapse);
        await tester.pump();
        await tester.tap(collapse);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.ensureVisible(find.byType(PartyTeamBoard));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
      'team editor keeps drafts and focus across rotation: ${style.name}',
      (tester) async {
        tester.view.physicalSize = const Size(900, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await appVisualStyle.setStyle(style);
        var journey = CurrentJourney.mock().copyWith(
          party: const [
            PartyMember(species: 'Alpha', nickname: 'First', level: 10),
            PartyMember(species: 'Beta', nickname: 'Second', level: 20),
          ],
          saveSyncedParty: const [],
        );
        var saves = 0;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => StatefulBuilder(
                builder: (context, rebuild) => TeamPage(
                  journey: journey,
                  onSaveJourney: (updated) => rebuild(() {
                    journey = updated;
                    saves++;
                  }),
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(_adaptiveTeamApp(router, style));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('First').first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text(AppZh.teamEditAction));
        await tester.pump(const Duration(milliseconds: 300));
        final nickname = find.widgetWithText(TextField, AppZh.teamEditNickname);
        final level = find.widgetWithText(TextField, AppZh.teamEditLevel);
        await tester.enterText(level, '44');
        await tester.enterText(nickname, 'Uncommitted');
        await tester.pump();
        final editableFinder = find.descendant(
          of: nickname,
          matching: find.byType(EditableText),
        );
        final original = tester.widget<EditableText>(editableFinder);
        final focusedNode = original.focusNode;
        expect(focusedNode.hasFocus, isTrue);

        for (final size in [const Size(390, 844), const Size(900, 600)]) {
          tester.view.physicalSize = size;
          await tester.pump(const Duration(milliseconds: 300));
          final editable = tester.widget<EditableText>(editableFinder);
          expect(editable.controller, same(original.controller));
          expect(editable.controller.text, 'Uncommitted');
          expect(tester.widget<TextField>(level).controller!.text, '44');
          expect(editable.focusNode, same(focusedNode));
          expect(FocusManager.instance.primaryFocus, same(focusedNode));
          expect(
            tester
                .widget<PartyTeamBoard>(find.byType(PartyTeamBoard))
                .selectedIndex,
            0,
          );
          expect(saves, 0);
          expect(tester.takeException(), isNull);
        }

        final confirm = find.text(AppZh.confirm).last;
        await tester.ensureVisible(confirm);
        await tester.pump();
        await tester.tap(confirm);
        await tester.pump(const Duration(milliseconds: 300));
        expect(journey.party.first.nickname, 'Uncommitted');
        expect(journey.party.first.level, 44);
        expect(saves, 1);

        // Reordering and cancel keep the selected member's existing inspector.
        final edit = find.text(AppZh.teamEditAction);
        await tester.ensureVisible(edit);
        await tester.pump();
        await tester.tap(edit);
        await tester.pump(const Duration(milliseconds: 300));
        final swap = find.text(AppZh.teamEditSwapNext);
        await tester.ensureVisible(swap);
        await tester.pump();
        await tester.tap(swap);
        await tester.pump(const Duration(milliseconds: 300));
        expect(journey.party[1].nickname, 'Uncommitted');
        expect(
          tester
              .widget<PartyTeamBoard>(find.byType(PartyTeamBoard))
              .selectedIndex,
          1,
        );
        final cancel = find.byTooltip(AppZh.cancel);
        await tester.ensureVisible(cancel);
        await tester.pump();
        await tester.tap(cancel);
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.widgetWithText(TextField, AppZh.teamEditNickname),
          findsNothing,
        );
        expect(
          find.byKey(const Key('team-inspector-collapse')),
          findsOneWidget,
        );
        expect(saves, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _adaptiveTeamApp(
  GoRouter router,
  AppVisualStyle style, {
  double scale = 1,
  double? width,
}) => RepaintBoundary(
  key: _auditBoundary,
  child: MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: _auditTheme(style),
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: HandheldInputShell(child: child!),
          ),
        ),
      ),
    ),
  ),
);

ThemeData _auditTheme(AppVisualStyle style) {
  final theme = buildTitoTheme(style);
  if (_auditFont.isEmpty) return theme;
  const fallback = ['Noto Sans CJK SC'];
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: theme.primaryTextTheme.apply(
      fontFamilyFallback: fallback,
    ),
    // Component themes hold their original TextStyle instances; updating the
    // inherited text theme does not replace these explicitly bound styles.
    chipTheme: theme.chipTheme.copyWith(
      labelStyle: (theme.chipTheme.labelStyle ?? theme.textTheme.labelMedium)
          ?.copyWith(fontFamilyFallback: fallback),
      secondaryLabelStyle:
          (theme.chipTheme.secondaryLabelStyle ?? theme.textTheme.labelMedium)
              ?.copyWith(fontFamilyFallback: fallback),
    ),
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      labelStyle:
          (theme.inputDecorationTheme.labelStyle ?? theme.textTheme.bodyLarge)
              ?.copyWith(fontFamilyFallback: fallback),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: (theme.filledButtonTheme.style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStatePropertyAll(
          theme.textTheme.labelLarge?.copyWith(fontFamilyFallback: fallback),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: (theme.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStatePropertyAll(
          theme.textTheme.labelLarge?.copyWith(fontFamilyFallback: fallback),
        ),
      ),
    ),
  );
}

Future<void> _loadAuditFonts() async {
  if (_auditFont.isEmpty) return;
  await (FontLoader('Noto Sans CJK SC')..addFont(
        Future.value(ByteData.sublistView(File(_auditFont).readAsBytesSync())),
      ))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  final nunito = FontLoader('Nunito');
  for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    nunito.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
  }
  await nunito.load();
}

Future<void> _waitForTeamDetails(WidgetTester tester) async {
  final pane = find.byKey(const Key('team-details-pane'));
  final loadedName = find.descendant(of: pane, matching: find.text('Alpha'));
  // pumpAndSettle alone cannot complete file I/O under the fake test clock.
  // Poll the actual content, with a bound so regressions fail instead of
  // silently exporting a loading panel or waiting on a network timeout.
  for (
    var attempt = 0;
    attempt < 100 && loadedName.evaluate().isEmpty;
    attempt++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(loadedName, findsOneWidget);
  expect(
    find.descendant(of: pane, matching: find.byType(TitoLoadingPanel)),
    findsNothing,
  );
  expect(
    find.descendant(of: pane, matching: find.text(AppZh.teamHeldItem('测试道具'))),
    findsOneWidget,
  );
  expect(
    find.descendant(of: pane, matching: find.byType(ActionChip)),
    findsOneWidget,
  );
}

Future<void> _captureTeam(WidgetTester tester, String name) async {
  if (!_exportScreenshots) return;
  await tester.runAsync(() async {
    final image = await tester
        .renderObject<RenderRepaintBoundary>(find.byKey(_auditBoundary))
        .toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/app-layout-audit').createSync(recursive: true);
      File(
        'build/app-layout-audit/team-$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
