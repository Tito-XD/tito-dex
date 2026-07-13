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

/// Short label for home header pill (before full name in grid picker).
String homeGameBadgeLabel(GameEdition edition) {
  final label = edition.labelZh;
  final paren = label.indexOf(' (');
  if (paren > 0) {
    return label.substring(0, paren);
  }
  return label.length > 8 ? label.substring(0, 8) : label;
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

/// Grid bottom sheet — 23 games with icon slot (name-only until assets land).
Future<GameEdition?> showGameEditionGridPicker(
  BuildContext context, {
  GameEdition? selected,
}) {
  return showModalBottomSheet<GameEdition>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final current = selected ?? defaultGameEdition;
      final columns = MediaQuery.sizeOf(context).width >= 520 ? 4 : 3;
      return SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.62,
          minChildSize: 0.4,
          maxChildSize: 0.92,
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
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.92,
                    ),
                    itemCount: GameEdition.all.length,
                    itemBuilder: (context, index) {
                      final edition = GameEdition.all[index];
                      final isSelected = edition.slug == current.slug;
                      return Material(
                        color: isSelected
                            ? const Color(0xFFFFF3B0)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => Navigator.pop(context, edition),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF18283B)
                                    : const Color(0x3318283B),
                                width: isSelected ? 2.5 : 1.5,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  edition.labelZh,
                                  textAlign: TextAlign.center,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

/// List bottom sheet (legacy — prefer [showGameEditionGridPicker] on home).
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
