import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/companion/companion_repository.dart';
import '../features/game/game_edition.dart';
import '../features/journey/ask_titodex_entity_links.dart';
import '../features/journey/ask_titodex_history.dart';
import '../features/journey/ask_titodex_service.dart';
import '../features/journey/ask_titodex_settings.dart';
import '../features/journey/progression_hints.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
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
    this.historyStore,
    this.entityResolver,
  });

  final CurrentJourney journey;
  final GameEdition edition;
  final AskTitoDexService? service;
  final AskTitoDexHistoryStore? historyStore;
  final AskTitoDexEntityResolver? entityResolver;

  @override
  State<AskTitoDexPage> createState() => _AskTitoDexPageState();
}

class _AskTitoDexPageState extends State<AskTitoDexPage> {
  late final TextEditingController _questionController;
  late final ScrollController _answerScrollController;
  late final AskTitoDexService _service;
  late final AskTitoDexHistoryStore _historyStore;
  late final AskTitoDexEntityResolver _entityResolver;
  late final Future<void> _historyReady;
  AskTitoDexContext? _context;
  List<AskTitoDexHistoryEntry> _history = const [];
  AskTitoDexWorkerStatus _workerStatus =
      const AskTitoDexWorkerStatus.checking();
  AskTitoDexProgress _progress = AskTitoDexProgress.checkingLocal;
  var _requestSeed = 0;
  String? _submittedQuestion;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController();
    _answerScrollController = ScrollController();
    _service = widget.service ?? askTitoDexService;
    _historyStore = widget.historyStore ?? askTitoDexHistoryStore;
    _entityResolver = widget.entityResolver ?? askTitoDexEntityResolver;
    _historyReady = _loadHistory();
    askTitoDexSettings.addListener(_handleSettingsChanged);
    unawaited(companionRepository.load());
    _prepareContext();
    _checkConnection();
  }

  void _handleSettingsChanged() => _checkConnection();

  Future<void> _loadHistory() async {
    final loaded = await _historyStore.load();
    if (!mounted) return;
    setState(() => _history = loaded);
    _scrollToLatest();
  }

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

  Future<void> _submit([String? retryQuestion]) async {
    await _historyReady;
    if (!mounted) return;
    final contextValue = _context;
    final question = (retryQuestion ?? _questionController.text).trim();
    if (contextValue == null || question.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _submittedQuestion = question;
      _progress = AskTitoDexProgress.checkingLocal;
      _requestSeed += 1;
    });
    final result = await _service.ask(
      question,
      contextValue,
      history: askTitoDexRequestHistory(
        _history,
        game: contextValue.game ?? '',
      ),
      onProgress: (progress) {
        if (mounted) setState(() => _progress = progress);
      },
    );
    if (!mounted) return;
    final entry = AskTitoDexHistoryEntry(
      game: contextValue.game ?? 'unknown',
      question: question,
      result: result,
      createdAt: DateTime.now(),
    );
    List<AskTitoDexHistoryEntry> saved;
    try {
      saved = await _historyStore.append(entry);
    } on Object {
      saved = [..._history, entry];
      if (saved.length > askTitoDexHistoryLimit) {
        saved = saved.sublist(saved.length - askTitoDexHistoryLimit);
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _history = saved;
      _submittedQuestion = null;
      if (retryQuestion == null && result.status == AskTitoDexStatus.answered) {
        _questionController.clear();
      }
    });
    _scrollToLatest();
    if (result.errorCode?.contains('_fallback') == true) {
      unawaited(_checkConnection());
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_answerScrollController.hasClients) return;
      _answerScrollController.animateTo(
        _answerScrollController.position.maxScrollExtent,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    askTitoDexSettings.removeListener(_handleSettingsChanged);
    _questionController.dispose();
    _answerScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contextValue = _context;
    final pagePadding = DeviceLayout.pagePadding(context);
    final spacing = DeviceLayout.isCompact(context) ? 6.0 : 8.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            pagePadding.left,
            pagePadding.top,
            pagePadding.right,
            0,
          ),
          child: const SecondaryPageAppBar(title: AppZh.askTitoDexTitle),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              pagePadding.left,
              4,
              pagePadding.right,
              pagePadding.bottom + 4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ConnectionStatusCard(
                  status: _workerStatus,
                  historyCount: _history.length,
                  onRefresh: _checkConnection,
                ),
                SizedBox(height: spacing),
                _CompactContextCard(
                  contextValue: contextValue,
                  edition: widget.edition,
                  onRemoveLocation: contextValue == null
                      ? null
                      : () => setState(
                          () => _context = contextValue.copyWith(
                            includeLocation: false,
                          ),
                        ),
                  onRemoveBadges: contextValue == null
                      ? null
                      : () => setState(
                          () => _context = contextValue.copyWith(
                            includeBadges: false,
                          ),
                        ),
                ),
                SizedBox(height: spacing),
                AskTitoDexLoadingCard(
                  journey: widget.journey,
                  loading: _loading,
                  progress: _progress,
                  requestSeed: _requestSeed,
                ),
                SizedBox(height: spacing),
                Expanded(
                  child: DecoratedBox(
                    key: const Key('ask-titodex-answer-viewport'),
                    decoration: BoxDecoration(
                      color: TitoColors.card.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(
                        DeviceLayout.rLg(context),
                      ),
                      border: Border.all(
                        color: TitoColors.ink.withValues(alpha: 0.55),
                        width: 1.5,
                      ),
                    ),
                    child: Scrollbar(
                      controller: _answerScrollController,
                      child: ListView(
                        key: const Key('ask-titodex-answer-scroll'),
                        controller: _answerScrollController,
                        padding: const EdgeInsets.all(8),
                        children: [
                          if (_history.isEmpty &&
                              _submittedQuestion == null &&
                              !_loading)
                            const _ConversationEmptyState(),
                          for (final entry in _history) ...[
                            _QuestionBubble(
                              question: entry.question,
                              game: entry.game,
                              showGame: entry.game != contextValue?.game,
                            ),
                            const SizedBox(height: 8),
                            _AnswerCard(
                              question: entry.question,
                              result: entry.result,
                              entityResolver: _entityResolver,
                              onRetry: () => _submit(entry.question),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_submittedQuestion case final question?)
                            _QuestionBubble(question: question),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: spacing),
                _QuestionComposer(
                  controller: _questionController,
                  loading: _loading,
                  enabled: contextValue != null,
                  onSubmit: _submit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({
    required this.status,
    required this.historyCount,
    required this.onRefresh,
  });

  final AskTitoDexWorkerStatus status;
  final int historyCount;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final online = status.availability == AskTitoDexAvailability.online;
    final capabilities = _connectionCapabilities(status);
    final enabledCount = online
        ? capabilities.where((capability) => capability.$2).length
        : 0;
    final capabilityCount = capabilities.length;
    final color = switch (status.availability) {
      AskTitoDexAvailability.checking => TitoColors.skyBlue,
      AskTitoDexAvailability.online => TitoColors.mint,
      AskTitoDexAvailability.disabled => TitoColors.softYellow,
      AskTitoDexAvailability.unavailable => TitoColors.coral,
    };
    final summary = switch (status.availability) {
      AskTitoDexAvailability.checking =>
        '检查中 · -- · 问答 $historyCount/$askTitoDexHistoryLimit',
      AskTitoDexAvailability.online =>
        '在线能力 · $enabledCount/$capabilityCount · 问答 $historyCount/$askTitoDexHistoryLimit',
      AskTitoDexAvailability.disabled =>
        '在线能力已关闭 · 问答 $historyCount/$askTitoDexHistoryLimit',
      AskTitoDexAvailability.unavailable =>
        '当前仅本地 · 问答 $historyCount/$askTitoDexHistoryLimit',
    };

    return StickerCard(
      key: const Key('ask-titodex-connection-status'),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('ask-titodex-connection-summary'),
          borderRadius: BorderRadius.circular(DeviceLayout.rLg(context)),
          onTap: () => _showConnectionDetails(
            context,
            status: status,
            enabledCount: enabledCount,
            capabilityCount: capabilityCount,
            historyCount: historyCount,
            onRefresh: onRefresh,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: TitoColors.ink, width: 1.5),
                  ),
                  child: status.availability == AskTitoDexAvailability.checking
                      ? const Padding(
                          padding: EdgeInsets.all(2),
                          child: CircularProgressIndicator(strokeWidth: 1),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary,
                    style: SecondaryTypography.onCard.body14.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '查看',
                  style: SecondaryTypography.onCard.small12.copyWith(
                    color: TitoColors.mutedInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showConnectionDetails(
  BuildContext context, {
  required AskTitoDexWorkerStatus status,
  required int enabledCount,
  required int capabilityCount,
  required int historyCount,
  required VoidCallback onRefresh,
}) async {
  final workerOnline = status.availability == AskTitoDexAvailability.online;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('ask-titodex-connection-dialog'),
      title: Text(
        '连接状态 · $enabledCount/$capabilityCount\n问答记录 · $historyCount/$askTitoDexHistoryLimit',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final capability in _connectionCapabilities(status))
              _CapabilityDetail(
                label: capability.$1,
                enabled: workerOnline && capability.$2,
              ),
            if (status.experimentalAnswers) ...[
              const SizedBox(height: 6),
              Text(
                '当前为宽范围试用：仍只接受宝可梦主题和固定来源域名，但证据不足时会降为低置信度回答，不再直接丢弃。',
                key: const Key('ask-titodex-experimental-policy'),
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.deepBlue,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              switch (status.availability) {
                AskTitoDexAvailability.online =>
                  AppZh.askTitoDexStatusOnlineHint,
                AskTitoDexAvailability.disabled =>
                  AppZh.askTitoDexStatusDisabledHint,
                AskTitoDexAvailability.unavailable =>
                  AppZh.askTitoDexStatusUnavailableHint,
                AskTitoDexAvailability.checking =>
                  AppZh.askTitoDexWorkerChecking,
              },
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          key: const Key('ask-titodex-refresh-connection'),
          onPressed: status.availability == AskTitoDexAvailability.checking
              ? null
              : () {
                  Navigator.of(dialogContext).pop();
                  onRefresh();
                },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text(AppZh.askTitoDexWorkerRefresh),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

List<(String, bool)> _connectionCapabilities(AskTitoDexWorkerStatus status) => [
  ('Journey Worker', status.availability == AskTitoDexAvailability.online),
  ('Qwen · 回答整理/核对', status.qwenConfigured),
  ('AI Search · R2 索引', status.aiSearchEnabled),
  ('TitoDex Bundle · 结构化校验', status.dexBundleEnabled),
  ('百科资料 · 多个限定来源', status.curatedSourcesEnabled),
  for (final provider in status.webSearchProviders)
    ('联网 · ${_webSearchProviderLabel(provider)}', status.webSearchEnabled),
  if (status.webSearchProviders.isEmpty) ('联网搜索', false),
];

class _CapabilityDetail extends StatelessWidget {
  const _CapabilityDetail({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.remove_circle_outline,
            size: 18,
            color: enabled ? TitoColors.deepBlue : TitoColors.mutedInk,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: SecondaryTypography.onCard.body14),
          ),
          Text(
            enabled ? '可用' : '未连接',
            style: SecondaryTypography.onCard.small12.copyWith(
              color: enabled ? TitoColors.deepBlue : TitoColors.mutedInk,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactContextCard extends StatelessWidget {
  const _CompactContextCard({
    required this.contextValue,
    required this.edition,
    required this.onRemoveLocation,
    required this.onRemoveBadges,
  });

  final AskTitoDexContext? contextValue;
  final GameEdition edition;
  final VoidCallback? onRemoveLocation;
  final VoidCallback? onRemoveBadges;

  @override
  Widget build(BuildContext context) {
    final value = contextValue;
    final showLocation = value != null && value.hasVerifiedLocationContext;
    final showVerifiedBadges =
        value != null &&
        value.hasVerifiedBadgeContext &&
        value.badgesReliability == 'save_verified' &&
        value.badgeIds.isNotEmpty;
    final showBadgeCount =
        value != null &&
        value.hasVerifiedBadgeContext &&
        value.badgesReliability == 'count_only' &&
        value.badgeCount != null;

    return StickerCard(
      key: const Key('ask-titodex-context-card'),
      variant: StickerVariant.softYellow,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      child: value == null
          ? const LinearProgressIndicator(minHeight: 3)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.sports_esports_rounded, size: 20),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '当前游戏版本：${assistantEditionDisplayLabel(edition)}',
                        key: const Key('ask-titodex-current-edition'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SecondaryTypography.onCard.body14.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (showLocation ||
                          showVerifiedBadges ||
                          showBadgeCount) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            if (showLocation)
                              _ContextChip(
                                key: const Key('ask-titodex-location-context'),
                                icon: Icons.place_outlined,
                                label: localizeLocation(value.locationLabel!),
                                onDeleted: onRemoveLocation,
                              ),
                            if (showVerifiedBadges)
                              _ContextChip(
                                key: const Key('ask-titodex-badge-context'),
                                icon: Icons.military_tech,
                                label: AppZh.askTitoDexBadgeContext(
                                  value.badgeIds.length,
                                ),
                                onDeleted: onRemoveBadges,
                              ),
                            if (showBadgeCount)
                              _ContextChip(
                                key: const Key('ask-titodex-badge-context'),
                                icon: Icons.military_tech,
                                label: '存档徽章 ${value.badgeCount} 枚（仅计数）',
                                onDeleted: onRemoveBadges,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({
    super.key,
    required this.icon,
    required this.label,
    this.onDeleted,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: Icon(icon, size: 14),
      label: Text(
        label,
        style: SecondaryTypography.onCard.small12.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      deleteIcon: const Icon(Icons.close_rounded, size: 14),
      onDeleted: onDeleted,
    );
  }
}

class _ConversationEmptyState extends StatelessWidget {
  const _ConversationEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 24,
            color: TitoColors.deepBlue.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 6),
          Text(
            '回答会显示在这里',
            textAlign: TextAlign.center,
            style: SecondaryTypography.onCard.small12.copyWith(
              color: TitoColors.mutedInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionBubble extends StatelessWidget {
  const _QuestionBubble({
    required this.question,
    this.game,
    this.showGame = false,
  });

  final String question;
  final String? game;
  final bool showGame;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: TitoColors.deepBlue,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(color: TitoColors.ink, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (showGame && game != null) ...[
                  Text(
                    _assistantGameLabel(game!),
                    style: SecondaryTypography.onGradient.small12.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  question,
                  key: const Key('ask-titodex-question-bubble'),
                  style: SecondaryTypography.onGradient.body14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionComposer extends StatelessWidget {
  const _QuestionComposer({
    required this.controller,
    required this.loading,
    required this.enabled,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool loading;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      key: const Key('ask-titodex-composer'),
      padding: const EdgeInsets.fromLTRB(8, 7, 7, 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const Key('ask-titodex-question'),
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 3,
              maxLength: 240,
              textInputAction: TextInputAction.send,
              decoration:
                  retroInsetDecoration(
                    hintText: AppZh.askTitoDexQuestionHint,
                  ).copyWith(
                    isDense: true,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 11,
                    ),
                  ),
              onSubmitted: (_) {
                if (!loading) onSubmit();
              },
            ),
          ),
          const SizedBox(width: 7),
          SizedBox.square(
            dimension: 44,
            child: FilledButton(
              key: const Key('ask-titodex-submit'),
              onPressed: loading || !enabled ? null : onSubmit,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
              ),
              child: const Icon(Icons.arrow_upward_rounded, size: 22),
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: enabled
            ? TitoColors.mint.withValues(alpha: 0.55)
            : TitoColors.skyBlue.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TitoColors.ink, width: 1),
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

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.question,
    required this.result,
    required this.entityResolver,
    required this.onRetry,
  });

  final String question;
  final AskTitoDexResult result;
  final AskTitoDexEntityResolver entityResolver;
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
          if ((result.answer ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            _EntityLinkCards(
              question: question,
              answer: result.answer!,
              resolver: entityResolver,
            ),
          ],
        ],
      ),
    );
  }
}

class _EntityLinkCards extends StatefulWidget {
  const _EntityLinkCards({
    required this.question,
    required this.answer,
    required this.resolver,
  });

  final String question;
  final String answer;
  final AskTitoDexEntityResolver resolver;

  @override
  State<_EntityLinkCards> createState() => _EntityLinkCardsState();
}

class _EntityLinkCardsState extends State<_EntityLinkCards> {
  late Future<List<AskTitoDexEntityLink>> _links;

  @override
  void initState() {
    super.initState();
    _links = widget.resolver.resolve(
      question: widget.question,
      answer: widget.answer,
    );
  }

  @override
  void didUpdateWidget(covariant _EntityLinkCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question != widget.question ||
        oldWidget.answer != widget.answer ||
        oldWidget.resolver != widget.resolver) {
      _links = widget.resolver.resolve(
        question: widget.question,
        answer: widget.answer,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AskTitoDexEntityLink>>(
      future: _links,
      builder: (context, snapshot) {
        final links = snapshot.data ?? const <AskTitoDexEntityLink>[];
        if (links.isEmpty) return const SizedBox.shrink();
        return Column(
          key: const Key('ask-titodex-entity-links'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '在 TitoDex 里继续查看',
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final link in links)
                  ActionChip(
                    key: ValueKey('ask-entity-${link.kind.name}-${link.id}'),
                    avatar: Icon(_entityIcon(link.kind), size: 17),
                    label: Text(
                      '${link.nameZh} · ${_entityKindLabel(link.kind)}',
                    ),
                    onPressed: () => context.push(link.route),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

IconData _entityIcon(AskTitoDexEntityKind kind) => switch (kind) {
  AskTitoDexEntityKind.pokemon => Icons.catching_pokemon_rounded,
  AskTitoDexEntityKind.item => Icons.backpack_rounded,
  AskTitoDexEntityKind.move => Icons.auto_awesome_rounded,
  AskTitoDexEntityKind.ability => Icons.bolt_rounded,
};

String _entityKindLabel(AskTitoDexEntityKind kind) => switch (kind) {
  AskTitoDexEntityKind.pokemon => '图鉴',
  AskTitoDexEntityKind.item => '道具',
  AskTitoDexEntityKind.move => '招式',
  AskTitoDexEntityKind.ability => '特性',
};

String _assistantGameLabel(String value) => switch (value) {
  'diamond' => '钻石 · DP',
  'pearl' => '珍珠 · DP',
  'platinum' => '白金 · Pt',
  'heartgold' => '心金 · HGSS',
  'soulsilver' => '魂银 · HGSS',
  'black' => '黑 · BW',
  'white' => '白 · BW',
  'black-2' => '黑2 · B2W2',
  'white-2' => '白2 · B2W2',
  'x' => 'X · XY',
  'y' => 'Y · XY',
  'omega-ruby' => '欧米伽红宝石 · ORAS',
  'alpha-sapphire' => '阿尔法蓝宝石 · ORAS',
  'sun' => '太阳 · SM',
  'moon' => '月亮 · SM',
  'ultra-sun' => '究极之日 · USUM',
  'ultra-moon' => '究极之月 · USUM',
  'sword' => '剑 · SWSH',
  'shield' => '盾 · SWSH',
  'brilliant-diamond' => '晶灿钻石 · BDSP',
  'shining-pearl' => '明亮珍珠 · BDSP',
  'legends-arceus' => '传说 阿尔宙斯 · PLA',
  'scarlet' => '朱 · SV',
  'violet' => '紫 · SV',
  _ => value,
};

String _answerModeLabel(AskTitoDexAnswerMode mode) => switch (mode) {
  AskTitoDexAnswerMode.localAudited => AppZh.askTitoDexRouteLocal,
  AskTitoDexAnswerMode.auditedOnline => AppZh.askTitoDexRouteAuditedOnline,
  AskTitoDexAnswerMode.aiSearchAudited => AppZh.askTitoDexRouteAiSearch,
  AskTitoDexAnswerMode.curatedSourcesDeterministic =>
    AppZh.askTitoDexRouteCuratedDeterministic,
  AskTitoDexAnswerMode.curatedSourcesQwen => AppZh.askTitoDexRouteCuratedQwen,
  AskTitoDexAnswerMode.deepseekNativeSearch => 'DeepSeek 原生联网回答',
  AskTitoDexAnswerMode.multiSourceQwen => 'Qwen × DeepSeek 交叉核对',
  AskTitoDexAnswerMode.noMatch => AppZh.askTitoDexOnlineSearchedNoMatch,
};

String _sourceKindLabel(String value) => switch (value) {
  'pokeapi' => 'PokeAPI',
  'strategywiki' => 'StrategyWiki',
  'wikidata' => 'Wikidata',
  'tavily' => 'Tavily',
  'deepseek-native' => 'DeepSeek 联网',
  'brave' => 'Brave Search',
  _ => value,
};

String _webSearchProviderLabel(String value) => switch (value) {
  'tavily' => 'Tavily',
  'deepseek-native' => 'DeepSeek 原生',
  'brave' => 'Brave',
  _ => value,
};
