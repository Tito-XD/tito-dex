import 'package:flutter/material.dart';

import '../../l10n/game_zh.dart';
import 'game_edition.dart';

/// Playable / upcoming game slots — badge cycles in this order (legacy).
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

String badgeForEdition(GameEdition edition) {
  if (edition.journeyGameKey != null) {
    return badgeForGame(edition.journeyGameKey!);
  }
  return edition.slug.toUpperCase();
}

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

/// Bottom sheet picker for all 23 [GameEdition] entries.
Future<GameEdition?> showGameEditionPicker(
  BuildContext context, {
  GameEdition? selected,
}) {
  return showModalBottomSheet<GameEdition>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final current = selected ?? defaultGameEdition;
      return SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    '选择游戏版本',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: GameEdition.all.length,
                    itemBuilder: (context, index) {
                      final edition = GameEdition.all[index];
                      final isSelected = edition.slug == current.slug;
                      return ListTile(
                        leading: edition.hasPokeApiData
                            ? const Icon(Icons.videogame_asset_rounded)
                            : const Icon(Icons.info_outline_rounded),
                        title: Text(edition.labelZh),
                        subtitle: edition.hasPokeApiData
                            ? null
                            : const Text('暂无 PokeAPI 数据'),
                        trailing: isSelected
                            ? const Icon(Icons.check_rounded)
                            : null,
                        selected: isSelected,
                        onTap: () => Navigator.pop(context, edition),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
