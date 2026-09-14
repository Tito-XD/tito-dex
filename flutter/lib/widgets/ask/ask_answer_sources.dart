import 'package:flutter/material.dart';

import '../../features/journey/progression_hints.dart';
import '../../l10n/app_zh.dart';
import '../../theme/app_visual_style.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import '../../theme/trainer_journal.dart';
import 'ask_paper_style.dart';

typedef AskTitoDexSourceOpener = Future<bool> Function(Uri uri);

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: enabled
            ? TitoColors.skyBlue.withValues(alpha: 0.38)
            : TitoColors.cardWarm,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: appVisualStyle.usesTrainerJournal
              ? TrainerJournal.smallEdge
              : TitoColors.ink.withValues(alpha: 0.62),
          width: appVisualStyle.usesTrainerJournal
              ? TitoBorders.journalHairline
              : TitoBorders.element,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.remove_circle_outline,
            size: 11,
            color: enabled ? TitoColors.deepBlue : TitoColors.mutedInk,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: SecondaryTypography.onCard.small12.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class AskAnswerEvidenceSummary extends StatelessWidget {
  const AskAnswerEvidenceSummary({
    super.key,
    required this.sources,
    required this.sourceKinds,
    required this.sourceOpener,
    this.evidence,
  });

  final AskTitoDexEvidence? evidence;
  final List<ProgressionSource> sources;
  final List<String> sourceKinds;
  final AskTitoDexSourceOpener sourceOpener;

  @override
  Widget build(BuildContext context) {
    final hasSources = sources.isNotEmpty;
    final verified =
        evidence?.basis == 'structured' &&
        evidence?.scope == 'game' &&
        evidence?.complete == true;
    final label = evidence?.basis == 'structured'
        ? evidence!.complete
              ? evidence!.scope == 'game'
                    ? AppZh.askTitoDexStructuredGame
                    : AppZh.askTitoDexStructuredGeneral
              : AppZh.askTitoDexStructuredPartial
        : hasSources
        ? AppZh.askTitoDexSourcesAvailable(sources.length)
        : AppZh.askTitoDexEvidenceUnverified;
    return Semantics(
      button: hasSources,
      label: hasSources ? AppZh.askTitoDexViewCitations(label) : label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('ask-titodex-source-summary'),
          borderRadius: BorderRadius.circular(TitoRadii.md),
          onTap: hasSources
              ? () => showAskAnswerSources(
                  context,
                  sources: sources,
                  sourceKinds: sourceKinds,
                  sourceOpener: sourceOpener,
                )
              : null,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: TitoColors.skyBlue.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(TitoRadii.md),
              border: Border.all(
                color: appVisualStyle.usesTrainerJournal
                    ? TrainerJournal.smallEdge
                    : TitoColors.ink.withValues(alpha: 0.45),
                width: appVisualStyle.usesTrainerJournal
                    ? TitoBorders.journalElement
                    : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  verified
                      ? Icons.verified_user_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: verified ? TitoColors.mint : TitoColors.coral,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    style: SecondaryTypography.onCard.small12.copyWith(
                      color: TitoColors.deepBlue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (hasSources) ...[
                  Text(
                    AppZh.viewAction,
                    style: SecondaryTypography.onCard.small12.copyWith(
                      color: TitoColors.mutedInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showAskAnswerSources(
  BuildContext context, {
  required List<ProgressionSource> sources,
  required List<String> sourceKinds,
  required AskTitoDexSourceOpener sourceOpener,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      key: const Key('ask-titodex-source-sheet'),
      expand: false,
      initialChildSize: 0.68,
      minChildSize: 0.42,
      maxChildSize: 0.92,
      builder: (context, scrollController) => SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${AppZh.askTitoDexSourceSheetTitle} · ${sources.length}',
                      style: SecondaryTypography.onCard.h15,
                    ),
                  ),
                  IconButton(
                    key: const Key('ask-titodex-source-sheet-close'),
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                AppZh.askTitoDexSourceSheetHint,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                  height: 1.35,
                ),
              ),
            ),
            if (sourceKinds.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final sourceKind in sourceKinds)
                      _StatusPill(
                        label: _sourceKindLabel(sourceKind),
                        enabled: true,
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: sources.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) => _SourceReferenceTile(
                  index: index,
                  source: sources[index],
                  sourceOpener: sourceOpener,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SourceReferenceTile extends StatelessWidget {
  const _SourceReferenceTile({
    required this.index,
    required this.source,
    required this.sourceOpener,
  });

  final int index;
  final ProgressionSource source;
  final AskTitoDexSourceOpener sourceOpener;

  @override
  Widget build(BuildContext context) {
    final uri = _safeSourceUri(source.url);
    final host = uri == null
        ? AppZh.askTitoDexSourceLinkInvalid
        : _sourceHost(uri);
    final accessedAt = _sourceAccessDate(source.accessedAt);
    final tile = askPaperTileStyle(
      context,
      paper: TitoColors.card,
      outlineAlpha: 0.38,
    );
    return Material(
      color: tile.fill,
      borderRadius: tile.borderRadius,
      child: ListTile(
        key: ValueKey('ask-titodex-source-$index'),
        enabled: uri != null,
        shape: tile.shape,
        leading: SizedBox(
          width: 30,
          child: Text(
            '[${index + 1}]',
            textAlign: TextAlign.center,
            style: SecondaryTypography.onCard.small12.copyWith(
              color: TitoColors.deepBlue,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(
          source.title,
          style: SecondaryTypography.onCard.body14.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              accessedAt == null
                  ? host
                  : AppZh.askTitoDexSourceAccessed(host, accessedAt),
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              source.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: uri == null ? TitoColors.mutedInk : TitoColors.deepBlue,
                decoration: uri == null
                    ? TextDecoration.none
                    : TextDecoration.underline,
              ),
            ),
          ],
        ),
        trailing: Icon(
          uri == null ? Icons.link_off_rounded : Icons.open_in_new_rounded,
          size: 18,
        ),
        onTap: uri == null
            ? null
            : () async {
                var opened = false;
                try {
                  opened = await sourceOpener(uri);
                } on Object {
                  opened = false;
                }
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppZh.askTitoDexSourceLinkUnavailable),
                    ),
                  );
                }
              },
      ),
    );
  }
}

List<ProgressionSource> uniqueAskAnswerSources(
  List<ProgressionSource> sources,
) {
  final seen = <String>{};
  final unique = <ProgressionSource>[];
  for (final source in sources) {
    final uri = _safeSourceUri(source.url);
    final key =
        uri?.replace(fragment: '').toString() ??
        '${source.title.trim()}\n${source.url.trim()}';
    if (seen.add(key)) unique.add(source);
  }
  return List.unmodifiable(unique);
}

Uri? _safeSourceUri(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

String _sourceHost(Uri uri) =>
    uri.host.startsWith('www.') ? uri.host.substring('www.'.length) : uri.host;

String? _sourceAccessDate(String raw) {
  final value = DateTime.tryParse(raw);
  if (value == null) return null;
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _sourceKindLabel(String value) => switch (value) {
  'pokeapi' => 'PokeAPI',
  'strategywiki' => 'StrategyWiki',
  'wikidata' => 'Wikidata',
  'tavily' => 'Tavily',
  'deepseek-native' => AppZh.askTitoDexSourceDeepseekWeb,
  'brave' => 'Brave Search',
  _ => value,
};
