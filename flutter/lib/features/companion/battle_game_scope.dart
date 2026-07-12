import '../game/game_catalog.dart';
import '../game/game_edition.dart';

/// Battle-tool context derived from the journey's current game.
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

// v0.4.0: prefer global [GameEdition] when resolving battle-tool context (B2).
BattleGameScope battleScopeForGame(String gameKey, {GameEdition? edition}) {
  final effectiveKey = edition?.journeyGameKey ?? gameKey;
  final badge = edition?.homeBadgeLabel ?? badgeForGame(effectiveKey);
  return switch (badge) {
    'HGSS' || 'Pt' => BattleGameScope(
        gameKey: effectiveKey,
        badge: badge,
        generation: 4,
        defaultLevel: 50,
        facilityLabel: '对战开拓区',
        typeChartNote: '属性表按现代数据参考；魂银/心金/白金游戏内无妖精系。',
        damageNote: '按第四世代伤害公式估算，适合对战开拓区与高难度战参考。',
      ),
    'B/W' => BattleGameScope(
        gameKey: effectiveKey,
        badge: badge,
        generation: 5,
        defaultLevel: 50,
        facilityLabel: '对战地铁',
        typeChartNote: '属性表按第五世代规则；游戏内无妖精系。',
        damageNote: '按第五世代伤害公式估算，适合对战地铁与 N 战参考。',
      ),
    'B2W2' => BattleGameScope(
        gameKey: effectiveKey,
        badge: badge,
        generation: 5,
        defaultLevel: 50,
        facilityLabel: '世界对战会场',
        typeChartNote: '属性表按第五世代规则；游戏内无妖精系。',
        damageNote: '按第五世代伤害公式估算，适合对战地铁与世界对战参考。',
      ),
    'X/Y' => BattleGameScope(
        gameKey: effectiveKey,
        badge: badge,
        generation: 6,
        defaultLevel: 50,
        facilityLabel: '对战城堡',
        typeChartNote: '含妖精系与 Mega 进化世代；此处仅算属性与基础伤害。',
        damageNote: '按第六世代伤害公式估算，适合对战城堡与冠军战参考。',
      ),
    'ORAS' => BattleGameScope(
        gameKey: effectiveKey,
        badge: badge,
        generation: 6,
        defaultLevel: 50,
        facilityLabel: '对战 Maison',
        typeChartNote: '含妖精系与 Mega 进化世代；此处仅算属性与基础伤害。',
        damageNote: '按第六世代伤害公式估算，适合对战 Maison 参考。',
      ),
    'USUM' => BattleGameScope(
        gameKey: effectiveKey,
        badge: badge,
        generation: 7,
        defaultLevel: 50,
        facilityLabel: '对战树',
        typeChartNote: '含 Z 招式世代；此处不算 Z 与极巨化，仅基础伤害参考。',
        damageNote: '按第七世代伤害公式估算，适合对战树与究极 Necrozma 战参考。',
      ),
    _ => BattleGameScope(
        gameKey: effectiveKey,
        badge: badge,
        generation: 4,
        defaultLevel: 50,
        facilityLabel: '对战设施',
        typeChartNote: '属性表仅供参考，请以当前游戏内机制为准。',
        damageNote: '按通用伤害公式估算，仅供快速参考。',
      ),
  };
}
