import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/companion/companion_animation_catalog.dart';

import 'fixtures/companion_animation_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CompanionAnimationCatalog catalog;
  setUpAll(() {
    catalog = CompanionAnimationCatalog.fromJson(
      jsonDecode(
            File(
              'assets/data/companion_animation_catalog.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
  });

  test('Furret has separately indexed regular and shiny ShinyHunters GIFs', () {
    final normal = catalog
        .forForm(162)
        .singleWhere((a) => a.source == 'shinyhunters');
    final shiny = catalog
        .forForm(162, shiny: true)
        .singleWhere((a) => a.source == 'shinyhunters');
    expect(normal.url, endsWith('/regular/162.gif'));
    expect(shiny.url, endsWith('/shiny/162.gif'));
    expect(normal.width, 560);
    expect(shiny.width, 314);
    expect(normal.generation, 100);
    expect(normal.cacheFileName, isNot(shiny.cacheFileName));
  });

  test('same-ID forms use exact keys and cannot borrow another form', () {
    final b = catalog.forForm(201, formKey: 'unown-b', shiny: true);
    expect(b.single.url, endsWith('/shiny/867.gif'));
    expect(catalog.forForm(201, formKey: 'unown-c', shiny: true), isEmpty);
    expect(catalog.forForm(201, shiny: true), isEmpty);
    expect(catalog.forForm(493, formKey: 'arceus-fire'), isEmpty);
  });

  test('static disguised GIFs and ambiguous sample forms are excluded', () {
    expect(
      catalog
          .forForm(58, formKey: 'growlithe-hisui')
          .where((a) => a.source == 'shinyhunters'),
      isEmpty,
    );
    expect(
      catalog
          .forForm(58, formKey: 'growlithe-hisui', shiny: true)
          .singleWhere((a) => a.source == 'shinyhunters')
          .url,
      endsWith('/shiny/1024.gif'),
    );
    for (final speciesId in [869, 1007, 1013]) {
      expect(
        catalog
            .forForm(speciesId, shiny: true)
            .where((a) => a.source == 'shinyhunters'),
        isEmpty,
      );
    }
    expect(
      catalog.forForm(906).singleWhere((a) => a.source == 'shinyhunters').url,
      endsWith('/regular/1044.gif'),
    );
  });

  test(
    'asset bundle includes the small catalog without media requests',
    () async {
      final bundled = await CompanionAnimationCatalog.load();
      expect(
        bundled.forForm(162).any((a) => a.source == 'shinyhunters'),
        isTrue,
      );
    },
  );

  test(
    'cache names separate source, form and colour even for the same URL',
    () {
      final assets = [
        animationFixture(),
        animationFixture(id: 'another-source'),
        animationFixture(
          id: 'another-form',
          formKey: 'furret-other',
          isDefault: false,
        ),
        animationFixture(id: 'shiny', shiny: true),
      ];
      expect(assets.map((a) => a.cacheFileName).toSet(), hasLength(4));
      expect(assets.first.matches(162, 'missing-form', false), isFalse);
      expect(assets.first.matches(162, null, true), isFalse);
    },
  );
}
