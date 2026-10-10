import 'package:flutter/material.dart';

import '../../features/journey/progression_hints.dart';
import '../../features/journey/ask_titodex_source_browser.dart';
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
    this.result,
  });

  final AskTitoDexEvidence? evidence;
  final AskTitoDexResult? result;
  final List<ProgressionSource> sources;
  final List<String> sourceKinds;
  final AskTitoDexSourceOpener sourceOpener;

  @override
  Widget build(BuildContext context) {
    final hasSources = sources.isNotEmpty;
    final canInspect = hasSources || result != null;
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
      button: canInspect,
      label: canInspect ? AppZh.askTitoDexViewCitations(label) : label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('ask-titodex-source-summary'),
          borderRadius: BorderRadius.circular(TitoRadii.md),
          onTap: canInspect
              ? () => showAskAnswerSources(
                  context,
                  sources: sources,
                  result: result,
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
                if (canInspect) ...[
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
  AskTitoDexResult? result,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      key: const Key('ask-titodex-source-sheet'),
      expand: false,
      initialChildSize: sources.isEmpty ? 0.42 : 0.68,
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
                      sources.isEmpty
                          ? AppZh.askTitoDexAnswerDetails
                          : '${AppZh.askTitoDexSourceSheetTitle} · ${sources.length}',
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
            if (result != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Wrap(
                  key: const Key('ask-titodex-answer-trace'),
                  spacing: 9,
                  runSpacing: 4,
                  children: [
                    _AnswerMetaLabel(label: _answerModeLabel(result)),
                    _AnswerMetaLabel(
                      label: _modelTraceLabel(result),
                      emphasized: result.modelUsed,
                    ),
                    if (result.aiSearchUsed)
                      _AnswerMetaLabel(
                        label: AppZh.askTitoDexTraceAiSearch,
                        emphasized: true,
                      ),
                    if (sourceKinds.isNotEmpty)
                      _AnswerMetaLabel(
                        label: AppZh.askTitoDexTraceSearchRoutes(
                          sourceKinds.length,
                        ),
                        emphasized: true,
                      ),
                  ],
                ),
              ),
            ],
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
    final uri = askTitoDexSourceUri(source.url);
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
    final uri = askTitoDexSourceUri(source.url);
    final key =
        uri?.replace(fragment: '').toString() ??
        '${source.title.trim()}\n${source.url.trim()}';
    if (seen.add(key)) unique.add(source);
  }
  return List.unmodifiable(unique);
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
  'exa' => 'Exa',
  'pokeapi' => 'PokeAPI',
  'strategywiki' => 'StrategyWiki',
  'wikidata' => 'Wikidata',
  'tavily' => 'Tavily',
  'deepseek-native' => AppZh.askTitoDexSourceDeepseekWeb,
  'brave' => 'Brave Search',
  _ => value,
};

class _AnswerMetaLabel extends StatelessWidget {
  const _AnswerMetaLabel({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: emphasized ? TitoColors.mint : TitoColors.skyBlue,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: SecondaryTypography.onCard.small12.copyWith(
            color: emphasized ? TitoColors.deepBlue : TitoColors.mutedInk,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

String _modelTraceLabel(AskTitoDexResult result) {
  if (result.modelProviders.contains('deepseek-text')) {
    return result.modelProviders.contains('workers-ai-qwen')
        ? AppZh.askTitoDexTraceQwenDeepseek
        : AppZh.askTitoDexTraceDeepseekText;
  }
  return result.modelUsed
      ? AppZh.askTitoDexTraceModel
      : AppZh.askTitoDexTraceNoModel;
}

String _answerModeLabel(AskTitoDexResult result) {
  if (result.outlineMode == 'basic_web_outline') {
    return AppZh.askTitoDexBasicOutline;
  }
  if (result.modelProviders.contains('deepseek-text')) {
    final fallback = switch (result.answerMode) {
      AskTitoDexAnswerMode.curatedSourcesQwen =>
        AppZh.askTitoDexRouteCuratedFallback,
      AskTitoDexAnswerMode.auditedOnline =>
        AppZh.askTitoDexRouteAuditedFallback,
      AskTitoDexAnswerMode.aiSearchAudited =>
        AppZh.askTitoDexRouteAiSearchFallback,
      _ => null,
    };
    if (fallback != null) return fallback;
  }
  return switch (result.answerMode) {
    AskTitoDexAnswerMode.localAudited => AppZh.askTitoDexRouteLocal,
    AskTitoDexAnswerMode.auditedOnline => AppZh.askTitoDexRouteAuditedOnline,
    AskTitoDexAnswerMode.aiSearchAudited => AppZh.askTitoDexRouteAiSearch,
    AskTitoDexAnswerMode.curatedSourcesDeterministic =>
      AppZh.askTitoDexRouteCuratedDeterministic,
    AskTitoDexAnswerMode.curatedSourcesQwen => AppZh.askTitoDexRouteCuratedQwen,
    AskTitoDexAnswerMode.deepseekNativeSearch =>
      AppZh.askTitoDexRouteDeepseekNative,
    AskTitoDexAnswerMode.multiSourceQwen => AppZh.askTitoDexRouteMultiSource,
    AskTitoDexAnswerMode.noMatch => AppZh.askTitoDexOnlineSearchedNoMatch,
  };
}
