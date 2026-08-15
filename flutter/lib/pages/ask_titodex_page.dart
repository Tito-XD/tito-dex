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
  });

  final CurrentJourney journey;
  final GameEdition edition;
  final AskTitoDexService? service;

  @override
  State<AskTitoDexPage> createState() => _AskTitoDexPageState();
}

class _AskTitoDexPageState extends State<AskTitoDexPage> {
  late final TextEditingController _questionController;
  late final ScrollController _answerScrollController;
  late final AskTitoDexService _service;
  AskTitoDexContext? _context;
  AskTitoDexResult? _result;
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
      _submittedQuestion = question;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _answerScrollController.hasClients) {
        _answerScrollController.animateTo(
          _answerScrollController.position.maxScrollExtent,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
    if (result.errorCode?.contains('_fallback') == true) {
      unawaited(_checkConnection());
    }
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
                          if (_submittedQuestion == null && !_loading)
                            const _ConversationEmptyState(),
                          if (_submittedQuestion case final question?)
                            _QuestionBubble(question: question),
                          if (_result case final result?) ...[
                            const SizedBox(height: 8),
                            _AnswerCard(result: result, onRetry: _submit),
                          ],
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
  const _ConnectionStatusCard({required this.status, required this.onRefresh});

  final AskTitoDexWorkerStatus status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final online = status.availability == AskTitoDexAvailability.online;
    final enabledCount = online
        ? 1 +
              (status.qwenConfigured ? 1 : 0) +
              (status.aiSearchEnabled ? 1 : 0) +
              (status.webSearchEnabled ? 1 : 0)
        : 0;
    final color = switch (status.availability) {
      AskTitoDexAvailability.checking => TitoColors.skyBlue,
      AskTitoDexAvailability.online => TitoColors.mint,
      AskTitoDexAvailability.disabled => TitoColors.softYellow,
      AskTitoDexAvailability.unavailable => TitoColors.coral,
    };
    final summary = switch (status.availability) {
      AskTitoDexAvailability.checking => '检查中 · --/4',
      AskTitoDexAvailability.online => '在线能力 · $enabledCount/4',
      AskTitoDexAvailability.disabled => '在线能力已关闭 · 0/4',
      AskTitoDexAvailability.unavailable => '当前仅本地 · 0/4',
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
  required VoidCallback onRefresh,
}) async {
  final workerOnline = status.availability == AskTitoDexAvailability.online;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('ask-titodex-connection-dialog'),
      title: Text('连接状态 · $enabledCount/4'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CapabilityDetail(label: 'Journey Worker', enabled: workerOnline),
          _CapabilityDetail(
            label: 'Qwen',
            enabled: workerOnline && status.qwenConfigured,
          ),
          _CapabilityDetail(
            label: 'AI Search',
            enabled: workerOnline && status.aiSearchEnabled,
          ),
          _CapabilityDetail(
            label: status.webSearchProviders.isEmpty
                ? '联网搜索'
                : '联网搜索（${status.webSearchProviders.map(_webSearchProviderLabel).join(' / ')}）',
            enabled: workerOnline && status.webSearchEnabled,
          ),
          const SizedBox(height: 8),
          Text(
            switch (status.availability) {
              AskTitoDexAvailability.online => AppZh.askTitoDexStatusOnlineHint,
              AskTitoDexAvailability.disabled =>
                AppZh.askTitoDexStatusDisabledHint,
              AskTitoDexAvailability.unavailable =>
                AppZh.askTitoDexStatusUnavailableHint,
              AskTitoDexAvailability.checking => AppZh.askTitoDexWorkerChecking,
            },
            style: SecondaryTypography.onCard.small12.copyWith(
              color: TitoColors.mutedInk,
              height: 1.35,
            ),
          ),
        ],
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
  const _QuestionBubble({required this.question});

  final String question;

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
            child: Text(
              question,
              key: const Key('ask-titodex-question-bubble'),
              style: SecondaryTypography.onGradient.body14,
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
  AskTitoDexAnswerMode.deepseekNativeSearch => 'DeepSeek 原生联网回答',
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
