import '../dex/battle_effectiveness.dart';
import '../dex/generation_type_chart.dart';
import '../dex/type_chart.dart';

class BattleTeamMember {
  const BattleTeamMember({
    required this.name,
    required this.types,
    this.abilitySlug,
  });
  final String name;
  final List<String> types;
  final String? abilitySlug;
}

class BattleTeamAnalysis {
  BattleTeamAnalysis(
    List<BattleTeamMember> members,
    Map<String, TypeDamageRelations> relations, {
    required int generation,
  }) {
    for (final type in attackTypesForGeneration(generation)) {
      var weak = 0;
      var resist = 0;
      var immune = 0;
      var covered = false;
      for (final member in members) {
        final multiplier = typeMultiplierForBattleMove(
          type,
          BattleEffectivenessInput(
            defenderTypes: member.types,
            relationsByType: relations,
            generation: generation,
            defenderAbilitySlug: member.abilitySlug,
          ),
        );
        if (multiplier > 1) weak++;
        if (multiplier > 0 && multiplier < 1) resist++;
        if (multiplier == 0) immune++;
        if (bestStabMultiplierAgainstDefender(
              attackerTypes: member.types,
              defenderSingleType: type,
              relationsByType: relations,
              generation: generation,
              attackerAbilitySlug: member.abilitySlug,
            ) >=
            2) {
          covered = true;
        }
      }
      if (weak >= 2) sharedWeaknesses[type] = weak;
      if (resist > 0) resistances[type] = resist;
      if (immune > 0) immunities[type] = immune;
      if (!covered && members.isNotEmpty) offensiveBlindSpots.add(type);
    }
  }

  final sharedWeaknesses = <String, int>{};
  final resistances = <String, int>{};
  final immunities = <String, int>{};
  final offensiveBlindSpots = <String>[];
}
