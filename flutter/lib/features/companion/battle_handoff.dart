import 'package:flutter/foundation.dart';

import '../../models/journey.dart';

/// One-shot stat handoff from the stat calculator into quick damage.
///
/// The stat calc page fills the matching slot and switches to (or pushes)
/// quick damage; quick damage consumes (and clears) it when notified.
/// Values never persist — an abandoned handoff dies with the process.
class BattleStatHandoff extends ChangeNotifier {
  int? attack;
  int? defense;
  int? hp;

  bool get isEmpty => attack == null && defense == null && hp == null;

  void commit() => notifyListeners();

  void clear({bool notify = true}) {
    attack = null;
    defense = null;
    hp = null;
    if (notify) notifyListeners();
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
