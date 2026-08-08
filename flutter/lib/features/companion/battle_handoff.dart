import '../../models/journey.dart';

/// One-shot stat handoff from the stat calculator into quick damage.
///
/// The stat calc page fills the matching slot and pushes the quick-damage
/// route; quick damage consumes (and clears) it in initState. Values never
/// persist — an abandoned handoff dies with the process.
class BattleStatHandoff {
  int? attack;
  int? defense;
  int? hp;

  bool get isEmpty => attack == null && defense == null && hp == null;

  void clear() {
    attack = null;
    defense = null;
    hp = null;
  }
}

final battleStatHandoff = BattleStatHandoff();

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
