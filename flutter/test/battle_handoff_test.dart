import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/companion/battle_handoff.dart';

void main() {
  test('handoff starts empty, holds one slot, and clears fully', () {
    final handoff = BattleStatHandoff();
    expect(handoff.isEmpty, isTrue);

    handoff.attack = 182;
    expect(handoff.isEmpty, isFalse);
    expect(handoff.defense, isNull);
    expect(handoff.hp, isNull);

    handoff.clear();
    expect(handoff.isEmpty, isTrue);
    expect(handoff.attack, isNull);
  });

  test('shared instance is process-wide', () {
    battleStatHandoff.clear();
    battleStatHandoff.hp = 207;
    expect(battleStatHandoff.isEmpty, isFalse);
    battleStatHandoff.clear();
    expect(battleStatHandoff.isEmpty, isTrue);
  });
}
