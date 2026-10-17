import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/retro_style.dart';
import 'package:titodex/theme/tito_colors.dart';
import 'package:titodex/theme/tito_skin.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/handheld_input.dart';
import 'package:titodex/widgets/liquid_glass.dart';
import 'package:titodex/widgets/sticker_card.dart';
import 'package:titodex/widgets/tito_paper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await retroStyle.setEnabled(true);
  });

  tearDown(() async {
    await retroStyle.setEnabled(true);
    await appVisualStyle.setStyle(AppVisualStyle.classic);
  });

  test('every ThemeData registers the matching TitoSkin', () {
    for (final style in AppVisualStyle.values) {
      final skin = buildTitoTheme(style).extension<TitoSkin>();
      expect(skin, isNotNull, reason: style.name);
      expect(skin!.family, style.family);
      expect(skin, same(TitoSkin.forStyle(style)));
    }
  });

  test('theme taglines are Chinese by default with English fallbacks', () {
    const zh = Locale('zh');
    const en = Locale('en');
    expect(AppVisualStyle.classic.taglineFor(zh), '纸贴纸 · 胶带 · 印章');
    expect(AppVisualStyle.solidPlastic.taglineFor(zh), '半透外壳 · 压铸按键');
    expect(AppVisualStyle.flatUi.taglineFor(zh), '色块 · 大字 · 干脆');
    for (final style in AppVisualStyle.values) {
      expect(style.taglineFor(en), isNot(style.taglineFor(zh)));
      // Labels are unchanged by the skin refresh.
      expect(style.labelFor(zh), isNotEmpty);
    }
  });

  test('journal keeps the hard 0/5 sticker drop; flat has no shadow', () {
    final journal = TitoSkin.journal.cardShadow()!;
    expect(journal.first.offset, const Offset(0, 5));
    expect(journal.first.blurRadius, 0);
    expect(TitoSkin.flat.cardShadow(), isNull);
  });

  test('retro off removes journal and plastic card shadows', () async {
    await retroStyle.setEnabled(false);
    expect(TitoSkin.journal.cardShadow(), isNull);
    expect(TitoSkin.plastic.cardShadow(), isNull);
  });

  test('focus ring is per theme', () {
    const radius = BorderRadius.all(Radius.circular(12));
    Set<Color> ringColors(TitoSkin skin) =>
        skin.focusRing(radius).boxShadow!.map((s) => s.color).toSet();
    expect(ringColors(TitoSkin.journal), contains(TitoColors.softYellow));
    expect(ringColors(TitoSkin.flat), contains(TitoColors.flatOnSurface));
    expect(
      ringColors(TitoSkin.plastic),
      contains(Colors.white.withValues(alpha: 0xF2 / 255)),
    );
  });

  Future<void> pumpHero(WidgetTester tester, AppVisualStyle style) async {
    await appVisualStyle.setStyle(style);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTitoTheme(style),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: StickerCard.hero(child: Text('训练家')),
            ),
          ),
        ),
      ),
    );
    // MaterialApp animates theme swaps; the skin snaps at the midpoint.
    await tester.pumpAndSettle();
  }

  testWidgets('journal trainer hero gets tape and tilt; lists stay flat', (
    tester,
  ) async {
    await pumpHero(tester, AppVisualStyle.classic);
    expect(find.byType(TitoWashiTape), findsOneWidget);
    expect(
      find.ancestor(of: find.text('训练家'), matching: find.byType(Transform)),
      findsWidgets,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTitoTheme(),
        home: const Scaffold(body: StickerCard.dense(child: Text('列表'))),
      ),
    );
    expect(find.byType(TitoWashiTape), findsNothing);
  });

  testWidgets('plastic hero is a static gradient shell, flat hero is a block', (
    tester,
  ) async {
    await pumpHero(tester, AppVisualStyle.solidPlastic);
    expect(find.byType(LiquidGlassSurface), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(TitoWashiTape), findsNothing);

    await pumpHero(tester, AppVisualStyle.flatUi);
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(StickerCard),
        matching: find.byType(Material),
      ),
    );
    expect(material.elevation, 0);
    expect(material.color, TitoColors.softYellow);
  });

  testWidgets('focus decorator paints the skin ring without remounting', (
    tester,
  ) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    });
    final childKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTitoTheme(AppVisualStyle.flatUi),
        home: Scaffold(
          body: HandheldFocusDecorator(
            onActivate: () {},
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(key: childKey, width: 80, height: 40),
          ),
        ),
      ),
    );
    final before = childKey.currentContext;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final ring = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          ((widget.decoration as BoxDecoration).boxShadow ?? const []).any(
            (s) => s.color == TitoColors.flatOnSurface,
          ),
    );
    expect(ring, findsOneWidget);
    expect(childKey.currentContext, same(before));
  });
}
