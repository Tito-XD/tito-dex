import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/navigation/back_navigation.dart';

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
}
