import '../../l10n/game_zh.dart';

/// Playable / upcoming game slots — badge cycles in this order.
const gameBadgeCycle = <String>[
  'HGSS',
  'Pt',
  'B/W',
  'B2W2',
  'X/Y',
  'ORAS',
  'USUM',
];

const _badgeToGameKey = <String, String>{
  'HGSS': 'SoulSilver',
  'Pt': 'Platinum',
  'B/W': 'BlackWhite',
  'B2W2': 'Black2White2',
  'X/Y': 'XY',
  'ORAS': 'ORAS',
  'USUM': 'USUM',
};

const _gameKeyToBadge = <String, String>{
  'SoulSilver': 'HGSS',
  'HeartGold': 'HGSS',
  'Platinum': 'Pt',
  'BlackWhite': 'B/W',
  'Black2White2': 'B2W2',
  'XY': 'X/Y',
  'ORAS': 'ORAS',
  'USUM': 'USUM',
};

String badgeForGame(String gameKey) => _gameKeyToBadge[gameKey] ?? 'HGSS';

String gameKeyForBadge(String badge) =>
    _badgeToGameKey[badge] ?? _badgeToGameKey['HGSS']!;

String cycleGameBadge(String currentBadge) {
  final index = gameBadgeCycle.indexOf(currentBadge);
  if (index < 0) {
    return gameBadgeCycle.first;
  }
  return gameBadgeCycle[(index + 1) % gameBadgeCycle.length];
}

String cycleGameKey(String currentGameKey) {
  final badge = badgeForGame(currentGameKey);
  final nextBadge = cycleGameBadge(badge);
  return gameKeyForBadge(nextBadge);
}

String localizedGameTitle(String gameKey) {
  return localizeGame(gameKey);
}
