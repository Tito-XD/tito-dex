import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/theme/retro_style.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/sticker_card.dart';
import 'package:titodex/widgets/sticker_pressable.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await retroStyle.setEnabled(true);
  });

  tearDown(() async {
    await retroStyle.setEnabled(true);
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
}
