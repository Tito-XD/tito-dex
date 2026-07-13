import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/features/dex/dex_game_scope.dart';
import 'package:titodex/l10n/zh_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    ZhCatalog.instance.resetForTest();
    await ZhCatalog.instance.ensureLoaded();
  });

  test('catalog resolves numeric location-area id to Chinese', () {
    // canalave-city-area id=1 in PokeAPI
    expect(zhCatalogLocationAreaLabel('1'), isNotNull);
    expect(zhCatalogLocationAreaLabel('1'), isNot(equals('1')));
  });

  test('catalog resolves slug to Chinese', () {
    expect(
      resolveObtainAreaLabelZh('cherrygrove-city-area'),
      '吉花市',
    );
    expect(
      resolveObtainAreaLabelZh('route-29-area'),
      '29号道路',
    );
  });
}
