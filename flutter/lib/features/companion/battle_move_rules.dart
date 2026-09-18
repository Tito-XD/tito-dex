import '../../l10n/app_locale.dart';
import '../dex/battle_effectiveness.dart';
import '../dex/dex_models.dart';
import 'battle_math.dart';
import 'battle_rule_data.dart';
import 'battle_session.dart';

class BattleMoveProfile {
  const BattleMoveProfile(
    this.power,
    this.type,
    this.physical,
    this.flags,
    this.conditional,
  );
  final int power;
  final String type;
  final bool physical;
  final int flags;
  final bool conditional;
  bool get contact => flags & 1 != 0;
}

BattleMoveProfile? battleMoveProfile(
  CachedMove? move,
  int generation, {
  BattleCombatant? attacker,
  String? weather,
}) {
  if (move == null ||
      generation < 4 ||
      generation > 9 ||
      (move.generation ?? 0) > generation ||
      move.category == 'status') {
    return null;
  }
  final rows = battleMoveRuleData[move.id];
  if (rows == null) return null;
  final row = rows.lastWhere((r) => (r[0] as int) <= generation);
  if (row[3] == 'status') return null;
  var power = row[1] as int;
  var type = row[2] as String;
  var physical = row[3] == 'physical';
  if (move.id == 311 &&
      const {'sun', 'rain', 'sandstorm', 'snow', 'hail'}.contains(weather)) {
    type = switch (weather) {
      'sun' => 'fire',
      'rain' => 'water',
      'sandstorm' => 'rock',
      'snow' || 'hail' => 'ice',
      _ => type,
    };
    power *= 2;
  }
  if (move.id == 263 &&
      attacker?.status != BattleStatusCondition.none &&
      attacker != null) {
    power *= 2;
  }
  if (move.id == 851 && attacker?.terastallized == true && generation >= 9) {
    type = attacker!.teraType ?? type;
    physical =
        attacker.number(attacker.raw[BattleStat.attack]!, 0) >
        attacker.number(attacker.raw[BattleStat.specialAttack]!, 0);
  }
  return BattleMoveProfile(
    power,
    type,
    physical,
    row[4] as int,
    row[5] as bool,
  );
}

BattleStat battleOffensiveStat(CachedMove? move, bool physical) =>
    move?.id == 776
    ? BattleStat.defense
    : physical
    ? BattleStat.attack
    : BattleStat.specialAttack;
BattleStat battleDefensiveStat(CachedMove? move, bool physical) =>
    physical || const {473, 540, 548}.contains(move?.id)
    ? BattleStat.defense
    : BattleStat.specialDefense;

// These moves have an explicit path in estimatePartyMove. Other callbacks,
// multi-hit and variable-power moves must not fall through to generic damage.
const _handledMoves = {
  89,
  523,
  49,
  69,
  82,
  101,
  263,
  311,
  473,
  492,
  540,
  548,
  573,
  776,
  851,
};
const _attackerSupported = {
  'huge-power',
  'pure-power',
  'guts',
  'adaptability',
  'technician',
  'water-bubble',
  'scrappy',
  'mind-s-eye',
  'minds-eye',
  'mold-breaker',
  'teravolt',
  'turboblaze',
  'tinted-lens',
  'pixilate',
  'aerilate',
  'refrigerate',
  'galvanize',
  'sniper',
  'infiltrator',
};
const _defenderSupported = {
  'sap-sipper',
  'thick-fat',
  'levitate',
  'flash-fire',
  'water-absorb',
  'volt-absorb',
  'lightning-rod',
  'storm-drain',
  'motor-drive',
  'earth-eater',
  'well-baked-body',
  'heatproof',
  'water-bubble',
  'dry-skin',
  'fluffy',
  'purifying-salt',
  'wonder-guard',
  'filter',
  'solid-rock',
  'prism-armor',
  'fur-coat',
  'ice-scales',
  'battle-armor',
  'shell-armor',
  'soundproof',
  'bulletproof',
};

String? battleMoveIssue(
  BattleCombatant attacker,
  BattleCombatant defender,
  CachedMove? move,
  int generation,
) {
  final profile = battleMoveProfile(move, generation);
  if (profile == null) {
    return AppLocale.pick(
      zh: '当前世代资料不足或不是伤害招式',
      en: 'No supported damage data for this generation',
    );
  }
  if ((profile.conditional || profile.power <= 0) &&
      !_handledMoves.contains(move!.id)) {
    return AppLocale.pick(
      zh: '需要连击、回合或其他特殊条件，暂不估算',
      en: 'Hit count, turn state or special conditions are not yet modelled',
    );
  }
  if (attacker.selectionFailed || defender.selectionFailed) {
    return AppLocale.pick(
      zh: '宝可梦资料读取失败',
      en: 'Pokémon data could not be loaded',
    );
  }
  if (attacker.unsupportedItem || defender.unsupportedItem) {
    return AppLocale.pick(
      zh: '请先确认携带道具，不能忽略未识别道具',
      en: 'Confirm the unidentified held item first',
    );
  }
  if ((attacker.terastallized && attacker.teraType == 'stellar') ||
      (defender.terastallized && defender.teraType == 'stellar')) {
    return AppLocale.pick(
      zh: '星晶的首击状态尚未建模',
      en: 'Stellar first-use state is not yet modelled',
    );
  }
  if (const {311, 851}.contains(move!.id) &&
      kAbilityMoveTypeConversion.containsKey(attacker.abilitySlug)) {
    return AppLocale.pick(
      zh: '变属性招式与皮肤特性的组合暂不估算',
      en: 'This variable-type move and conversion ability combination is not yet modelled',
    );
  }
  for (final (ability, supported, role) in [
    (attacker.abilitySlug, _attackerSupported, 0),
    (
      effectiveDefenderAbility(attacker.abilitySlug, defender.abilitySlug),
      _defenderSupported,
      1,
    ),
  ]) {
    if (ability == null || supported.contains(ability)) continue;
    final metadata =
        battleAbilityRuleData[ability.replaceAll(RegExp('[^a-z0-9]'), '')];
    if (metadata == null || metadata[role]) {
      return AppLocale.pick(
        zh: '所选特性的触发条件尚未建模，暂不估算',
        en: 'The selected ability needs conditions not yet modelled',
      );
    }
  }
  return null;
}
