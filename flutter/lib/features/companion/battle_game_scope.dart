import '../../l10n/app_locale.dart';
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
        facilityLabel: AppLocale.pick(zh: '对战开拓区', en: 'Battle Frontier'),
        typeChartNote: AppLocale.pick(
          zh: '属性表按现代数据参考；第四世代游戏内无妖精系。',
          en: 'Type chart uses modern data; Gen 4 has no Fairy type in-game.',
        ),
        damageNote: AppLocale.pick(
          zh: '按第四世代伤害公式估算，适合对战开拓区与高难度战参考。',
          en: 'Gen 4 damage formula. Useful for Battle Frontier and tough fights.',
        ),
      ),
    'B/W' => BattleGameScope(
        gameKey: gameKey,
        badge: badge,
        generation: 5,
        defaultLevel: 50,
        facilityLabel: AppLocale.pick(zh: '对战地铁', en: 'Battle Subway'),
        typeChartNote: AppLocale.pick(
          zh: '属性表按第五世代规则；游戏内无妖精系。',
          en: 'Type chart uses Gen 5 rules; no Fairy type in-game.',
        ),
        damageNote: AppLocale.pick(
          zh: '按第五世代伤害公式估算，适合对战地铁与 N 战参考。',
          en: 'Gen 5 damage formula. Useful for Battle Subway and N fights.',
        ),
      ),
    'B2W2' => BattleGameScope(
        gameKey: gameKey,
        badge: badge,
        generation: 5,
        defaultLevel: 50,
        facilityLabel: AppLocale.pick(zh: '世界对战会场', en: 'PWT'),
        typeChartNote: AppLocale.pick(
          zh: '属性表按第五世代规则；游戏内无妖精系。',
          en: 'Type chart uses Gen 5 rules; no Fairy type in-game.',
        ),
        damageNote: AppLocale.pick(
          zh: '按第五世代伤害公式估算，适合对战地铁与世界对战参考。',
          en: 'Gen 5 damage formula. Useful for the Subway and PWT.',
        ),
      ),
    'X/Y' || 'ORAS' => BattleGameScope(
        gameKey: gameKey,
        badge: badge,
        generation: 6,
        defaultLevel: 50,
        facilityLabel: AppLocale.pick(zh: '对战城堡', en: 'Battle Maison'),
        typeChartNote: AppLocale.pick(
          zh: '含妖精系与 Mega 进化世代；此处仅算属性与基础伤害。',
          en: 'Fairy and Mega era. Types and base damage only here.',
        ),
        damageNote: AppLocale.pick(
          zh: '按第六世代伤害公式估算，适合对战城堡与冠军战参考。',
          en: 'Gen 6 damage formula. Useful for Battle Maison and champion fights.',
        ),
      ),
    'SM' || 'USUM' || 'LGPE' => BattleGameScope(
        gameKey: gameKey,
        badge: badge,
        generation: 7,
        defaultLevel: 50,
        facilityLabel: AppLocale.pick(zh: '对战树', en: 'Battle Tree'),
        typeChartNote: AppLocale.pick(
          zh: '含 Z 招式世代；此处不算 Z 与极巨化，仅基础伤害参考。',
          en: 'Z-Move era. Z-Moves and Dynamax are not modeled.',
        ),
        damageNote: AppLocale.pick(
          zh: '按第七世代伤害公式估算，适合对战树参考。',
          en: 'Gen 7 damage formula. Useful for Battle Tree.',
        ),
      ),
    'SWSH' || 'BDSP' => BattleGameScope(
        gameKey: gameKey,
        badge: badge,
        generation: 8,
        defaultLevel: 50,
        facilityLabel: AppLocale.pick(zh: '对战塔', en: 'Battle Tower'),
        typeChartNote: AppLocale.pick(
          zh: '含极巨化世代；此处不算极巨化，仅基础伤害参考。',
          en: 'Dynamax era. Dynamax is not modeled here.',
        ),
        damageNote: AppLocale.pick(
          zh: '按第八世代伤害公式估算，适合对战塔参考。',
          en: 'Gen 8 damage formula. Useful for Battle Tower.',
        ),
      ),
    'SV' || 'LA' || 'LZA' || 'Champions' => BattleGameScope(
        gameKey: gameKey,
        badge: badge,
        generation: 9,
        defaultLevel: 50,
        facilityLabel: AppLocale.pick(zh: '对战设施', en: 'Battle facility'),
        typeChartNote: AppLocale.pick(
          zh: '第九世代规则参考；请以游戏内机制为准。',
          en: 'Gen 9 rules for reference. In-game mechanics win.',
        ),
        damageNote: AppLocale.pick(
          zh: '按第九世代伤害公式估算，仅供快速参考。',
          en: 'Gen 9 damage formula. Quick estimates only.',
        ),
      ),
    _ => BattleGameScope(
        gameKey: gameKey,
        badge: badge,
        generation: 4,
        defaultLevel: 50,
        facilityLabel: AppLocale.pick(zh: '对战设施', en: 'Battle facility'),
        typeChartNote: AppLocale.pick(
          zh: '属性表仅供参考，请以当前游戏内机制为准。',
          en: 'Type chart is a reference. In-game mechanics win.',
        ),
        damageNote: AppLocale.pick(
          zh: '按通用伤害公式估算，仅供快速参考。',
          en: 'Generic damage formula. Quick estimates only.',
        ),
      ),
  };
}
