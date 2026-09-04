import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/pokemon_anniversary_art.dart';
import 'package:titodex/features/dex/pokemon_anniversary_catalog.g.dart';
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
    expect(find.text('Logo 选择仅用于展示，不改变当前形态、闪光或图鉴数据。'), findsOneWidget);
    expect(find.text('当前展示：超级进化 X'), findsOneWidget);
    expect(find.text('官方来源与使用条款'), findsOneWidget);
    final image = tester.widget<Image>(
      find.byKey(const ValueKey('anniversary-0006_01-0')),
    );
    expect((image.image as NetworkImage).url, endsWith('/0006_01.png'));

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
      expect(find.byKey(const ValueKey('anniversary-0025-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'official catalog preserves all file identities including non-null base branches',
    () {
      final all = [
        for (var id = 1; id <= 1025; id++) ...pokemonAnniversaryArts(id),
      ];
      expect(all.length, 1324);
      expect(all.map((art) => art.file).toSet().length, 1324);
      expect(all.where((art) => art.isBase).length, 1025);
      expect(
        pokemonAnniversaryArts(201).where((art) => art.isBase).single.file,
        '0201',
      );
      expect(pokemonAnniversaryArts(6).map((art) => art.file), [
        '0006',
        '0006_01',
        '0006_02',
        '0006_03',
      ]);
      expect(pokemonAnniversaryArts(479).length, 6);
      expect(() => pokemonAnniversaryArts(6).clear(), throwsUnsupportedError);
      final officialFiles = all.map((art) => art.file).toSet();
      expect(
        pokemonAnniversaryFileByFormKey.values.every(officialFiles.contains),
        isTrue,
      );
    },
  );

  test('form matching uses official semantics and not art-id ordering', () {
    for (final (id, slug, file) in [
      (6, 'charizard-mega-x', '0006_01'),
      (6, 'charizard-mega-y', '0006_02'),
      (6, 'charizard-gmax', '0006_03'),
      (25, 'pikachu-gmax', '0025_01'),
      (19, 'rattata-alola', '0019_01'),
      (52, 'meowth-galar', '0052_02'),
      (479, 'rotom-heat', '0479_01'),
      (479, 'rotom-wash', '0479_02'),
      (479, 'rotom-frost', '0479_03'),
      (479, 'rotom-fan', '0479_04'),
      (479, 'rotom-mow', '0479_05'),
      (386, 'deoxys-speed', '0386_03'),
      (555, 'darmanitan-galar-zen', '0555_03'),
      (1, 'bulbasaur', '0001'),
      (984, 'great-tusk', '0984'),
    ]) {
      final selected = selectPokemonAnniversaryArt(id, nameEn: slug)!;
      expect(selected.art.file, file, reason: slug);
      expect(selected.matchesForm, isTrue, reason: slug);
    }
    for (final (id, slug, resourceId) in [
      (25, 'pikachu-rock-star', 10080),
      (201, 'unown-b', 201),
      (201, 'unown(B)', 201),
      (6, 'charizard-unknown', 6),
      (1, 'bulbasaur-gmax', 1),
    ]) {
      final selected = selectPokemonAnniversaryArt(
        id,
        nameEn: slug,
        spriteResourceId: resourceId,
      )!;
      expect(selected.art.isBase, isTrue, reason: slug);
      expect(selected.matchesForm, isFalse, reason: slug);
    }
  });

  testWidgets(
    'unmatched form is explicit and manual selection requests exact official logo',
    (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PokemonAnniversaryArtwork(
              nationalId: 25,
              nameEn: 'pikachu-rock-star',
              spriteResourceId: 10080,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('未自动匹配当前形态；当前展示：基础 Logo'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('超极巨化').last);
      await tester.pumpAndSettle();
      expect(find.text('当前展示：超极巨化'), findsOneWidget);
      final image = tester.widget<Image>(
        find.byKey(const ValueKey('anniversary-0025_01-0')),
      );
      expect((image.image as NetworkImage).url, endsWith('/0025_01.png'));
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
