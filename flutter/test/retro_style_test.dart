import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/theme/retro_style.dart';
import 'package:titodex/theme/tito_colors.dart';
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

  test('RetroStyle defaults to enabled and persists the choice', () async {
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

  testWidgets('StickerCard carries the signature shadow only in retro mode',
      (tester) async {
    BoxDecoration cardDecoration() {
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(StickerCard),
          matching: find.byType(DecoratedBox),
        ),
      );
      return box.decoration as BoxDecoration;
    }

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StickerCard(child: Text('x')))),
    );
    expect(cardDecoration().boxShadow, TitoShadows.sticker);

    await retroStyle.setEnabled(false);
    await tester.pump();
    expect(cardDecoration().boxShadow, isNull);
  });

  testWidgets('StickerPressable sinks and squashes its shadow while pressed',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StickerPressable(
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(width: 120, height: 80),
            ),
          ),
        ),
      ),
    );

    AnimatedContainer container() =>
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    double sunkY() =>
        (container().transform as Matrix4).getTranslation().y;
    BoxDecoration decoration() => container().decoration as BoxDecoration;

    expect(sunkY(), 0);
    expect(decoration().boxShadow, TitoShadows.sticker);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SizedBox)),
    );
    await tester.pump();
    expect(sunkY(), 3);
    expect(decoration().boxShadow, TitoShadows.stickerPressed);

    await gesture.up();
    await tester.pump();
    expect(sunkY(), 0);
    expect(decoration().boxShadow, TitoShadows.sticker);
  });

  testWidgets('flat mode strips the shadow and the press physics',
      (tester) async {
    await retroStyle.setEnabled(false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StickerPressable(
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(width: 120, height: 80),
            ),
          ),
        ),
      ),
    );

    AnimatedContainer container() =>
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));

    expect((container().decoration as BoxDecoration).boxShadow, isNull);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SizedBox)),
    );
    await tester.pump();
    expect((container().transform as Matrix4).getTranslation().y, 0);
    expect((container().decoration as BoxDecoration).boxShadow, isNull);
    await gesture.up();
  });

  testWidgets('display-only pressable keeps the static shadow without sinking',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StickerPressable(
              borderRadius: BorderRadius.circular(12),
              interactive: false,
              child: const SizedBox(width: 120, height: 80),
            ),
          ),
        ),
      ),
    );

    AnimatedContainer container() =>
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));

    expect((container().decoration as BoxDecoration).boxShadow,
        TitoShadows.sticker);
    expect(
      find.descendant(
        of: find.byType(StickerPressable),
        matching: find.byType(Listener),
      ),
      findsNothing,
    );
  });
}
