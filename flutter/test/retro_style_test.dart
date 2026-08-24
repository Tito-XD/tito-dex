import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/retro_style.dart';
import 'package:titodex/theme/tito_colors.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/sticker_card.dart';
import 'package:titodex/widgets/sticker_pressable.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await appVisualStyle.setStyle(AppVisualStyle.flatUi);
    await retroStyle.setEnabled(true);
  });

  tearDown(() async {
    await retroStyle.setEnabled(true);
    await appVisualStyle.setStyle(AppVisualStyle.flatUi);
  });

  test('surface depth defaults to enabled and persists the choice', () async {
    SharedPreferences.setMockInitialValues({});
    final fresh = RetroStyle();
    await fresh.load();
    expect(fresh.enabled, isTrue);

    await fresh.setEnabled(false);
    expect(fresh.enabled, isFalse);

    final restored = RetroStyle();
    await restored.load();
    expect(restored.enabled, isFalse);
  });

  testWidgets('StickerCard switches between elevated and outlined Material', (
    tester,
  ) async {
    Material cardMaterial() => tester.widget<Material>(
      find.descendant(
        of: find.byType(StickerCard),
        matching: find.byType(Material),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTitoTheme(),
        home: const Scaffold(body: StickerCard(child: Text('x'))),
      ),
    );
    expect(cardMaterial().elevation, 1);
    expect(
      (cardMaterial().shape! as RoundedRectangleBorder).side,
      BorderSide.none,
    );

    await retroStyle.setEnabled(false);
    await tester.pump();
    expect(cardMaterial().elevation, 0);
    expect(
      (cardMaterial().shape! as RoundedRectangleBorder).side,
      isNot(BorderSide.none),
    );
  });

  testWidgets('StickerPressable delegates feedback to its Material child', (
    tester,
  ) async {
    const childKey = ValueKey('material-child');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StickerPressable(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: SizedBox(key: childKey, width: 120, height: 80),
          ),
        ),
      ),
    );

    expect(find.byKey(childKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(StickerPressable),
        matching: find.byType(AnimatedContainer),
      ),
      findsNothing,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(childKey)),
    );
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(childKey)), const Offset(0, 0));
    await gesture.up();
  });

  testWidgets('display-only StickerPressable remains a layout pass-through', (
    tester,
  ) async {
    const childKey = ValueKey('display-child');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StickerPressable(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            interactive: false,
            child: SizedBox(key: childKey, width: 120, height: 80),
          ),
        ),
      ),
    );

    expect(find.byKey(childKey), findsOneWidget);
    expect(tester.getSize(find.byKey(childKey)), const Size(120, 80));
  });

  testWidgets('Solid Plastic card uses the static moulded shared surface', (
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

    expect(find.byKey(const ValueKey('solid-plastic-shadow')), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets(
    'switching from Flat UI restores Trainer Journal hard shadow and sink',
    (tester) async {
      const childKey = ValueKey('theme-switch-child');
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: appVisualStyle,
          builder: (context, _) => MaterialApp(
            theme: buildTitoTheme(appVisualStyle.style),
            home: const Scaffold(
              body: StickerPressable(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                child: SizedBox(key: childKey, width: 120, height: 80),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(AnimatedContainer), findsNothing);

      await appVisualStyle.setStyle(AppVisualStyle.classic);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTitoTheme(appVisualStyle.style),
          home: const Scaffold(
            body: StickerPressable(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              child: SizedBox(key: childKey, width: 120, height: 80),
            ),
          ),
        ),
      );

      final pressable = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(StickerPressable),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        (pressable.decoration! as BoxDecoration).boxShadow,
        TrainerJournalShadows.sticker,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(childKey)),
      );
      await tester.pump(const Duration(milliseconds: 80));
      final sunk = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(StickerPressable),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(sunk.transform!.storage[13], 3);
      expect(
        (sunk.decoration! as BoxDecoration).boxShadow,
        TrainerJournalShadows.stickerPressed,
      );
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 120));
    },
  );
}
