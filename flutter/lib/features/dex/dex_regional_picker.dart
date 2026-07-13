import 'package:flutter/material.dart';

import '../../l10n/app_zh.dart';
import 'dex_game_scope.dart';
import '../game/game_edition.dart';

/// v0.4.1: Bottom sheet regional dex picker (replaces tap-to-cycle on national tab).
Future<DexRegionalPokedex?> showRegionalPokedexPicker(
  BuildContext context, {
  required DexRegionalPokedex selected,
  GameEdition gameEdition = defaultGameEdition,
}) {
  return showModalBottomSheet<DexRegionalPokedex>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            final highlights = {
              gameEdition.defaultRegionalPokedex,
              DexRegionalPokedex.national,
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    AppZh.dexPickRegionalPokedex,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: DexRegionalPokedex.values.length,
                    itemBuilder: (context, index) {
                      final scope = DexRegionalPokedex.values[index];
                      final isSelected = scope == selected;
                      return ListTile(
                        leading: highlights.contains(scope)
                            ? const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFF6B6B),
                              )
                            : const Icon(Icons.map_rounded),
                        title: Text(AppZh.dexRegionalDexTitle(scope.labelZh)),
                        trailing: isSelected
                            ? const Icon(Icons.check_rounded)
                            : null,
                        selected: isSelected,
                        onTap: () => Navigator.pop(context, scope),
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
