import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/l10n/app_locale.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_colors.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/theme/tito_typography.dart';
import 'package:titodex/theme/trainer_journal.dart';
import 'package:titodex/widgets/journey_card.dart';
import 'package:titodex/widgets/journey_timeline.dart';
import 'package:titodex/widgets/party_strip.dart';
import 'package:titodex/widgets/party_team_list.dart';
import 'package:titodex/widgets/sticker_card.dart';
import 'package:titodex/theme/tito_buttons.dart';
import 'package:titodex/widgets/retro_forms.dart';
import 'package:titodex/widgets/tito_fact_grid.dart';
import 'package:titodex/widgets/trainer_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadBundledFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await appVisualStyle.setStyle(AppVisualStyle.classic);
    final previousLanguage = AppLocale.instance.language;
    AppLocale.instance.debugOverride(AppUiLanguage.zh);
    addTearDown(() => AppLocale.instance.debugOverride(previousLanguage));
  });

  test('Journal remaps weight without changing requested size', () {
    expect(TrainerJournal.weight(FontWeight.w800), FontWeight.w700);
    expect(TrainerJournal.weight(FontWeight.w700), FontWeight.w600);
    expect(TrainerJournal.weight(FontWeight.w600), FontWeight.w400);
    final style = TitoTypography.style(
      fontSize: 22.5,
      fontWeight: FontWeight.w800,
    );
    expect(style.fontSize, 22.5);
    expect(style.fontWeight, FontWeight.w700);
  });

  test('other themes keep historical weights and ink', () async {
    await appVisualStyle.setStyle(AppVisualStyle.solidPlastic);
    expect(TrainerJournal.weight(FontWeight.w800), FontWeight.w800);
    final style = TitoTypography.style(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    expect(style.fontSize, 14);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.color, TitoColors.ink);
    await appVisualStyle.setStyle(AppVisualStyle.flatUi);
    expect(TrainerJournal.weight(FontWeight.w800), FontWeight.w800);
  });

  test('shared border tokens stay at historical widths', () {
    expect(TitoBorders.card, 2.0);
    expect(TitoBorders.element, 1.5);
    expect(TitoBorders.glass, 1.1);
    expect(TitoBorders.journalCard, 1.25);
    expect(TitoBorders.journalElement, 0.85);
  });

  testWidgets('Journal cream card uses paper edge, not near-black 2px ink', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTitoTheme(AppVisualStyle.classic),
        home: const Scaffold(body: StickerCard(child: Text('paper'))),
      ),
    );
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(StickerCard),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.border, TrainerJournal.allCard());
    expect(decoration.color, TrainerJournal.paperWarm);
    expect(decoration.boxShadow, TrainerJournalShadows.sticker);
  });

  testWidgets('Solid Plastic cards do not read Journal paper tokens', (
    tester,
  ) async {
    await appVisualStyle.setStyle(AppVisualStyle.solidPlastic);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTitoTheme(AppVisualStyle.solidPlastic),
        home: Scaffold(
          body: BackdropGroup(child: const StickerCard(child: Text('glass'))),
        ),
      ),
    );
    expect(find.text('glass'), findsOneWidget);
  });

  testWidgets('home cards keep names visible at the default size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final journey = CurrentJourney.mock();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(360, 780)),
        child: MaterialApp(
          theme: buildTitoTheme(),
          home: Scaffold(
            body: ListView(
              children: [
                TrainerCard(journey: journey, compact: true),
                SizedBox(
                  height: 176,
                  child: JourneyCard(
                    journey: journey,
                    onOpenDetail: () {},
                    compact: true,
                  ),
                ),
                SizedBox(
                  height: 200,
                  child: PartyStrip(
                    party: journey.party,
                    compact: true,
                    square: true,
                    gridMode: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Tito'), findsWidgets);
  });

  testWidgets('English trainer name still fits the home card', (tester) async {
    AppLocale.instance.debugOverride(AppUiLanguage.en);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const journey = CurrentJourney(
      game: 'SoulSilver',
      trainerName: 'Whitney',
      location: 'Goldenrod City',
      badges: 3,
      maxBadges: 8,
      playTime: '18:42',
      party: [],
      timeline: [],
      companion: 'Cyndaquil',
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(360, 780)),
        child: MaterialApp(
          locale: const Locale('en'),
          theme: buildTitoTheme(),
          home: Scaffold(body: TrainerCard(journey: journey, compact: true)),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Trainer Whitney'), findsOneWidget);
  });

  testWidgets('English trainer name still fits the home card at large text', (
    tester,
  ) async {
    AppLocale.instance.debugOverride(AppUiLanguage.en);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const journey = CurrentJourney(
      game: 'SoulSilver',
      trainerName: 'Whitney',
      location: 'Goldenrod City',
      badges: 3,
      maxBadges: 8,
      playTime: '18:42',
      party: [],
      timeline: [
        JourneyTimelineEntry(
          id: 't1',
          text: 'Arrived in Goldenrod City',
          at: '2026-04-15 14:22',
        ),
      ],
      companion: 'Cyndaquil',
      nextReminder: 'Check the Radio Tower when ready',
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 780),
          textScaler: TextScaler.linear(1.3),
        ),
        child: MaterialApp(
          locale: const Locale('en'),
          theme: buildTitoTheme(),
          home: Scaffold(
            body: ListView(
              children: [
                TrainerCard(journey: journey, compact: true),
                JourneyTimeline(
                  entries: journey.timeline,
                  nextReminder: journey.nextReminder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Trainer Whitney'), findsOneWidget);
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('Journal keeps rendered font size at text scale $scale', (
      tester,
    ) async {
      AppLocale.instance.debugOverride(AppUiLanguage.en);
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const journey = CurrentJourney(
        game: 'SoulSilver',
        trainerName: 'Christopher Johnson',
        location: 'Goldenrod City',
        badges: 3,
        maxBadges: 8,
        playTime: '18:42',
        party: [],
        timeline: [],
        companion: 'Cyndaquil',
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          theme: buildTitoTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 780),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [TrainerCard(journey: journey, compact: true)],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final cardBounds = tester.getRect(find.byType(StickerCard));
      for (final label in [
        AppZh.timeGreeting(DateTime.now()),
        'Trainer Christopher Johnson',
      ]) {
        final paragraphFinder = find.descendant(
          of: find.text(label),
          matching: find.byType(RichText),
        );
        final paragraph = tester.renderObject<RenderParagraph>(paragraphFinder);
        // Inspect the paint transform: a constant TextStyle.fontSize alone
        // would miss a FittedBox silently undoing the user's text scale.
        final transform = paragraph.getTransformTo(null);
        expect(transform.storage[0], closeTo(1, 0.0001));
        expect(transform.storage[5], closeTo(1, 0.0001));
        expect(paragraph.textScaler.scale(20), closeTo(20 * scale, 0.0001));
        expect(paragraph.overflow, TextOverflow.ellipsis);
        final bounds = tester.getRect(paragraphFinder);
        expect(bounds.left, greaterThanOrEqualTo(cardBounds.left));
        expect(bounds.right, lessThanOrEqualTo(cardBounds.right));
        expect(bounds.bottom, lessThanOrEqualTo(cardBounds.bottom));
      }
      expect(
        tester
            .widget<Text>(find.text('Trainer Christopher Johnson'))
            .style!
            .fontSize,
        20.25,
      );
    });
  }

  for (final style in AppVisualStyle.values) {
    testWidgets('${style.name} retains its own shared control styles', (
      tester,
    ) async {
      await appVisualStyle.setStyle(style);
      late InputDecoration input;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTitoTheme(style),
          home: Builder(
            builder: (context) {
              input = retroInsetDecoration(
                context: context,
                labelText: 'Input',
              );
              return Scaffold(
                body: Column(
                  children: [
                    TitoPrimaryButton(label: 'Primary', onPressed: () {}),
                    SizedBox(
                      height: 90,
                      child: TitoQuickTile(
                        label: 'Quick',
                        icon: Icons.search,
                        onTap: () {},
                      ),
                    ),
                    const TrainerAvatar(
                      journey: CurrentJourney(
                        game: 'SoulSilver',
                        trainerName: 'Whitney',
                        location: '',
                        badges: 0,
                        maxBadges: 8,
                        playTime: '',
                        party: [],
                        timeline: [],
                        companion: '',
                      ),
                      size: 60,
                    ),
                    const JourneyTimeline(
                      entries: [
                        JourneyTimelineEntry(
                          id: '1',
                          text: 'Example',
                          at: '2026-09-10',
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      final journal = style == AppVisualStyle.classic;
      final date = tester.widget<Text>(find.text('2026-09-10')).style!;
      expect(date.fontWeight, journal ? FontWeight.w700 : FontWeight.w800);
      expect(date.color, journal ? TrainerJournal.muted : TitoColors.mutedInk);
      expect(
        tester.widget<Text>(find.text('W')).style!.fontWeight,
        journal ? FontWeight.w700 : FontWeight.w900,
      );
      if (style != AppVisualStyle.flatUi) {
        for (final label in ['Primary', 'Quick']) {
          expect(
            tester.widget<Text>(find.text(label)).style!.fontWeight,
            journal ? FontWeight.w700 : FontWeight.w800,
          );
        }
        expect(input.focusedBorder!.borderSide.width, journal ? 1.6 : 2.0);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Journal preserves default phone and handheld card dimensions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final (size, height, nameSize) in [
      (const Size(360, 780), 117.0, 20.25),
      (const Size(640, 480), 115.0, 13.5),
      (const Size(360, 360), 103.0, 13.5),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTitoTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: TrainerCard(journey: CurrentJourney.mock(), compact: true),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TrainerCard)).height, height);
      expect(
        tester
            .widget<Text>(find.text(AppZh.trainerNameLine('Tito')))
            .style!
            .fontSize,
        nameSize,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('team board selection is a fill, not a nested sticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTitoTheme(),
        home: Scaffold(
          body: PartyTeamBoard(
            party: CurrentJourney.mock().party,
            selectedIndex: 0,
          ),
        ),
      ),
    );
    expect(find.byType(StickerCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // Opt-in component captures, not native-device screenshots. The widget-test
  // engine has no system CJK fonts: require a local font instead of producing
  // misleading missing-glyph images. This font is never bundled in the app.
  const cjkPreviewFont = String.fromEnvironment('JOURNAL_PREVIEW_CJK_FONT');
  testWidgets('writes Journal / Plastic / Flat home previews', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final cjk = FontLoader('Noto Sans CJK SC')
      ..addFont(
        Future.value(
          ByteData.sublistView(File(cjkPreviewFont).readAsBytesSync()),
        ),
      );
    await cjk.load();
    for (final style in AppVisualStyle.values) {
      await appVisualStyle.setStyle(style);
      await _writeHomePreview(tester, style);
    }
    await appVisualStyle.setStyle(AppVisualStyle.classic);
    await _writeSecondaryPreview(tester);
    await _writeHandheldPreview(tester);
  }, skip: cjkPreviewFont.isEmpty);
}

Future<void> _loadBundledFonts() async {
  final loader = FontLoader('Nunito')
    ..addFont(rootBundle.load('assets/fonts/Nunito-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Nunito-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Nunito-Bold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Nunito-ExtraBold.ttf'));
  await loader.load();
}

Future<void> _writeHomePreview(
  WidgetTester tester,
  AppVisualStyle style,
) async {
  final journey = CurrentJourney.mock();
  const previewKey = ValueKey('journal-preview-boundary');
  Widget preview = ColoredBox(
    color: style == AppVisualStyle.flatUi
        ? TitoColors.flatSurface
        : const Color(0xFF5D728A),
    child: Align(
      alignment: Alignment.topCenter,
      child: RepaintBoundary(
        key: previewKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TrainerCard(journey: journey, compact: true),
              const SizedBox(height: 12),
              SizedBox(
                height: 168,
                child: JourneyCard(
                  journey: journey,
                  onOpenDetail: () {},
                  compact: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 168,
                child: PartyStrip(party: journey.party, compact: true),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 88,
                child: Row(
                  children: [
                    Expanded(
                      child: TitoQuickTile(
                        label: AppZh.navTeam,
                        icon: Icons.groups_rounded,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TitoQuickTile(
                        label: AppZh.navDex,
                        icon: Icons.menu_book_rounded,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TitoQuickTile(
                        label: AppZh.navSearch,
                        icon: Icons.search_rounded,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(400, 800)),
      child: MaterialApp(theme: buildTitoTheme(style), home: preview),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
  await _writePng(tester, previewKey, style.name);
}

Future<void> _writePng(WidgetTester tester, Key previewKey, String name) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(previewKey),
    );
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/journal-preview');
    dir.createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _capture(
  WidgetTester tester, {
  required String name,
  required Widget child,
  Size size = const Size(400, 800),
  Color background = const Color(0xFF5D728A),
}) async {
  const previewKey = ValueKey('journal-preview-boundary');
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        theme: buildTitoTheme(AppVisualStyle.classic),
        home: ColoredBox(
          color: background,
          child: Align(
            alignment: Alignment.topCenter,
            child: UnconstrainedBox(
              constrainedAxis: Axis.horizontal,
              alignment: Alignment.topCenter,
              child: RepaintBoundary(
                key: previewKey,
                child: SizedBox(
                  width: size.width,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
  await _writePng(tester, previewKey, name);
}

Future<void> _writeSecondaryPreview(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  final journey = CurrentJourney.mock();
  await _capture(
    tester,
    name: 'journal-team-journey',
    size: const Size(400, 1200),
    child: SizedBox(
      width: 368,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PartyTeamBoard(party: journey.party, selectedIndex: 0),
          const SizedBox(height: 12),
          JourneyTimeline(
            entries: journey.timeline,
            nextReminder: journey.nextReminder,
          ),
          const SizedBox(height: 12),
          StickerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TitoFactGrid(
                  children: [
                    TitoFactTile(
                      title: AppZh.settingsTrainerId,
                      child: Text(journey.trainerName),
                    ),
                    TitoFactTile(
                      title: AppZh.settingsBadges,
                      child: JournalStampLabel(
                        child: Text(journey.badgeProgressLabel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    StickerSwitch(value: true, onChanged: (_) {}),
                    const SizedBox(width: 12),
                    StickerPillToggle(
                      label: AppZh.labelBadges,
                      value: true,
                      onChanged: (_) {},
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TitoPrimaryButton(
                  label: AppZh.continueButton,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _writeHandheldPreview(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 960);
  tester.view.devicePixelRatio = 2;
  final journey = CurrentJourney.mock();
  await _capture(
    tester,
    name: 'journal-handheld',
    size: const Size(640, 480),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              TrainerCard(journey: journey, compact: true, dense: true),
              const SizedBox(height: 10),
              SizedBox(
                height: 168,
                child: JourneyCard(
                  journey: journey,
                  onOpenDetail: () {},
                  compact: true,
                  dense: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 280,
            child: PartyStrip(
              party: journey.party,
              compact: true,
              square: true,
              gridMode: true,
            ),
          ),
        ),
      ],
    ),
  );
}
