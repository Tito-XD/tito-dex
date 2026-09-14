import 'package:flutter/material.dart';

import '../../features/dex/dex_game_scope.dart';
import '../../features/journey/ask_titodex_history.dart';
import '../../l10n/app_zh.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import 'ask_paper_style.dart';

enum AskHistoryManagerAction { compact, clear }

class AskHistoryManagerSheet extends StatelessWidget {
  const AskHistoryManagerSheet({super.key, required this.entries});

  final List<AskTitoDexHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final newestFirst = entries.reversed.toList(growable: false);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 8, 12),
              child: Row(
                children: [
                  const Icon(Icons.forum_outlined),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      AppZh.askTitoDexHistorySheetTitle(
                        entries.length,
                        askTitoDexHistoryLimit,
                      ),
                      style: SecondaryTypography.onCard.h15,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                AppZh.askTitoDexHistorySheetHint(askTitoDexContextEntryLimit),
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: newestFirst.isEmpty
                  ? Center(
                      child: Text(
                        AppZh.askTitoDexHistoryEmpty,
                        style: SecondaryTypography.onCard.body14.copyWith(
                          color: TitoColors.mutedInk,
                        ),
                      ),
                    )
                  : ListView.separated(
                      key: const Key('ask-titodex-history-list'),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: newestFirst.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final entry = newestFirst[index];
                        final tile = askPaperTileStyle(
                          context,
                          paper: TitoColors.cardWarm,
                          outlineAlpha: 0.2,
                        );
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: tile.fill,
                            borderRadius: BorderRadius.circular(TitoRadii.md),
                            border: Border.all(
                              color: tile.outline,
                              width: tile.outlineWidth,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.question,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: SecondaryTypography.onCard.body14
                                      .copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_assistantGameLabel(entry.game)} · ${_formatHistoryTime(entry.createdAt)}',
                                  style: SecondaryTypography.onCard.small12
                                      .copyWith(color: TitoColors.mutedInk),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('ask-titodex-compact-history'),
                      onPressed: entries.length > 10
                          ? () => Navigator.pop(
                              context,
                              AskHistoryManagerAction.compact,
                            )
                          : null,
                      icon: const Icon(Icons.compress_rounded),
                      label: Text(AppZh.askTitoDexHistoryCompactAction),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('ask-titodex-clear-history'),
                      onPressed: entries.isEmpty
                          ? null
                          : () => Navigator.pop(
                              context,
                              AskHistoryManagerAction.clear,
                            ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(AppZh.askTitoDexHistoryClearAction),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatHistoryTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}

String _assistantGameLabel(String value) => flavorVersionLabelZh(value);
