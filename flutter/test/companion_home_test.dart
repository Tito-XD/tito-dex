import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/companion/companion_art.dart';
import 'package:titodex/widgets/city_illustration.dart';

void main() {
  test('cycleCompanion rotates HGSS starters', () {
    expect(cycleCompanion('Cyndaquil'), 'Totodile');
    expect(cycleCompanion('Totodile'), 'Chikorita');
    expect(cycleCompanion('Chikorita'), 'Cyndaquil');
    expect(cycleCompanion('Riolu'), 'Chikorita');
  });

  test('companionAssetPath resolves bundled starters', () {
    expect(companionAssetPath('Cyndaquil'), 'assets/companion/155.png');
    expect(companionAssetPath('Riolu'), isNull);
  });

  test('locationSceneKindFor detects routes and cities', () {
    expect(locationSceneKindFor('36号道路'), LocationSceneKind.route);
    expect(locationSceneKindFor('满金市'), LocationSceneKind.city);
  });
}
