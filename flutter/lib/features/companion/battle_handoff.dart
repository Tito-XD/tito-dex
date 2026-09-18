import '../../models/journey.dart';

/// One-shot team selection carried from Party into quick damage.
class BattlePartyHandoff {
  PartyMember? member;
  int? moveId;

  bool get isEmpty => member == null;

  void set(PartyMember value, {int? selectedMoveId}) {
    member = value;
    moveId = selectedMoveId;
  }

  void clear() {
    member = null;
    moveId = null;
  }
}

final battlePartyHandoff = BattlePartyHandoff();
