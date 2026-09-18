import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/companion/battle_handoff.dart';
import 'package:titodex/models/journey.dart';

void main() {
  test('party handoff carries the selected member and move, then clears', () {
    final handoff = BattlePartyHandoff();
    expect(handoff.isEmpty, isTrue);
    const member = PartyMember(species: '皮卡丘', speciesId: 25, level: 70);
    handoff.set(member, selectedMoveId: 85);
    expect(handoff.isEmpty, isFalse);
    expect(handoff.member, same(member));
    expect(handoff.moveId, 85);

    handoff.clear();
    expect(handoff.isEmpty, isTrue);
    expect(handoff.member, isNull);
    expect(handoff.moveId, isNull);
  });

  test('shared instance is process-wide', () {
    battlePartyHandoff.clear();
    battlePartyHandoff.set(const PartyMember(species: '皮卡丘'));
    expect(battlePartyHandoff.isEmpty, isFalse);
    battlePartyHandoff.clear();
    expect(battlePartyHandoff.isEmpty, isTrue);
  });
}
