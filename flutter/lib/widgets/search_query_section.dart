import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_motion.dart';
import 'sticker_card.dart';

/// Search shortcuts appear as one scrollable row until explicitly expanded.
class SearchQuerySection extends StatefulWidget {
  const SearchQuerySection({
    super.key,
    required this.title,
    required this.queries,
    required this.onQuery,
    this.onClear,
    this.variant = StickerVariant.cream,
  });

  final String title;
  final List<String> queries;
  final ValueChanged<String> onQuery;
  final VoidCallback? onClear;
  final StickerVariant variant;

  @override
  State<SearchQuerySection> createState() => _SearchQuerySectionState();
}

class _SearchQuerySectionState extends State<SearchQuerySection> {
  final _scroll = ScrollController();
  bool _expanded = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StickerCard(
    variant: widget.variant,
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SecondaryTypography.onCard.h15,
              ),
            ),
            if (widget.onClear != null)
              TextButton(
                onPressed: widget.onClear,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(AppZh.searchRecentClear),
              ),
            if (widget.queries.length > 1)
              TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                icon: Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                ),
                label: Text(
                  _expanded
                      ? AppZh.searchQueriesCollapse
                      : AppZh.searchQueriesExpand,
                ),
              ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final chips = [
              for (final query in widget.queries)
                ActionChip(
                  key: ValueKey('search-query-$query'),
                  onPressed: () => widget.onQuery(query),
                  tooltip: query,
                  label: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth - 32,
                    ),
                    child: Text(
                      query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ];
            return AnimatedSize(
              duration: TitoMotion.duration(context, TitoMotion.emphasized),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              clipBehavior: Clip.none,
              child: _expanded
                  ? Wrap(spacing: 8, runSpacing: 4, children: chips)
                  : Scrollbar(
                      controller: _scroll,
                      thumbVisibility: true,
                      thickness: 2,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            for (var i = 0; i < chips.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              chips[i],
                            ],
                          ],
                        ),
                      ),
                    ),
            );
          },
        ),
      ],
    ),
  );
}
