import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/pokemon_anniversary_art.dart';
import 'package:titodex/widgets/pokemon_anniversary_artwork.dart';
import 'package:titodex/theme/tito_colors.dart';

import 'artwork_viewer_test.dart' show pumpViewer;

void main() {
  test(
    'anniversary catalog uses national numbers and rejects unknown species',
    () {
      expect(pokemonAnniversaryArtUrl(1), endsWith('/0001.png'));
      expect(pokemonAnniversaryArtUrl(25), endsWith('/0025.png'));
      expect(pokemonAnniversaryArtUrl(1025), endsWith('/1025.png'));
      expect(pokemonAnniversaryArtUrl(0), isNull);
      expect(pokemonAnniversaryArtUrl(1026), isNull);
      expect(pokemonAnniversaryArtUrl(10034), isNull);
    },
  );

  testWidgets('anniversary is opt-in and separate from form or shiny sprites', (
    tester,
  ) async {
    const megaCharizard = PokemonSummary(
      id: 6,
      nameEn: 'charizard-mega-x',
      nameZh: '超级喷火龙 X',
      types: ['fire', 'dragon'],
      spriteResourceId: 10034,
      localSpritePath: 'sprites/10034.png',
    );
    await pumpViewer(tester, megaCharizard);
    expect(find.byType(PokemonAnniversaryArtwork), findsNothing);
    expect(find.text('闪光'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url.contains('/30th_logo/'),
      ),
      findsNothing,
    );
    await tester.tap(find.widgetWithText(TextButton, '闪光'));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.widgetWithText(ChoiceChip, '30周年 Logo'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(PokemonAnniversaryArtwork), findsOneWidget);
    expect(find.text('闪光'), findsNothing);
    expect(find.byKey(const ValueKey('artwork-viewer-editions')), findsNothing);
    final artwork = tester.widget<PokemonAnniversaryArtwork>(
      find.byType(PokemonAnniversaryArtwork),
    );
    expect(artwork.nationalId, 6);
    expect(find.text('按物种展示纪念 Logo，不改变当前形态或图鉴数据。'), findsOneWidget);
    expect(find.text('官方来源与使用条款'), findsOneWidget);
    final image = tester.widget<Image>(
      find.byKey(const ValueKey('anniversary-6-0')),
    );
    expect((image.image as NetworkImage).url, endsWith('/0006.png'));

    await tester.tap(find.widgetWithText(ChoiceChip, '立绘'));
    await tester.pump();
    expect(find.byType(PokemonAnniversaryArtwork), findsNothing);
    expect(find.text('闪光'), findsOneWidget);
    final shinyButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '闪光'),
    );
    expect(
      shinyButton.style!.foregroundColor!.resolve({}),
      TitoColors.softYellow,
    );
    final hero = tester.widget<Hero>(
      find.byKey(const ValueKey('artwork-stable-hero')),
    );
    expect(hero.tag, 'pokemon-artwork-6-10034');
    expect(
      find.byKey(const ValueKey('artwork-viewer-editions')),
      findsOneWidget,
    );
  });

  testWidgets(
    'missing artwork reports failure without showing unrelated sprite',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PokemonAnniversaryArtwork(nationalId: 25)),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('周年图片暂时无法加载'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(find.byKey(const ValueKey('anniversary-25-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
