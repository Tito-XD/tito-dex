import '../game/game_catalog.dart';
import '../game/game_edition.dart';

/// Battle-tool context derived from global [GameEdition] (v0.4.0 B2).
class BattleGameScope {
  const BattleGameScope({
    required this.gameKey,
    required this.badge,
    required this.generation,
    required this.defaultLevel,
    required this.facilityLabel,
    required this.typeChartNote,
    required this.damageNote,
  });

  final String gameKey;
  final String badge;
  final int generation;
  final int defaultLevel;
  final String facilityLabel;
  final String typeChartNote;
  final String damageNote;
}

BattleGameScope battleScopeForEdition(GameEdition edition) {
  final badge = badgeForEdition(edition);
  final gameKey = edition.journeyGameKey ?? 'SoulSilver';
  return _scopeForBadge(badge, gameKey);
}

BattleGameScope battleScopeForGame(String gameKey) {
  final badge = badgeForGame(gameKey);
  return _scopeForBadge(badge, gameKey);
}

BattleGameScope _scopeForBadge(String badge, String gameKey) {
  return switch (badge) {
    'HGSS' || 'Pt' || 'DP' => BattleGameScope(
        gameKey: gameKey,
        badge: badge,
        generation: 4,
        defaultLevel: 50,
        facilityLabel: '对战开拓区',
        typeChartNote: '属性表按现代数据参考；第四世代游戏内无妖精系。',
        damageNote: '按第四世代伤害公式估算，适合对战开拓区与高难度战参考。',
      ),
    'B/W' => BattleGameScope(
        gameKey: gameKey,
        badge: badge,
        generation: 5,
        defaultLevel: 50,
        facilityLabel: '对战地铁',
        typeChartNote: '属性表按第五世代规则；游戏内无妖精系。',
        damageNote: '按第五世代伤害公式估算，适合对战地铁与 N 战参考。',
      ),
    'B2W2' => BattleGameScope(
        gameKey: gameKey,
        badge: badge,
        generation: 5,
        defaultLevel: 50,
        facilityLabel: '世界对战会场',
        typeChartNote: '属性表按第五世代规则；游戏内无妖精系。',
        damageNote: '按第五世代伤害公式估算，适合对战地铁与世界对战参考。',
      ),
    'X/Y' || 'ORAS' => BattleGameScope(
        gameKey: gameKey,
        badge: badge,
        generation: 6,
        defaultLevel: 50,
        facilityLabel: '对战城堡',
        typeChartNote: '含妖精系与 Mega 进化世代；此处仅算属性与基础伤害。',
        damageNote: '按第六世代伤害公式估算，适合对战城堡与冠军战参考。',
      ),
    'SM' || 'USUM' || 'LGPE' => BattleGameScope(
        gameKey: gameKey,
        badge: badge,
        generation: 7,
        defaultLevel: 50,
        facilityLabel: '对战树',
        typeChartNote: '含 Z 招式世代；此处不算 Z 与极巨化，仅基础伤害参考。',
        damageNote: '按第七世代伤害公式估算，适合对战树参考。',
      ),
    'SWSH' || 'BDSP' => BattleGameScope(
        gameKey: gameKey,
        badge: badge,
        generation: 8,
        defaultLevel: 50,
        facilityLabel: '对战塔',
        typeChartNote: '含极巨化世代；此处不算极巨化，仅基础伤害参考。',
        damageNote: '按第八世代伤害公式估算，适合对战塔参考。',
      ),
    'SV' || 'LA' || 'LZA' || 'Champions' => BattleGameScope(
        gameKey: gameKey,
        badge: badge,
        generation: 9,
        defaultLevel: 50,
        facilityLabel: '对战设施',
        typeChartNote: '第九世代规则参考；请以游戏内机制为准。',
        damageNote: '按第九世代伤害公式估算，仅供快速参考。',
      ),
    _ => BattleGameScope(
        gameKey: gameKey,
        badge: badge,
        generation: 4,
        defaultLevel: 50,
        facilityLabel: '对战设施',
        typeChartNote: '属性表仅供参考，请以当前游戏内机制为准。',
        damageNote: '按通用伤害公式估算，仅供快速参考。',
      ),
  };
}
