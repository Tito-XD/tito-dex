import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/parser/gen4_exp.dart';

void main() {
  test('gen4MediumFastExpForLevel follows n³ curve', () {
    expect(gen4MediumFastExpForLevel(1), 0);
    expect(gen4MediumFastExpForLevel(10), 1000);
    expect(gen4MediumFastExpForLevel(27), 19683);
  });

  test('gen4MediumFastExpProgress interpolates within level band', () {
    expect(gen4MediumFastExpProgress(1000, 10), 0);
    final mid = 1000 + ((1331 - 1000) / 2).round();
    expect(gen4MediumFastExpProgress(mid, 10), closeTo(0.5, 0.01));
  });
}
