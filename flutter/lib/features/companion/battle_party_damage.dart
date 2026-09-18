import '../dex/battle_effectiveness.dart';
import 'battle_move_rules.dart';
import '../dex/dex_models.dart';
import '../dex/type_chart.dart';
import 'battle_math.dart';
import 'battle_session.dart';

/// Uses each move's category and each member's unmodified stats. Battle bonuses
/// are applied once by the same estimator as the single-combatant calculator.
DamageEstimate? estimatePartyMove({
  required BattleCombatant attacker,
  required BattleCombatant defender,
  required CachedMove? move,
  required Map<String, TypeDamageRelations> relations,
  required int generation,
  String? weatherSlug,
  String? terrainSlug,
  bool critical = false,
  bool screened = false,
  bool spread = false,
}) {
  if (battleMoveIssue(attacker, defender, move, generation) != null) {
    return null;
  }
  final profile = battleMoveProfile(
    move,
    generation,
    attacker: attacker,
    weather: weatherSlug,
  )!;
  final physical = profile.physical;
  final id = move!.id;
  var chart = relations;
  if (id == 573 && chart['ice'] != null) {
    final ice = chart['ice']!;
    chart = {
      ...chart,
      'ice': TypeDamageRelations(
        doubleDamageTo: {...ice.doubleDamageTo, 'water'},
        halfDamageTo: {...ice.halfDamageTo}..remove('water'),
        noDamageTo: ice.noDamageTo,
      ),
    };
  }
  final defenseAbility = effectiveDefenderAbility(
    attacker.abilitySlug,
    defender.abilitySlug,
  );
  final blockedByFlag =
      (defenseAbility == 'soundproof' && profile.flags & 2 != 0) ||
      (defenseAbility == 'bulletproof' && profile.flags & 64 != 0) ||
      (terrainSlug == 'psychic' &&
          generation >= 7 &&
          profile.flags & 256 != 0 &&
          battleGrounded(
            defender.terastallized
                ? [defender.teraType ?? 'normal']
                : defender.types,
            defender.abilitySlug,
          ));
  final type = blockedByFlag
      ? 0.0
      : typeMultiplierForMove(
          profile.type,
          defender.types,
          chart,
          attackerAbilitySlug: attacker.abilitySlug,
          defenderAbilitySlug: defender.abilitySlug,
          generation: generation,
          defenderTerastallized: defender.terastallized,
          defenderTeraType: defender.teraType,
        );
  final hp = defender.number(defender.raw[BattleStat.hp]!, 1);
  if (blockedByFlag || const {49, 69, 82, 101}.contains(id)) {
    final fixed = switch (id) {
      49 => 20,
      82 => 40,
      69 || 101 => attacker.number(attacker.level, 50),
      _ => 0,
    };
    return fixedDamageEstimate(fixed, hp, type);
  }
  var extra = 1.0;
  if (terrainSlug == 'grassy' &&
      generation >= 6 &&
      const {89, 222, 523}.contains(id) &&
      battleGrounded(
        defender.terastallized && generation >= 9
            ? [defender.teraType ?? 'normal']
            : defender.types,
        defender.abilitySlug,
      )) {
    extra *= .5;
  }
  final source = id == 492 ? defender : attacker;
  return estimateDamage(
    level: attacker.number(attacker.level, 50),
    power: profile.power,
    attack: source.number(source.raw[battleOffensiveStat(move, physical)]!, 0),
    defense: defender.number(
      defender.raw[battleDefensiveStat(move, physical)]!,
      0,
    ),
    defenderHp: defender.number(defender.raw[BattleStat.hp]!, 1),
    moveType: profile.type,
    attackerTypes: attacker.types,
    defenderTypes: defender.types,
    relationsByType: chart,
    attackerAbilitySlug: attacker.abilitySlug,
    defenderAbilitySlug: defender.abilitySlug,
    generation: generation,
    category: physical ? MoveCategory.physical : MoveCategory.special,
    defenderTerastallized: defender.terastallized,
    defenderTeraType: defender.teraType,
    attackerTerastallized: attacker.terastallized,
    attackerTeraType: attacker.teraType,
    attackerHeldItem: attacker.heldItem,
    typeBoostItemType: attacker.typeBoostItemType,
    attackerStatus: attacker.status,
    weatherSlug: weatherSlug,
    terrainSlug: terrainSlug,
    isCriticalHit: critical,
    defenderScreened: screened,
    isContactMove: profile.contact,
    isSpreadMove: spread && profile.flags & 512 != 0,
    otherMultiplier: extra,
    ignoreBurn: id == 263 && generation >= 6,
    usesPhysicalDefense:
        battleDefensiveStat(move, physical) == BattleStat.defense,
    teraPowerFloorEligible: profile.flags & 256 == 0,
  );
}
