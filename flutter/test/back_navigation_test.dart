import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/navigation/back_navigation.dart';
import 'package:titodex/navigation/tito_page_transition.dart';

void main() {
  test('isDexDetail matches pokemon detail routes', () {
    expect(TitoBackNavigation.isDexDetail('/dex/25'), isTrue);
    expect(TitoBackNavigation.isDexDetail('/dex'), isFalse);
    expect(TitoBackNavigation.isDexDetail('/team'), isFalse);
  });

  test('isHome matches root route only', () {
    expect(TitoBackNavigation.isHome('/'), isTrue);
    expect(TitoBackNavigation.isHome('/team'), isFalse);
  });

  test('fallback back path returns nested routes to their logical parent', () {
    expect(TitoBackNavigation.parentPath('/dex/25'), '/dex');
    expect(TitoBackNavigation.parentPath('/dex/moves'), '/dex');
    expect(TitoBackNavigation.parentPath('/dex/abilities'), '/dex');
    expect(
      TitoBackNavigation.parentPath('/search/companion/type-matchup'),
      '/search',
    );
    expect(TitoBackNavigation.parentPath('/search/reference/json'), '/search');
  });

  test('fallback back path returns first-level pages to home', () {
    for (final path in const [
      '/team',
      '/journey',
      '/dex',
      '/search',
      '/settings',
    ]) {
      expect(TitoBackNavigation.parentPath(path), '/');
    }
  });

  test('only the Dex home action uses a Hero tag', () {
    expect(
      TitoHomeActionHero.forRoute('/dex', TitoHomeActionHero.dex),
      TitoHomeActionHero.dex,
    );
    expect(
      TitoHomeActionHero.forRoute('/team', TitoHomeActionHero.dex),
      isNull,
    );
  });
}
