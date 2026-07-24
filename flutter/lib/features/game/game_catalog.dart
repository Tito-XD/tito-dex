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

String badgeForGame(String gameKey) => _badgeToGameKey[gameKey] ?? 'HGSS';

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

/// Grid bottom sheet — 23 games with icon slot. Editions with sub-versions
/// open a secondary sheet where the user can choose the merged edition or a
/// specific flavor (e.g. 朱/紫 → 朱, 紫, or 合并版本).
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
                      childAspectRatio: 0.82,
                    ),
                    itemCount: GameEdition.all.length,
                    itemBuilder: (context, index) {
                      final edition = GameEdition.all[index];
                      final isSelected = edition.slug == current.slug;
                      final displayEdition =
                          isSelected ? current : edition;
                      return Material(
                        color: isSelected
                            ? const Color(0xFFFFF3B0)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () async {
                            final result = await _resolveEditionWithFlavor(
                              context,
                              edition: edition,
                              current: current,
                            );
                            if (context.mounted && result != null) {
                              Navigator.pop(context, result);
                            }
                          },
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
                                _GameEditionGridIcon(edition: displayEdition),
                                const SizedBox(height: 6),
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

/// List bottom sheet (used in detail pages). Same merged-or-flavor behavior as
/// the grid picker.
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
                      final displayEdition =
                          isSelected ? current : edition;
                      return ListTile(
                        leading: GameEditionIcon(
                          edition: displayEdition,
                          size: 32,
                        ),
                        title: Text(edition.labelZh),
                        subtitle: edition.hasPokeApiData
                            ? null
                            : const Text('暂无 PokeAPI 数据'),
                        trailing: isSelected
                            ? const Icon(Icons.check_rounded)
                            : null,
                        selected: isSelected,
                        onTap: () async {
                          final result = await _resolveEditionWithFlavor(
                            context,
                            edition: edition,
                            current: current,
                          );
                          if (context.mounted && result != null) {
                            Navigator.pop(context, result);
                          }
                        },
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

/// If the edition has multiple flavors, push a secondary flavor picker;
/// otherwise return the edition itself.
Future<GameEdition?> _resolveEditionWithFlavor(
  BuildContext context, {
  required GameEdition edition,
  required GameEdition current,
}) async {
  if (!edition.hasFlavorVersions) {
    return edition.withFlavor(null);
  }
  return _showFlavorPicker(context, edition: edition, current: current);
}

/// Secondary bottom sheet for choosing a merged edition or one of its flavors.
Future<GameEdition?> _showFlavorPicker(
  BuildContext context, {
  required GameEdition edition,
  required GameEdition current,
}) {
  return showModalBottomSheet<GameEdition>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final flavors = edition.flavorVersions;
      return SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.7,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    edition.labelZh,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: flavors.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final isSelected =
                            current.slug == edition.slug &&
                            current.selectedFlavor == null;
                        return ListTile(
                          leading: GameEditionIcon(edition: edition, size: 32),
                          title: const Text('合并版本'),
                          trailing: isSelected
                              ? const Icon(Icons.check_rounded)
                              : null,
                          selected: isSelected,
                          onTap: () => Navigator.pop(
                            context,
                            edition.withFlavor(null),
                          ),
                        );
                      }
                      final flavor = flavors[index - 1];
                      final isSelected =
                          current.slug == edition.slug &&
                          current.selectedFlavor == flavor;
                      return ListTile(
                        leading: GameEditionIcon(
                          edition: edition.withFlavor(flavor),
                          size: 32,
                        ),
                        title: Text(localizeFlavorVersion(flavor)),
                        trailing: isSelected
                            ? const Icon(Icons.check_rounded)
                            : null,
                        selected: isSelected,
                        onTap: () => Navigator.pop(
                          context,
                          edition.withFlavor(flavor),
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

/// Short code for the letter-badge fallback — the ASCII tag inside the
/// label's parentheses ('心金/魂银 (HGSS)' → 'HGSS').
String gameEditionShortCode(GameEdition edition) {
  final label = edition.labelZh;
  final open = label.lastIndexOf('(');
  final close = label.lastIndexOf(')');
  if (open >= 0 && close > open + 1) {
    return label.substring(open + 1, close);
  }
  return edition.slug.length > 4
      ? edition.slug.substring(0, 4).toUpperCase()
      : edition.slug.toUpperCase();
}

/// Game icon: bundled official HOME icon for Gen VI+, version-tinted letter
/// badge for older titles.
class GameEditionIcon extends StatelessWidget {
  const GameEditionIcon({super.key, required this.edition, this.size = 40});

  final GameEdition edition;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = edition.iconAsset;
    if (asset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _LetterBadge(
            edition: edition,
            size: size,
          ),
        ),
      );
    }
    return _LetterBadge(edition: edition, size: size);
  }
}

class _LetterBadge extends StatelessWidget {
  const _LetterBadge({required this.edition, required this.size});

  final GameEdition edition;
  final double size;

  @override
  Widget build(BuildContext context) {
    final code = gameEditionShortCode(edition);
    final accent = edition.accentColor;
    final dark = accent.computeLuminance() < 0.4;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: const Color(0x3318283B), width: 1),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.08),
          child: Text(
            code,
            style: TextStyle(
              fontSize: size * 0.34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: dark ? Colors.white : const Color(0xFF221F26),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameEditionGridIcon extends StatelessWidget {
  const _GameEditionGridIcon({required this.edition});

  final GameEdition edition;

  @override
  Widget build(BuildContext context) {
    return GameEditionIcon(edition: edition, size: 40);
  }
}
