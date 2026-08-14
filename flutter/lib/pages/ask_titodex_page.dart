import 'dart:async';

import 'package:flutter/material.dart';

import '../features/companion/companion_repository.dart';
import '../features/game/game_edition.dart';
import '../features/journey/ask_titodex_service.dart';
import '../features/journey/ask_titodex_settings.dart';
import '../features/journey/progression_hints.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../widgets/ask_titodex_loading.dart';
import '../widgets/retro_forms.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';

class AskTitoDexPage extends StatefulWidget {
  const AskTitoDexPage({
    super.key,
    required this.journey,
    required this.edition,
    this.service,
  });

  final CurrentJourney journey;
  final GameEdition edition;
  final AskTitoDexService? service;

  @override
  State<AskTitoDexPage> createState() => _AskTitoDexPageState();
}

class _AskTitoDexPageState extends State<AskTitoDexPage> {
  late final TextEditingController _questionController;
  late final AskTitoDexService _service;
  AskTitoDexContext? _context;
  AskTitoDexResult? _result;
  AskTitoDexWorkerStatus _workerStatus =
      const AskTitoDexWorkerStatus.checking();
  AskTitoDexProgress _progress = AskTitoDexProgress.checkingLocal;
  var _requestSeed = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController();
    _service = widget.service ?? askTitoDexService;
    askTitoDexSettings.addListener(_handleSettingsChanged);
    unawaited(companionRepository.load());
    _prepareContext();
    _checkConnection();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !askTitoDexSettings.noticeAcknowledged) {
        _showOnlineNotice();
      }
    });
  }

  void _handleSettingsChanged() => _checkConnection();

  Future<void> _checkConnection() async {
    if (mounted) {
      setState(() => _workerStatus = const AskTitoDexWorkerStatus.checking());
    }
    final status = await _service.checkConnection();
    if (mounted) setState(() => _workerStatus = status);
  }

  Future<void> _prepareContext() async {
    final initial = AskTitoDexContext.fromJourney(
      widget.journey,
      widget.edition,
    );
    final resolved = await _service.buildContext(initial);
    if (mounted) setState(() => _context = resolved);
  }

  Future<void> _showOnlineNotice() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppZh.askTitoDexNoticeTitle),
        content: const Text(AppZh.askTitoDexNoticeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppZh.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppZh.askTitoDexNoticeAccept),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await askTitoDexSettings.acknowledgeNotice();
    }
  }

  Future<void> _submit() async {
    final contextValue = _context;
    final question = _questionController.text.trim();
    if (contextValue == null || question.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _result = null;
      _progress = AskTitoDexProgress.checkingLocal;
      _requestSeed += 1;
    });
    final result = await _service.ask(
      question,
      contextValue,
      onProgress: (progress) {
        if (mounted) setState(() => _progress = progress);
      },
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
    });
    if (result.errorCode?.contains('_fallback') == true) {
      unawaited(_checkConnection());
    }
  }

  @override
  void dispose() {
    askTitoDexSettings.removeListener(_handleSettingsChanged);
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contextValue = _context;
    return SecondaryPageScaffold(
      title: AppZh.askTitoDexTitle,
      subtitle: AppZh.askTitoDexSubtitle,
      children: [
        _ConnectionStatusCard(
          status: _workerStatus,
          onRefresh: _checkConnection,
        ),
        const SizedBox(height: 14),
        StickerCard(
          variant: StickerVariant.softYellow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppZh.askTitoDexContextTitle,
                style: SecondaryTypography.onCard.h15,
              ),
              const SizedBox(height: 4),
              Text(
                AppZh.askTitoDexContextHint,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
              const SizedBox(height: 10),
              if (contextValue == null)
                const LinearProgressIndicator()
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InputChip(
                      avatar: const Icon(Icons.sports_esports, size: 18),
                      label: Text(
                        contextValue.game == null
                            ? AppZh.askTitoDexGameUnknown
                            : localizeFlavorVersion(contextValue.game!),
                      ),
                    ),
                    if (contextValue.includeLocation &&
                        contextValue.locationId != null &&
                        contextValue.locationLabel != null)
                      InputChip(
                        avatar: const Icon(Icons.place_outlined, size: 18),
                        label: Text(
                          localizeLocation(contextValue.locationLabel!),
                        ),
                        onDeleted: () => setState(
                          () => _context = contextValue.copyWith(
                            includeLocation: false,
                          ),
                        ),
                      ),
                    if (contextValue.includeLocation &&
                        contextValue.locationLabel != null &&
                        contextValue.locationId == null)
                      const Text(AppZh.askTitoDexLocationNotSent),
                    if (contextValue.includeBadges)
                      InputChip(
                        avatar: const Icon(Icons.military_tech, size: 18),
                        label: Text(
                          AppZh.askTitoDexBadgeContext(
                            contextValue.badgeIds.length,
                          ),
                        ),
                        onDeleted: () => setState(
                          () => _context = contextValue.copyWith(
                            includeBadges: false,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('ask-titodex-question'),
                controller: _questionController,
                minLines: 2,
                maxLines: 4,
                maxLength: 240,
                textInputAction: TextInputAction.send,
                decoration: retroInsetDecoration(
                  labelText: AppZh.askTitoDexQuestionLabel,
                  hintText: AppZh.askTitoDexQuestionHint,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('ask-titodex-submit'),
                onPressed: _loading || contextValue == null ? null : _submit,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  _loading ? AppZh.askTitoDexLoading : AppZh.askTitoDexSubmit,
                ),
              ),
            ],
          ),
        ),
        if (_loading) ...[
          const SizedBox(height: 14),
          AskTitoDexLoadingCard(
            journey: widget.journey,
            progress: _progress,
            requestSeed: _requestSeed,
          ),
        ],
        if (_result != null) ...[
          const SizedBox(height: 14),
          _AnswerCard(result: _result!, onRetry: _submit),
        ],
      ],
    );
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({required this.status, required this.onRefresh});

  final AskTitoDexWorkerStatus status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, hint) = switch (status.availability) {
      AskTitoDexAvailability.checking => (
        Icons.sync_rounded,
        TitoColors.skyBlue,
        AppZh.askTitoDexWorkerChecking,
        '',
      ),
      AskTitoDexAvailability.online => (
        Icons.cloud_done_rounded,
        TitoColors.mint,
        AppZh.askTitoDexWorkerOnline,
        AppZh.askTitoDexStatusOnlineHint,
      ),
      AskTitoDexAvailability.disabled => (
        Icons.cloud_off_rounded,
        TitoColors.softYellow,
        AppZh.askTitoDexWorkerDisabled,
        AppZh.askTitoDexStatusDisabledHint,
      ),
      AskTitoDexAvailability.unavailable => (
        Icons.cloud_off_rounded,
        TitoColors.coral,
        AppZh.askTitoDexWorkerUnavailable,
        AppZh.askTitoDexStatusUnavailableHint,
      ),
    };

    return StickerCard(
      key: const Key('ask-titodex-connection-status'),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: TitoColors.ink,
                    width: TitoBorders.element,
                  ),
                ),
                child: status.availability == AskTitoDexAvailability.checking
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(icon, size: 19, color: TitoColors.deepBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: SecondaryTypography.onCard.h15),
              ),
              IconButton(
                key: const Key('ask-titodex-refresh-connection'),
                tooltip: AppZh.askTitoDexWorkerRefresh,
                onPressed:
                    status.availability == AskTitoDexAvailability.checking
                    ? null
                    : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (status.availability == AskTitoDexAvailability.online) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StatusPill(
                  label: AppZh.askTitoDexQwenConfigured,
                  enabled: status.qwenConfigured,
                ),
                _StatusPill(
                  label: AppZh.askTitoDexAiSearchEnabled,
                  enabled: status.aiSearchEnabled,
                ),
                _StatusPill(
                  label: AppZh.askTitoDexCuratedSourcesEnabled,
                  enabled: status.curatedSourcesEnabled,
                ),
                _StatusPill(
                  label: AppZh.askTitoDexBraveNotConnected,
                  enabled: status.braveSearchEnabled,
                ),
              ],
            ),
          ],
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              hint,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: enabled
            ? TitoColors.mint.withValues(alpha: 0.55)
            : TitoColors.skyBlue.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TitoColors.ink, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.remove_circle_outline,
            size: 13,
            color: enabled ? TitoColors.deepBlue : TitoColors.mutedInk,
          ),
          const SizedBox(width: 4),
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

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.result, required this.onRetry});

  final AskTitoDexResult result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (result.status == AskTitoDexStatus.failed) {
      return StickerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              result.errorCode == 'upstream_timeout'
                  ? AppZh.askTitoDexTimeout
                  : AppZh.askTitoDexNetworkFailed,
              style: SecondaryTypography.onCard.body14,
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              key: const Key('ask-titodex-retry'),
              onPressed: onRetry,
              child: const Text(AppZh.retry),
            ),
          ],
        ),
      );
    }
    if (result.status == AskTitoDexStatus.needsClarification ||
        result.status == AskTitoDexStatus.noMatch) {
      final fallbackMessage = result.errorCode == 'online_timeout_fallback'
          ? AppZh.askTitoDexOnlineTimeoutFallback
          : result.errorCode?.contains('_fallback') == true
          ? AppZh.askTitoDexOnlineFallback
          : result.onlineAttempted && result.modelUsed
          ? AppZh.askTitoDexOnlineSearchedNoMatch
          : null;
      return StickerCard(
        variant: StickerVariant.softYellow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.followUp ?? AppZh.askTitoDexNeedsClarification,
              key: const Key('ask-titodex-follow-up'),
              style: SecondaryTypography.onCard.body14,
            ),
            if (fallbackMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                fallbackMessage,
                key: const Key('ask-titodex-fallback-trace'),
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.deepBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      );
    }
    return StickerCard(
      variant: StickerVariant.mint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StickerIconPlate(
                icon: Icons.fact_check_outlined,
                color: TitoColors.mint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _answerModeLabel(result.answerMode),
                  style: SecondaryTypography.onCard.h15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            key: const Key('ask-titodex-answer-trace'),
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatusPill(
                label: result.modelUsed
                    ? AppZh.askTitoDexTraceModel
                    : AppZh.askTitoDexTraceNoModel,
                enabled: result.modelUsed,
              ),
              if (result.aiSearchUsed)
                const _StatusPill(
                  label: AppZh.askTitoDexTraceAiSearch,
                  enabled: true,
                ),
              for (final sourceKind in result.sourceKinds)
                _StatusPill(label: _sourceKindLabel(sourceKind), enabled: true),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            result.answer ?? '',
            key: const Key('ask-titodex-answer'),
            style: SecondaryTypography.onCard.body14.copyWith(height: 1.45),
          ),
          if (result.unknowns.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              AppZh.askTitoDexUnknownWarning,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.deepBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (result.sources.isNotEmpty) ...[
            const Divider(height: 22),
            Text(
              '${AppZh.askTitoDexSources}：${result.sources.map((source) => source.title).join(' · ')}',
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _answerModeLabel(AskTitoDexAnswerMode mode) => switch (mode) {
  AskTitoDexAnswerMode.localAudited => AppZh.askTitoDexRouteLocal,
  AskTitoDexAnswerMode.auditedOnline => AppZh.askTitoDexRouteAuditedOnline,
  AskTitoDexAnswerMode.aiSearchAudited => AppZh.askTitoDexRouteAiSearch,
  AskTitoDexAnswerMode.curatedSourcesDeterministic =>
    AppZh.askTitoDexRouteCuratedDeterministic,
  AskTitoDexAnswerMode.curatedSourcesQwen => AppZh.askTitoDexRouteCuratedQwen,
  AskTitoDexAnswerMode.noMatch => AppZh.askTitoDexOnlineSearchedNoMatch,
};

String _sourceKindLabel(String value) => switch (value) {
  'pokeapi' => 'PokeAPI',
  'strategywiki' => 'StrategyWiki',
  'wikidata' => 'Wikidata',
  _ => value,
};
