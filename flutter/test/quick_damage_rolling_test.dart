import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/companion/battle_handoff.dart';
import 'package:titodex/features/companion/battle_session.dart';
import 'package:titodex/features/companion/battle_tools_service.dart';
import 'package:titodex/features/dex/dex_cache_store.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/type_chart.dart';
import 'package:titodex/features/game/game_edition_repository.dart';
import 'package:titodex/l10n/app_locale.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/companion/quick_damage_page.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/motion_preferences.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/battle_move_picker.dart';
import 'package:titodex/widgets/companion_tool_fields.dart';
import 'package:titodex/widgets/tito_animated_number.dart';
import 'package:titodex/widgets/tito_rolling_value.dart';

const _font = String.fromEnvironment('UI_AUDIT_CJK_FONT');
const _typeSlot = ValueKey('damage-type-multiplier');
const _stabSlot = ValueKey('damage-stab-multiplier');
const _modifiers = ValueKey('damage-modifiers');
const _move = CachedMove(
  id: 85,
  nameEn: 'Thunderbolt',
  nameZh: '十万伏特',
  type: 'electric',
  category: 'special',
  power: 90,
);
const _pokemon = PokemonSummary(
  id: 25,
  nameEn: 'Pikachu',
  nameZh: '皮卡丘',
  types: ['electric'],
);
const _detail = PokemonDetail(
  summary: _pokemon,
  genusZh: '',
  heightDm: 4,
  weightHg: 60,
  weaknesses: [],
  resistances: [],
  immunities: [],
  stabSuperEffective: [],
  evolutionChain: null,
  moveSets: {
    'scarlet-violet': PokemonMoveSet(
      machine: [PokemonMove(move: _move, method: 'machine')],
    ),
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final documents = Directory('build/quick-damage-rolling-fixture').absolute;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => documents.path,
        );
    await DexCacheStore().writeTypeRelations({
      for (final type in typeGridOrder)
        type: const TypeDamageRelations(
          doubleDamageTo: {},
          halfDamageTo: {},
          noDamageTo: {},
        ),
      'electric': const TypeDamageRelations(
        doubleDamageTo: {'water', 'flying'},
        halfDamageTo: {'electric', 'grass', 'dragon'},
        noDamageTo: {'ground'},
      ),
    });
    await battleToolsService.loadTypeRelations();
    final nunito = FontLoader('Nunito');
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      nunito.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
    }
    await nunito.load();
    if (_font.isNotEmpty) {
      await (FontLoader('Noto Sans CJK SC')..addFont(
            Future.value(ByteData.sublistView(File(_font).readAsBytesSync())),
          ))
          .load();
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugOverride(AppUiLanguage.zh);
    TitoAnimatedNumberState.debugResetMemory();
    battlePartyHandoff.clear();
    await gameEditionRepository.saveSlug('sv');
    await motionPreferences.setListAnimationsEnabled(true);
  });
  tearDown(() async {
    AppLocale.instance.debugOverride(AppUiLanguage.zh);
    battlePartyHandoff.clear();
    await appVisualStyle.setStyle(AppVisualStyle.classic);
    await motionPreferences.setListAnimationsEnabled(true);
  });

  testWidgets('switching defender rolls the damage digits in place', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.reset);
    final session = _session();
    addTearDown(session.dispose);
    await _openEstimate(tester, session, AppVisualStyle.classic);
    final hero = find.byKey(const ValueKey('damage-hero-max'));
    final state = tester.state<TitoAnimatedNumberState>(hero);
    final before = state.displayedText;
    session.defender.pokemonId = 130;
    session.defender.types = ['water', 'flying'];
    session.changed();
    await tester.pump();
    // Same slot, continuing from the old reading rather than from 0%.
    expect(tester.state(hero), same(state));
    expect(state.displayedText, before);
    await tester.pump(const Duration(milliseconds: 16));
    expect(state.displayedText, isNot('0%'));
    await tester.pumpAndSettle();
    expect(state.displayedText, isNot(before));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('real damage edits roll exact modifiers with final semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 480);
      addTearDown(tester.view.reset);
      AppLocale.instance.debugOverride(AppUiLanguage.en);
      final session = _session();
      addTearDown(session.dispose);
      await _openEstimate(tester, session, AppVisualStyle.classic);
      final type = find.byKey(_typeSlot);
      final stab = find.byKey(_stabSlot);
      final typeState = tester.state(type);
      final typeIdentity = tester.widget<TitoRollingValue>(type).identity;
      final label = find.text('Type ×');
      final labelElement = tester.element(label);
      expect(_texts(tester, type), {'2'});
      expect(_texts(tester, stab), {'1.5'});

      // Exercise the same callback that clears a linked species during manual edits.
      tester
          .widgetList<LinkedOrManualTypePicker>(
            find.byType(LinkedOrManualTypePicker),
          )
          .last
          .onManualChanged(['grass']);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(session.defender.pokemonId, isNull);
      expect(tester.state(type), same(typeState));
      expect(tester.widget<TitoRollingValue>(type).identity, typeIdentity);
      expect(tester.element(label), same(labelElement));
      expect(_texts(tester, type), {'2', '1/2'});
      expect(_texts(tester, stab), {'1.5'});
      expect(
        tester.getSemantics(find.byKey(_modifiers)).label,
        'Type ×1/2 · STAB ×1.5 · roll 85%–100%',
      );
      await tester.pump(const Duration(milliseconds: 151));
      expect(_texts(tester, type), {'1/2'});

      session.defender.types = ['grass', 'dragon'];
      session.changed();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(_texts(tester, type), {'1/2', '1/4'});
      await tester.pump(const Duration(milliseconds: 151));
      expect(_texts(tester, type), {'1/4'});

      session.defender.types = ['water'];
      session.defender.abilitySlug = 'filter';
      session.attacker.abilitySlug = 'adaptability';
      session.attacker.terastallized = true;
      session.attacker.teraType = 'electric';
      session.changed();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      // Filter is reported separately as an extra modifier, not as type 1.5.
      expect(_texts(tester, type), {'1/4', '2'});
      expect(_texts(tester, stab), {'1.5', '2.25'});
      expect(find.text(AppZh.companionDamageExtra('0.75')), findsOneWidget);
      expect(tester.element(label), same(labelElement));
      expect(
        tester.getSemantics(find.byKey(_modifiers)).label,
        'Type ×2 · STAB ×2.25 · roll 85%–100%',
      );
      await tester.pump(const Duration(milliseconds: 151));
      expect(_texts(tester, type), {'2'});
      expect(_texts(tester, stab), {'2.25'});

      session.attacker.abilitySlug = null;
      session.attacker.terastallized = false;
      session.attacker.types = ['normal'];
      session.changed();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(_texts(tester, stab), {'2.25', '1'});
      expect(
        tester.getSemantics(find.byKey(_modifiers)).label,
        'Type ×2 · STAB ×1 · roll 85%–100%',
      );
      await tester.pump(const Duration(milliseconds: 151));
      expect(_texts(tester, stab), {'1'});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
  });

  for (final style in AppVisualStyle.values) {
    testWidgets('${style.name}: damage card keeps its rows at 360px', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await appVisualStyle.setStyle(style);
      final session = _session();
      addTearDown(session.dispose);
      for (final (scale, language) in [
        (1.0, AppUiLanguage.zh),
        (1.4, AppUiLanguage.en),
      ]) {
        tester.view.physicalSize = const Size(360, 740);
        AppLocale.instance.debugOverride(language);
        await _openEstimate(tester, session, style, scale: scale);
        final verdict = find.byKey(const ValueKey('damage-verdict'));
        final title = find.text(AppZh.companionDamageResultTitle);
        final hero = find.byKey(const ValueKey('damage-hero-max'));
        final range = find.byKey(const ValueKey('damage-hp-range'));
        expect(verdict, findsOneWidget);
        // Verdict pill shares the title row; the hero number owns its row.
        expect(
          tester.getCenter(verdict).dy,
          closeTo(tester.getCenter(title).dy, 6),
        );
        expect(tester.getRect(verdict).right, lessThanOrEqualTo(360));
        expect(
          tester.getRect(hero).top,
          greaterThanOrEqualTo(tester.getRect(verdict).bottom),
        );
        expect(
          tester.getRect(range).top,
          greaterThan(tester.getRect(hero).bottom),
        );
        expect(
          tester.getRect(range).left,
          lessThan(tester.getRect(hero).right),
        );
        _expectModifierBounds(tester);
        expect(
          tester.getRect(find.byKey(_modifiers)).right,
          lessThanOrEqualTo(360),
        );
        expect(tester.takeException(), isNull, reason: '$scale $language');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      '${style.name}: wrapped modifiers survive large text and reduced motion',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        await appVisualStyle.setStyle(style);
        final session = _session();
        addTearDown(session.dispose);
        await _openEstimate(tester, session, style, scale: 1.8);
        final type = find.byKey(_typeSlot);
        final state = tester.state(type);
        _expectModifierBounds(tester);
        session.defender.types = ['grass', 'dragon'];
        session.changed();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        expect(_texts(tester, type), {'2', '1/4'});
        _expectModifierBounds(tester);
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();

        AppLocale.instance.debugOverride(AppUiLanguage.en);
        tester.view.physicalSize = const Size(800, 480);
        await tester.pumpWidget(
          _app(session, style, scale: 1.8, reduced: true),
        );
        session.defender.types = ['water'];
        session.defender.abilitySlug = 'filter';
        session.attacker.abilitySlug = 'adaptability';
        session.attacker.terastallized = true;
        session.attacker.teraType = 'electric';
        session.changed();
        await tester.pump();
        expect(tester.state(type), same(state));
        expect(_texts(tester, type), {'2'});
        expect(_texts(tester, find.byKey(_stabSlot)), {'2.25'});
        expect(find.text(AppZh.companionDamageExtra('0.75')), findsOneWidget);
        expect(find.text('Type ×'), findsOneWidget);
        expect(find.text('STAB ×'), findsOneWidget);
        expect(find.text('roll 85%–100%'), findsOneWidget);
        _expectModifierBounds(tester);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

BattleSession _session() {
  final session = BattleSession();
  session.attacker.pokemonId = 25;
  session.attacker.detail = _detail;
  session.attacker.types = ['electric'];
  session.attacker.query.text = 'Pikachu';
  session.defender.pokemonId = 129;
  session.defender.types = ['water'];
  return session;
}

Widget _app(
  BattleSession session,
  AppVisualStyle style, {
  double scale = 1,
  bool reduced = false,
}) => MaterialApp(
  theme: buildTitoTheme(style),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reduced,
    ),
    child: child!,
  ),
  home: Scaffold(
    body: QuickDamagePage(
      journey: CurrentJourney.mock().copyWith(party: const []),
      session: session,
      embedded: true,
    ),
  ),
);

Future<void> _openEstimate(
  WidgetTester tester,
  BattleSession session,
  AppVisualStyle style, {
  double scale = 1,
}) async {
  await tester.pumpWidget(_app(session, style, scale: scale));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byType(BattleMovePicker),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  tester
      .widget<BattleMovePicker>(find.byType(BattleMovePicker))
      .onChanged(_move);
  await tester.pump();
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
  expect(find.byKey(_typeSlot), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Set<String> _texts(WidgetTester tester, Finder slot) => tester
    .widgetList<Text>(find.descendant(of: slot, matching: find.byType(Text)))
    .map((text) => text.data!)
    .toSet();

void _expectModifierBounds(WidgetTester tester) {
  final modifiers = find.byKey(_modifiers);
  final bounds = tester.getRect(modifiers);
  final groups = tester.widget<Wrap>(
    find.descendant(of: modifiers, matching: find.byType(Wrap)),
  );
  for (final group in groups.children) {
    final rect = tester.getRect(find.byWidget(group));
    expect(rect.left, greaterThanOrEqualTo(bounds.left - .01));
    expect(rect.right, lessThanOrEqualTo(bounds.right + .01));
    expect(rect.bottom, lessThanOrEqualTo(bounds.bottom + .01));
  }
  expect(find.text(AppZh.companionDamageRandomRoll), findsOneWidget);
}
