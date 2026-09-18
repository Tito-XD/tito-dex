import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/companion/battle_math.dart';
import 'package:titodex/features/companion/battle_party_damage.dart';
import 'package:titodex/features/companion/battle_session.dart';
import 'package:titodex/features/dex/battle_effectiveness.dart';
import 'package:titodex/features/dex/dex_models.dart';

CachedMove move(String category, {int? power = 80, int generation = 1}) =>
    CachedMove(
      id: power == null || power == 0
          ? 68
          : category == 'physical'
          ? 70
          : 161,
      nameEn: 'Test',
      nameZh: '测试',
      type: 'normal',
      category: category,
      power: power,
      generation: generation,
    );

void main() {
  test(
    'party moves use both attack categories and the current shared defender',
    () {
      final session = BattleSession();
      addTearDown(session.dispose);
      final a = session.attacker;
      final d = session.defender;
      a.raw[BattleStat.attack]!.text = '200';
      a.raw[BattleStat.specialAttack]!.text = '100';
      d.raw[BattleStat.defense]!.text = '100';
      d.raw[BattleStat.specialDefense]!.text = '200';
      d.raw[BattleStat.hp]!.text = '200';
      DamageEstimate run(String category) => estimatePartyMove(
        attacker: a,
        defender: d,
        move: move(category),
        relations: {},
        generation: 9,
      )!;
      // Strength / Tri Attack: both historical power 80 and neutral here.
      expect(run('physical').maxDamage, 72);
      expect(run('special').maxDamage, 19);
      expect(run('physical').maxPercent, 36);
      d.raw[BattleStat.specialDefense]!.text = '100';
      expect(run('special').maxDamage, 37);
      expect(run('physical').maxDamage, 72);
    },
  );

  test(
    'party attack bonuses apply once and unsupported moves produce no estimate',
    () {
      final session = BattleSession();
      addTearDown(session.dispose);
      session.attacker.raw[BattleStat.attack]!.text = '100';
      session.defender.raw[BattleStat.defense]!.text = '100';
      session.attacker.abilitySlug = 'huge-power';
      session.attacker.heldItem = BattleHeldItem.choiceBand;
      session.attacker.status = BattleStatusCondition.burn;
      DamageEstimate? run(CachedMove? value) => estimatePartyMove(
        attacker: session.attacker,
        defender: session.defender,
        move: value,
        relations: {},
        generation: 4,
      );
      expect(run(move('physical'))!.maxDamage, 53);
      for (final value in [
        null,
        move('status'),
        move('special', power: null),
        move('physical', power: 0),
        move('special', generation: 9),
      ]) {
        expect(run(value), isNull);
      }
      session.attacker.selectionFailed = true;
      expect(run(move('physical')), isNull);
    },
  );
}
