import 'package:titodex/widgets/battle_party_results.dart';
import 'package:titodex/widgets/battle_team_editor.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/companion/battle_handoff.dart';
import 'package:titodex/features/companion/battle_tools_service.dart';
import 'package:titodex/features/dex/dex_cache_store.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_repository.dart';
import 'package:titodex/features/companion/battle_math.dart';
import 'package:titodex/features/dex/type_chart.dart';
import 'package:titodex/features/game/game_edition_repository.dart';
import 'package:titodex/l10n/app_locale.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/companion/battle_calc_page.dart';
import 'package:titodex/widgets/battle_tool_panels.dart';
import 'package:titodex/widgets/battle_team_panel.dart';
import 'package:titodex/widgets/battle_party_picker.dart';
import 'package:titodex/widgets/companion_tool_fields.dart';
import 'package:titodex/widgets/tito_page_container.dart';
import 'package:titodex/widgets/type_badge.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_theme.dart';

const _font = String.fromEnvironment('UI_AUDIT_CJK_FONT');
const _boundary = ValueKey('battle-audit-boundary');
const _partyPokemon = PokemonSummary(
  id: 25,
  nameEn: 'Pikachu',
  nameZh: '皮卡丘',
  types: ['electric'],
);
const _party = [
  PartyMember(
    species: '皮卡丘',
    speciesId: 25,
    nickname: '进攻队员',
    moveIds: [85, 98, 86, 99999],
    level: 70,
    nature: '内敛',
    abilitySlug: 'static',
    types: ['electric'],
    ivs: [1, 2, 3, 4, 5, 6],
    evs: [4, 8, 12, 16, 20, 24],
  ),
  PartyMember(
    species: '皮卡丘',
    speciesId: 25,
    nickname: '防守队员',
    level: 60,
    nature: '认真',
    abilitySlug: 'static',
    types: ['electric'],
    ivs: [31, 31, 31, 31, 31, 31],
    evs: [252, 0, 252, 0, 0, 0],
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    final documents = Directory('build/battle-audit-fixture').absolute;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => documents.path,
        );
    final relations = <String, TypeDamageRelations>{
      for (final type in typeGridOrder)
        type: const TypeDamageRelations(
          doubleDamageTo: {},
          halfDamageTo: {},
          noDamageTo: {},
        ),
      'fire': const TypeDamageRelations(
        doubleDamageTo: {'grass', 'ice', 'bug', 'steel'},
        halfDamageTo: {'fire', 'water', 'rock', 'dragon'},
        noDamageTo: {},
      ),
      'water': const TypeDamageRelations(
        doubleDamageTo: {'fire', 'ground', 'rock'},
        halfDamageTo: {'water', 'grass', 'dragon'},
        noDamageTo: {},
      ),
      'electric': const TypeDamageRelations(
        doubleDamageTo: {'water', 'flying'},
        halfDamageTo: {'electric', 'grass', 'dragon'},
        noDamageTo: {'ground'},
      ),
      'grass': const TypeDamageRelations(
        doubleDamageTo: {'water', 'ground', 'rock'},
        halfDamageTo: {
          'fire',
          'grass',
          'poison',
          'flying',
          'bug',
          'dragon',
          'steel',
        },
        noDamageTo: {},
      ),
      'ground': const TypeDamageRelations(
        doubleDamageTo: {'fire', 'electric', 'poison', 'rock', 'steel'},
        halfDamageTo: {'grass', 'bug'},
        noDamageTo: {'flying'},
      ),
      'rock': const TypeDamageRelations(
        doubleDamageTo: {'fire', 'ice', 'flying', 'bug'},
        halfDamageTo: {'fighting', 'ground', 'steel'},
        noDamageTo: {},
      ),
      'normal': const TypeDamageRelations(
        doubleDamageTo: {},
        halfDamageTo: {'rock', 'steel'},
        noDamageTo: {'ghost'},
      ),
      'ice': const TypeDamageRelations(
        doubleDamageTo: {'grass', 'ground', 'flying', 'dragon'},
        halfDamageTo: {'fire', 'water', 'ice', 'steel'},
        noDamageTo: {},
      ),
      'fighting': const TypeDamageRelations(
        doubleDamageTo: {'normal', 'ice', 'rock', 'dark', 'steel'},
        halfDamageTo: {'poison', 'flying', 'psychic', 'bug', 'fairy'},
        noDamageTo: {'ghost'},
      ),
      'poison': const TypeDamageRelations(
        doubleDamageTo: {'grass', 'fairy'},
        halfDamageTo: {'poison', 'ground', 'rock', 'ghost'},
        noDamageTo: {'steel'},
      ),
      'flying': const TypeDamageRelations(
        doubleDamageTo: {'grass', 'fighting', 'bug'},
        halfDamageTo: {'electric', 'rock', 'steel'},
        noDamageTo: {},
      ),
      'psychic': const TypeDamageRelations(
        doubleDamageTo: {'fighting', 'poison'},
        halfDamageTo: {'psychic', 'steel'},
        noDamageTo: {'dark'},
      ),
      'bug': const TypeDamageRelations(
        doubleDamageTo: {'grass', 'psychic', 'dark'},
        halfDamageTo: {
          'fire',
          'fighting',
          'poison',
          'flying',
          'ghost',
          'steel',
          'fairy',
        },
        noDamageTo: {},
      ),
      'ghost': const TypeDamageRelations(
        doubleDamageTo: {'psychic', 'ghost'},
        halfDamageTo: {'dark'},
        noDamageTo: {'normal'},
      ),
      'dragon': const TypeDamageRelations(
        doubleDamageTo: {'dragon'},
        halfDamageTo: {'steel'},
        noDamageTo: {'fairy'},
      ),
      'dark': const TypeDamageRelations(
        doubleDamageTo: {'psychic', 'ghost'},
        halfDamageTo: {'fighting', 'dark', 'fairy'},
        noDamageTo: {},
      ),
      'steel': const TypeDamageRelations(
        doubleDamageTo: {'ice', 'rock', 'fairy'},
        halfDamageTo: {'fire', 'water', 'electric', 'steel'},
        noDamageTo: {},
      ),
      'fairy': const TypeDamageRelations(
        doubleDamageTo: {'fighting', 'dragon', 'dark'},
        halfDamageTo: {'fire', 'poison', 'steel'},
        noDamageTo: {},
      ),
    };
    await DexCacheStore().writeTypeRelations(relations);
    await DexCacheStore().writeSummaries([_partyPokemon]);
    await DexCacheStore().writeMoves({
      85: const CachedMove(
        id: 85,
        nameEn: 'Thunderbolt',
        nameZh: '十万伏特',
        type: 'electric',
        category: 'special',
        power: 90,
      ),
      98: const CachedMove(
        id: 98,
        nameEn: 'Quick Attack',
        nameZh: '电光一闪',
        type: 'normal',
        category: 'physical',
        power: 40,
      ),
      86: const CachedMove(
        id: 86,
        nameEn: 'Thunder Wave',
        nameZh: '电磁波',
        type: 'electric',
        category: 'status',
      ),
    });
    await DexCacheStore().writeManifest(
      const DexCacheManifest(
        version: DexCacheManifest.currentVersion,
        complete: false,
        preferOffline: true,
        pokemonCount: 1,
      ),
    );
    await DexCacheStore().writeDetail(
      25,
      const PokemonDetail(
        summary: _partyPokemon,
        genusZh: '',
        heightDm: 4,
        weightHg: 60,
        weaknesses: [],
        resistances: [],
        immunities: [],
        stabSuperEffective: [],
        evolutionChain: null,
        baseStats: PokemonBaseStats(
          hp: 35,
          attack: 55,
          defense: 40,
          specialAttack: 50,
          specialDefense: 50,
          speed: 90,
        ),
        moveSets: {
          'scarlet-violet': PokemonMoveSet(
            machine: [
              PokemonMove(
                move: CachedMove(
                  id: 85,
                  nameEn: 'Thunderbolt',
                  nameZh: '十万伏特',
                  type: 'electric',
                  category: 'special',
                  power: 90,
                ),
                method: 'machine',
              ),
              PokemonMove(
                move: CachedMove(
                  id: 98,
                  nameEn: 'Quick Attack',
                  nameZh: '电光一闪',
                  type: 'normal',
                  category: 'physical',
                  power: 40,
                ),
                method: 'level-up',
              ),
              PokemonMove(
                move: CachedMove(
                  id: 86,
                  nameEn: 'Thunder Wave',
                  nameZh: '电磁波',
                  type: 'electric',
                  category: 'status',
                ),
                method: 'machine',
              ),
            ],
          ),
        },
        abilities: [
          PokemonAbility(nameEn: 'Static', nameZh: '静电', descriptionZh: ''),
        ],
      ),
    );
    await battleToolsService.loadTypeRelations();
    // Resolve platform/file futures before entering the widget fake clock.
    await dexRepository.getSummary(25);
    await dexRepository.getDetail(25);
    await dexRepository.getAllMoves();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugOverride(AppUiLanguage.zh);
    battlePartyHandoff.clear();
    await gameEditionRepository.saveSlug('sv');
  });
  tearDown(() async {
    AppLocale.instance.debugOverride(AppUiLanguage.zh);
    await appVisualStyle.setStyle(AppVisualStyle.classic);
    battlePartyHandoff.clear();
  });

  testWidgets('matchup table retains exact modifiers and all neutral types', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTitoTheme(),
        home: const Scaffold(
          body: BattleMatchupSummary(
            multipliers: {
              'rock': 4,
              'water': 2,
              'fire': .5,
              'grass': .25,
              'ground': 0,
              'normal': 1,
              'ice': 1.5,
              'bug': .75,
            },
          ),
        ),
      ),
    );
    for (final text in ['4×', '2×', '1×', '½×', '¼×', '0×', '1.5×', '0.75×']) {
      expect(find.text(text), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  for (final style in AppVisualStyle.values) {
    testWidgets(
      '${style.name}: all four tools scroll results and keep sides adjacent',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(400, 850);
        addTearDown(tester.view.reset);
        await _loadFonts();
        await appVisualStyle.setStyle(style);
        final router = _router();
        await tester.pumpWidget(_app(router, style));
        await tester.pumpAndSettle();
        for (final mode in BattleCalcMode.values) {
          await tester.tap(find.text(_label(mode)).first);
          await tester.pumpAndSettle();
          if (mode == BattleCalcMode.matchup) {
            // Exercise the real manual picker, not a state-only test setter.
            final defender = find.byType(LinkedOrManualTypePicker).last;
            final expand = find.descendant(
              of: defender,
              matching: find.byIcon(Icons.expand_more_rounded),
            );
            await _reveal(tester, expand);
            await tester.pumpAndSettle();
            await tester.tap(expand);
            await tester.pumpAndSettle();
            final flying = find.descendant(
              of: defender,
              matching: find.byWidgetPredicate(
                (w) => w is TypeIconImage && w.typeEn == 'flying',
              ),
            );
            await _reveal(tester, flying);
            await tester.pumpAndSettle();
            await tester.tap(flying);
            await tester.pumpAndSettle();
            tester
                .widget<ListView>(find.byType(ListView))
                .controller!
                .jumpTo(0);
            await tester.pumpAndSettle();
            final summary = tester.widget<BattleMatchupSummary>(
              find.byType(BattleMatchupSummary),
            );
            expect(summary.multipliers['rock'], 4);
            expect(summary.multipliers['ground'], 0);
            final collapse = find.descendant(
              of: defender,
              matching: find.byIcon(Icons.expand_less_rounded),
            );
            await _reveal(tester, collapse);
            await tester.pumpAndSettle();
            await tester.tap(collapse);
            await tester.pumpAndSettle();
            await tester.drag(find.byType(ListView), const Offset(0, 800));
            await tester.pumpAndSettle();
          }
          expect(find.byKey(const ValueKey('battle-result')), findsOneWidget);
          if (mode != BattleCalcMode.stats) {
            final left = tester.getRect(find.text(AppZh.battleAttacker));
            final right = tester.getRect(
              find.text(AppZh.companionTypeDefenderTitle),
            );
            expect(left.left, lessThan(right.left));
            expect(left.top, closeTo(right.top, 1));
          }
          final before = tester.getTopLeft(
            find.byKey(const ValueKey('battle-result')),
          );
          await _capture(tester, '${style.name}-${mode.name}');
          await tester.drag(find.byType(ListView), const Offset(0, -240));
          await tester.pumpAndSettle();
          final full = find.byKey(const ValueKey('battle-result'));
          final controller = tester
              .widget<ListView>(find.byType(ListView))
              .controller!;
          if (controller.position.maxScrollExtent == 0) {
            // The slimmer selectors allow the short blind-spot page to fit.
            expect(controller.offset, 0);
          } else if (full.evaluate().isNotEmpty) {
            expect(tester.getTopLeft(full), isNot(before));
          } else {
            expect(
              find.byKey(const ValueKey('battle-result-summary')),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      },
    );
  }

  testWidgets(
    'small screen, handheld and large English text retain reachable controls',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final config in [
        (const Size(320, 640), 1.0, AppUiLanguage.zh, 0.0),
        (const Size(720, 720), 1.0, AppUiLanguage.zh, 0.0),
        (const Size(360, 740), 1.4, AppUiLanguage.en, 280.0),
      ]) {
        tester.view.physicalSize = config.$1;
        AppLocale.instance.debugOverride(config.$3);
        final router = _router();
        await tester.pumpWidget(
          _app(
            router,
            AppVisualStyle.classic,
            scale: config.$2,
            keyboard: config.$4,
          ),
        );
        await tester.pumpAndSettle();
        for (final mode in BattleCalcMode.values) {
          await tester.tap(find.text(_label(mode)).first);
          await tester.pumpAndSettle();
          final inputs = find.byType(ListView);
          expect(tester.getSize(inputs).height, greaterThan(90));
          await tester.drag(inputs, const Offset(0, -450));
          await tester.pumpAndSettle();
          if (mode == BattleCalcMode.damage) {
            for (final id in ['attacker', 'defender', 'field']) {
              final more = find.byKey(PageStorageKey('battle-more-$id'));
              await tester.scrollUntilVisible(
                more,
                id == 'field' ? 180 : -180,
                scrollable: find
                    .descendant(of: inputs, matching: find.byType(Scrollable))
                    .first,
                maxScrolls: 30,
              );
              final heading = find
                  .descendant(of: more, matching: find.byType(ListTile))
                  .first;
              await _reveal(tester, heading);
              await tester.pumpAndSettle();
              await tester.tap(heading);
              await tester.pumpAndSettle();
              await tester.drag(inputs, const Offset(0, -220));
              await tester.pumpAndSettle();
            }
          }
          expect(
            tester.takeException(),
            isNull,
            reason: '${config.$1}, ${mode.name}',
          );
        }
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      }
    },
  );

  testWidgets('party choices share roles and six stats across every tab', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 850);
    addTearDown(tester.view.reset);
    final router = _router(party: _party);
    await tester.pumpWidget(_app(router, AppVisualStyle.classic));
    await tester.pumpAndSettle();
    for (final entry in [(0, '进攻队员'), (1, '防守队员')]) {
      final draft = tester
          .widget<BattlePartyPicker>(
            find.byType(BattlePartyPicker).at(entry.$1),
          )
          .combatant;
      await tester.tap(find.text(AppZh.battleChooseParty).at(entry.$1));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.$2));
      await tester.pump();
      // Cached dex data still uses real asynchronous file I/O.
      await tester.runAsync(() async {
        final end = DateTime.now().add(const Duration(seconds: 5));
        while (draft.loading && DateTime.now().isBefore(end)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      expect(draft.loading, isFalse);
      expect(draft.selectionFailed, isFalse);
      await tester.pumpAndSettle();
    }
    await _capture(tester, 'party-selection');
    for (final mode in [
      BattleCalcMode.blind,
      BattleCalcMode.damage,
      BattleCalcMode.matchup,
    ]) {
      await tester.tap(find.text(_label(mode)));
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<PokemonSearchField>(find.byType(PokemonSearchField))
          .toList();
      expect(fields.map((f) => f.controller.text), ['进攻队员', '防守队员']);
      if (mode == BattleCalcMode.damage) {
        final level = tester.widget<CompanionNumberField>(
          find.widgetWithText(CompanionNumberField, AppZh.companionStatLevel),
        );
        expect(level.controller.text, '70');
      }
    }
    await tester.tap(find.text(AppZh.battleCalcModeStats));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CompanionSelectField<bool>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppZh.companionTypeDefenderTitle).last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PokemonSearchField>(find.byType(PokemonSearchField))
          .controller
          .text,
      '防守队员',
    );
    final level = find.widgetWithText(
      CompanionNumberField,
      AppZh.companionStatLevel,
    );
    expect(tester.widget<CompanionNumberField>(level).controller.text, '60');
    await tester.enterText(
      find.descendant(of: level, matching: find.byType(TextField)),
      '80',
    );
    await tester.pumpAndSettle();
    final statPicker = tester.widget<StatPicker>(find.byType(StatPicker));
    statPicker.onChanged(BattleStat.specialDefense);
    await tester.pumpAndSettle();
    final defenseResult = tester
        .widget<Text>(find.byKey(const ValueKey('battle-stat-value')))
        .data;
    await tester.tap(find.text(AppZh.battleViewDamage));
    await tester.pumpAndSettle();
    final defense = find.widgetWithText(
      CompanionNumberField,
      AppZh.companionSpDefenseStat,
    );
    expect(
      tester.widget<CompanionNumberField>(defense).controller.text,
      defenseResult,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });

  testWidgets('team analysis persists between matchup and blind tabs', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.reset);
    final router = _router(party: _party);
    await tester.pumpWidget(
      _app(router, AppVisualStyle.solidPlastic, scale: 1.4),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('battle-scope')),
        matching: find.text(AppZh.battleTeamAnalysis),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => tester
          .widget<BattleTeamPanel>(find.byType(BattleTeamPanel))
          .session
          .partyEntries(_party),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BattleTeamPanel), findsOneWidget);
    expect(find.text('${AppZh.battleTeamAnalysis} · 2/2'), findsOneWidget);
    expect(find.text('进攻队员'), findsOneWidget);
    await tester.tap(find.text(AppZh.battleCalcModeBlind));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => tester
          .widget<BattleTeamPanel>(find.byType(BattleTeamPanel))
          .session
          .partyEntries(_party),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BattleTeamPanel), findsOneWidget);
    expect(find.text('${AppZh.battleTeamAnalysis} · 2/2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(_app(router, AppVisualStyle.solidPlastic));
    await tester.pumpAndSettle();
    await _capture(tester, 'party-analysis');
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });

  for (final style in AppVisualStyle.values) {
    testWidgets(
      '${style.name}: party stats and assigned moves share current defender',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(400, 850);
        addTearDown(tester.view.reset);
        await _loadFonts();
        await appVisualStyle.setStyle(style);
        final router = _router(party: _party);
        await tester.pumpWidget(_app(router, style));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('battle-scope')),
            matching: find.text(AppZh.battleTeamAnalysis),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppZh.battleCalcModeStats));
        await tester.pump();
        final panel = tester.widget<BattlePartyResults>(
          find.byType(BattlePartyResults),
        );
        await tester.runAsync(() => panel.session.partyEntries(_party));
        await tester.pumpAndSettle();
        expect(find.byType(BattleTeamEditor), findsOneWidget);
        expect(find.text(AppZh.battleTeamStats), findsOneWidget);
        expect(
          find.text('Lv. 70', findRichText: true),
          findsNothing,
        ); // Value is part of the row label.
        await _capture(tester, '${style.name}-party-stats');
        await tester.tap(find.text(AppZh.battleCalcModeDamage));
        await tester.pumpAndSettle();
        expect(find.text(AppZh.battleTeamDamage), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BattlePartyResults),
            matching: find.textContaining('十万伏特'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining(AppZh.battleTeamNoMoves), findsOneWidget);
        expect(
          find.widgetWithText(CompanionNumberField, AppZh.companionDefenseStat),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(
            CompanionNumberField,
            AppZh.companionSpDefenseStat,
          ),
          findsOneWidget,
        );
        final before = tester
            .widget<Text>(
              find.descendant(
                of: find.byType(BattlePartyResults),
                matching: find.textContaining('十万伏特'),
              ),
            )
            .data;
        panel.session.defender.raw[BattleStat.specialDefense]!.text = '999';
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(
                find.descendant(
                  of: find.byType(BattlePartyResults),
                  matching: find.textContaining('电光一闪'),
                ),
              )
              .data,
          isNot(before),
        );
        panel.session.defender.raw[BattleStat.specialDefense]!.text = '120';
        await tester.pumpAndSettle();
        await _capture(tester, '${style.name}-party-damage');
        await tester.tap(
          find.descendant(
            of: find.byType(BattlePartyResults),
            matching: find.text('进攻队员'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining(AppZh.battleTeamMoveMissing), findsNothing);
        expect(find.textContaining('当前世代资料不足或不是伤害招式'), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.view.physicalSize = const Size(320, 640);
        await tester.pumpWidget(_app(router, style, scale: 1.4));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      },
    );
  }

  testWidgets(
    'compact roster edits update the shared team without changing Party',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 850);
      addTearDown(tester.view.reset);
      final source = [..._party, ..._party, ..._party];
      final router = _router(party: source);
      await tester.pumpWidget(_app(router, AppVisualStyle.classic));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppZh.battleCalcModeStats));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('battle-scope')),
          matching: find.text(AppZh.battleTeamAnalysis),
        ),
      );
      await tester.pump();
      final panel = tester.widget<BattlePartyResults>(
        find.byType(BattlePartyResults),
      );
      final entries = await tester.runAsync(
        () => panel.session.partyEntries(source),
      );
      await tester.pumpAndSettle();
      final board = find.byType(BattleTeamEditor);
      await _reveal(tester, board);
      await tester.pumpAndSettle();
      expect(tester.getSize(board).height, lessThan(310));
      expect(
        tester.getRect(find.byKey(const ValueKey('battle-team-slot-5'))).bottom,
        lessThanOrEqualTo(850),
      );
      for (var i = 0; i < 6; i++) {
        expect(find.byKey(ValueKey('battle-team-slot-$i')), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('battle-team-slot-0')));
      await tester.pumpAndSettle();
      final level = find.widgetWithText(
        CompanionNumberField,
        AppZh.companionStatLevel,
      );
      await tester.enterText(
        find.descendant(of: level, matching: find.byType(TextField)),
        '80',
      );
      await tester.pumpAndSettle();
      expect(entries!.first.combatant.level.text, '80');
      expect(_party.first.level, 70);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppZh.battleCalcModeBlind));
      await tester.pumpAndSettle();
      expect(
        identical(
          await tester.runAsync(() => panel.session.partyEntries(source)),
          entries,
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    },
  );

  testWidgets('stat edit updates fixed result and handoff selects damage tab', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 850);
    addTearDown(tester.view.reset);
    final router = _router();
    await tester.pumpWidget(_app(router, AppVisualStyle.classic));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppZh.battleCalcModeStats));
    await tester.pumpAndSettle();
    final result = find.byKey(const ValueKey('battle-stat-value'));
    final before = tester.widget<Text>(result).data;
    final level = find.widgetWithText(
      CompanionNumberField,
      AppZh.companionStatLevel,
    );
    await tester.enterText(
      find.descendant(of: level, matching: find.byType(TextField)),
      '75',
    );
    await tester.pumpAndSettle();
    final after = tester.widget<Text>(result).data;
    expect(after, isNot(before));
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('battle-result')),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();
    final attack = find.widgetWithText(
      CompanionNumberField,
      AppZh.companionAttackStat,
    );
    expect(tester.widget<CompanionNumberField>(attack).controller.text, after);
    await tester.tap(find.text(AppZh.battleCalcModeStats));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(result).data, after);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
}

String _label(BattleCalcMode mode) => switch (mode) {
  BattleCalcMode.matchup => AppZh.battleCalcModeMatchup,
  BattleCalcMode.stats => AppZh.battleCalcModeStats,
  BattleCalcMode.damage => AppZh.battleCalcModeDamage,
  BattleCalcMode.blind => AppZh.battleCalcModeBlind,
};

GoRouter _router({List<PartyMember> party = const []}) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => TitoPageContainer(
        child: BattleCalcPage(
          journey: CurrentJourney.mock().copyWith(party: party),
        ),
      ),
    ),
  ],
);

Widget _app(
  GoRouter router,
  AppVisualStyle style, {
  double scale = 1,
  double keyboard = 0,
}) {
  var theme = buildTitoTheme(style);
  if (_font.isNotEmpty) {
    const fallback = ['Noto Sans CJK SC'];
    theme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamilyFallback: fallback),
      primaryTextTheme: theme.primaryTextTheme.apply(
        fontFamilyFallback: fallback,
      ),
      chipTheme: theme.chipTheme.copyWith(
        labelStyle: (theme.chipTheme.labelStyle ?? theme.textTheme.labelLarge)
            ?.copyWith(fontFamilyFallback: fallback),
        secondaryLabelStyle:
            (theme.chipTheme.secondaryLabelStyle ?? theme.textTheme.labelLarge)
                ?.copyWith(fontFamilyFallback: fallback),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: (theme.filledButtonTheme.style ?? const ButtonStyle()).copyWith(
          textStyle: WidgetStatePropertyAll(
            theme.textTheme.labelLarge?.copyWith(fontFamilyFallback: fallback),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: (theme.textButtonTheme.style ?? const ButtonStyle()).copyWith(
          textStyle: WidgetStatePropertyAll(
            theme.textTheme.labelLarge?.copyWith(fontFamilyFallback: fallback),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: (theme.segmentedButtonTheme.style ?? const ButtonStyle())
            .copyWith(
              textStyle: WidgetStatePropertyAll(
                theme.textTheme.labelLarge?.copyWith(
                  fontFamilyFallback: fallback,
                ),
              ),
            ),
      ),
      listTileTheme: theme.listTileTheme.copyWith(
        titleTextStyle:
            (theme.listTileTheme.titleTextStyle ?? theme.textTheme.bodyLarge)
                ?.copyWith(fontFamilyFallback: fallback),
      ),
    );
  }
  return RepaintBoundary(
    key: _boundary,
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
}

Future<void> _loadFonts() async {
  if (_font.isEmpty) return;
  final cjk = FontLoader(
    'Noto Sans CJK SC',
  )..addFont(Future.value(ByteData.sublistView(File(_font).readAsBytesSync())));
  await cjk.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  final nunito = FontLoader('Nunito');
  for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    nunito.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
  }
  await nunito.load();
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (_font.isEmpty) return;
  await tester.runAsync(() async {
    final image = await tester
        .renderObject<RenderRepaintBoundary>(find.byKey(_boundary))
        .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/battle-audit').createSync(recursive: true);
    File(
      'build/battle-audit/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _reveal(WidgetTester tester, Finder finder) =>
    Scrollable.ensureVisible(tester.element(finder), alignment: .35);
