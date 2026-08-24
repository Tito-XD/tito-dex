import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/companion/companion_repository.dart';
import '../features/game/game_catalog.dart';
import '../features/game/game_edition.dart';
import '../features/game/game_edition_repository.dart';
import '../features/journey/ask_titodex_answer_blocks.dart';
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
import '../widgets/assistant_surface.dart';
import '../widgets/ask_titodex_loading.dart';
import '../widgets/retro_forms.dart';
import '../widgets/secondary_page_scaffold.dart';

typedef AskTitoDexSourceOpener = Future<bool> Function(Uri uri);

const _assistantPaper = Color(0xFFFFFBF2);
const _assistantCanvas = Color(0xFFF5F6F3);
const _assistantSkeleton = Color(0xFFDCE5E5);
const _semanticRevealDelay = Duration(milliseconds: 36);
const _semanticRevealStepLimit = 40;
const _askTitoDexQuestionLimit = 240;

String buildAskTitoDexClarificationQuestion({
  required String originalQuestion,
  required String candidateLabel,
}) {
  final original = originalQuestion.trim();
  final label = candidateLabel.trim();
  final prefix = '已确认对象是“$label”。原问题：';
  final available = _askTitoDexQuestionLimit - prefix.length;
  if (available <= 0) {
    return _takeLeadingCodeUnits(prefix, _askTitoDexQuestionLimit);
  }
  return '$prefix${_ellipsizeMiddle(original, available)}';
}

String _ellipsizeMiddle(String value, int maxLength) {
  if (maxLength <= 0) return '';
  if (value.length <= maxLength) return value;
  if (maxLength == 1) return '…';
  final contentLength = maxLength - 1;
  final leadingLength = contentLength ~/ 3;
  final trailingLength = contentLength - leadingLength;
  return '${_takeLeadingCodeUnits(value, leadingLength)}…'
      '${_takeTrailingCodeUnits(value, trailingLength)}';
}

String _takeLeadingCodeUnits(String value, int maxLength) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    if (buffer.length + character.length > maxLength) break;
    buffer.write(character);
  }
  return buffer.toString();
}

String _takeTrailingCodeUnits(String value, int maxLength) {
  final runes = value.runes.toList(growable: false);
  final selected = <int>[];
  var length = 0;
  for (var index = runes.length - 1; index >= 0; index -= 1) {
    final character = String.fromCharCode(runes[index]);
    if (length + character.length > maxLength) break;
    selected.add(runes[index]);
    length += character.length;
  }
  return String.fromCharCodes(selected.reversed);
}

Future<bool> _openExternalSource(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class AskTitoDexPage extends StatefulWidget {
  const AskTitoDexPage({
    super.key,
    required this.journey,
    required this.edition,
    this.service,
    this.historyStore,
    this.entityResolver,
    this.sourceOpener,
  });

  final CurrentJourney journey;
  final GameEdition edition;
  final AskTitoDexService? service;
  final AskTitoDexHistoryStore? historyStore;
  final AskTitoDexEntityResolver? entityResolver;
  final AskTitoDexSourceOpener? sourceOpener;

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
  late GameEdition _edition;
  AskTitoDexContext? _context;
  List<AskTitoDexHistoryEntry> _history = const [];
  AskTitoDexWorkerStatus _workerStatus =
      const AskTitoDexWorkerStatus.checking();
  AskTitoDexProgress _progress = AskTitoDexProgress.checkingLocal;
  var _requestSeed = 0;
  var _contextRequestId = 0;
  int? _revealEntryId;
  int? _activeEntryId;
  String? _submittedQuestion;
  bool _loading = false;
  List<AskTitoDexAnswerBlock> _streamedBlocks = const [];
  AskTitoDexClarification? _streamedClarification;
  AskTitoDexResult? _activeResult;
  var _semanticRevealSteps = 0;
  var _followingLatest = true;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController();
    _answerScrollController = ScrollController();
    _service = widget.service ?? askTitoDexService;
    _historyStore = widget.historyStore ?? askTitoDexHistoryStore;
    _entityResolver = widget.entityResolver ?? askTitoDexEntityResolver;
    _edition = widget.edition;
    _historyReady = _loadHistory();
    askTitoDexSettings.addListener(_handleSettingsChanged);
    unawaited(companionRepository.load());
    _prepareContext();
    _checkConnection();
  }

  void _handleSettingsChanged() => _checkConnection();

  @override
  void didUpdateWidget(covariant AskTitoDexPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.edition.slug != widget.edition.slug ||
        oldWidget.edition.selectedFlavor != widget.edition.selectedFlavor) {
      _requestSeed += 1;
      _edition = widget.edition;
      _context = null;
      _loading = false;
      _submittedQuestion = null;
      _streamedBlocks = const [];
      _streamedClarification = null;
      _activeEntryId = null;
      _activeResult = null;
      unawaited(_prepareContext());
    }
  }

  Future<void> _loadHistory() async {
    final loaded = await _historyStore.load();
    if (!mounted) return;
    setState(() => _history = loaded);
    _scrollToLatest(animate: false, force: true);
  }

  Future<void> _checkConnection() async {
    if (mounted) {
      setState(() => _workerStatus = const AskTitoDexWorkerStatus.checking());
    }
    final status = await _service.checkConnection();
    if (mounted) setState(() => _workerStatus = status);
  }

  Future<void> _prepareContext() async {
    final requestId = ++_contextRequestId;
    final edition = _edition;
    final initial = AskTitoDexContext.fromJourney(widget.journey, edition);
    final resolved = await _service.buildContext(initial);
    if (mounted && requestId == _contextRequestId) {
      setState(() => _context = resolved);
    }
  }

  Future<void> _pickEdition() async {
    if (_loading) return;
    final picked = await showGameEditionGridPicker(context, selected: _edition);
    if (!mounted || picked == null || _loading) return;
    if (picked.slug == _edition.slug &&
        picked.selectedFlavor == _edition.selectedFlavor) {
      return;
    }
    await gameEditionRepository.save(picked);
    if (!mounted || _loading) return;
    setState(() {
      _requestSeed += 1;
      _edition = picked;
      _context = null;
      _submittedQuestion = null;
      _streamedBlocks = const [];
      _streamedClarification = null;
      _activeEntryId = null;
      _activeResult = null;
    });
    await _prepareContext();
  }

  Future<void> _showHistoryManager() async {
    final action = await showModalBottomSheet<_HistoryManagerAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _HistoryManagerSheet(entries: _history),
    );
    if (!mounted || action == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          action == _HistoryManagerAction.clear ? '清除全部问答？' : '压缩问答记录？',
        ),
        content: Text(
          action == _HistoryManagerAction.clear
              ? '这会删除当前设备上的全部问答记录，无法撤销。'
              : '将只保留最近 10 条问答，较早记录会从当前设备删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              action == _HistoryManagerAction.clear ? '确认清除' : '确认压缩',
            ),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    if (action == _HistoryManagerAction.clear) {
      await _historyStore.clear();
      if (mounted) setState(() => _history = const []);
      return;
    }
    final compacted = await _historyStore.compact();
    if (mounted) setState(() => _history = compacted);
  }

  Future<void> _submit([String? retryQuestion]) async {
    await _historyReady;
    if (!mounted) return;
    final contextValue = _context;
    final question = (retryQuestion ?? _questionController.text).trim();
    if (contextValue == null || question.isEmpty || _loading) return;
    final requestId = _requestSeed + 1;
    final editionToken = _editionToken(_edition);
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _submittedQuestion = question;
      _progress = AskTitoDexProgress.checkingLocal;
      _requestSeed = requestId;
      _streamedBlocks = const [];
      _streamedClarification = null;
      _semanticRevealSteps = 0;
      _activeResult = null;
      _activeEntryId = null;
      _followingLatest = true;
    });
    // The pending answer skeleton is inserted in the same frame. Jumping after
    // that layout guarantees the new question and its full placeholder stay
    // visible instead of animating toward the pre-skeleton scroll extent.
    _scrollToLatest(animate: false, force: true);
    final result = await _service.ask(
      question,
      contextValue,
      history: askTitoDexRequestHistory(
        _history,
        game: contextValue.game ?? '',
      ),
      onProgress: (progress) {
        if (_isActiveRequest(requestId, editionToken)) {
          setState(() => _progress = progress);
        }
      },
      onStreamEvent: (event) async {
        if (!_isActiveRequest(requestId, editionToken)) return;
        if (event.semanticReset) {
          setState(() {
            _streamedBlocks = const [];
            _streamedClarification = null;
            _semanticRevealSteps = 0;
          });
          _scrollToLatest(animate: false);
          return;
        }
        if (event.answerBlock case final block?) {
          final blocks = [..._streamedBlocks];
          final index = blocks.indexWhere((value) => value.id == block.id);
          final previousLength = index < 0 ? 0 : blocks[index].text.length;
          final textGrew = block.text.length > previousLength;
          if (index < 0) {
            blocks.add(block);
          } else {
            blocks[index] = block;
          }
          setState(() => _streamedBlocks = List.unmodifiable(blocks));
          _scrollToLatest(animate: false);
          final reduceMotion = MediaQuery.disableAnimationsOf(context);
          if (textGrew &&
              !reduceMotion &&
              _semanticRevealSteps < _semanticRevealStepLimit) {
            _semanticRevealSteps += 1;
            await Future<void>.delayed(_semanticRevealDelay);
          }
        }
        if (event.clarification case final clarification?) {
          setState(() => _streamedClarification = clarification);
        }
      },
    );
    if (!_isActiveRequest(requestId, editionToken)) return;
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
    if (!_isActiveRequest(requestId, editionToken)) return;
    setState(() {
      _loading = false;
      _history = saved;
      _revealEntryId = entry.createdAt.microsecondsSinceEpoch;
      _activeEntryId = entry.createdAt.microsecondsSinceEpoch;
      _activeResult = result;
      if (retryQuestion == null && result.status == AskTitoDexStatus.answered) {
        _questionController.clear();
      }
    });
    _scrollToLatest();
    if (result.errorCode?.contains('_fallback') == true) {
      unawaited(_checkConnection());
    }
  }

  void _submitClarification(
    String originalQuestion,
    AskTitoDexClarificationCandidate candidate,
  ) {
    if (_loading) return;
    final label = candidate.label.trim();
    if (label.isEmpty) return;
    final clarifiedQuestion = buildAskTitoDexClarificationQuestion(
      originalQuestion: originalQuestion,
      candidateLabel: label,
    );
    unawaited(_submit(clarifiedQuestion));
  }

  bool _isActiveRequest(int requestId, String editionToken) =>
      mounted &&
      requestId == _requestSeed &&
      editionToken == _editionToken(_edition);

  static String _editionToken(GameEdition edition) =>
      '${edition.slug}\u0000${edition.selectedFlavor ?? ''}';

  bool _handleAnswerScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      _followingLatest = notification.metrics.extentAfter <= 72;
    } else if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      _followingLatest = notification.metrics.extentAfter <= 72;
    }
    return false;
  }

  void _scrollToLatest({bool animate = true, bool force = false}) {
    if (!force && !_followingLatest) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_answerScrollController.hasClients ||
          (!force && !_followingLatest)) {
        return;
      }
      final duration = !animate || MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220);
      if (duration == Duration.zero) {
        _answerScrollController.jumpTo(
          _answerScrollController.position.maxScrollExtent,
        );
        // A lazy ListView may only discover the pending skeleton's full height
        // after the first jump lays it out. Correct once on the next frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              !_answerScrollController.hasClients ||
              (!force && !_followingLatest)) {
            return;
          }
          _answerScrollController.jumpTo(
            _answerScrollController.position.maxScrollExtent,
          );
        });
        return;
      }
      unawaited(
        _answerScrollController
            .animateTo(
              _answerScrollController.position.maxScrollExtent,
              duration: duration,
              curve: Curves.easeOut,
            )
            .then((_) {
              if (!mounted ||
                  !_answerScrollController.hasClients ||
                  (!force && !_followingLatest)) {
                return;
              }
              final position = _answerScrollController.position;
              if ((position.maxScrollExtent - position.pixels).abs() > 0.5) {
                position.jumpTo(position.maxScrollExtent);
              }
            }),
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
                  contextValue: contextValue,
                  edition: _edition,
                  onRefresh: _checkConnection,
                  onShowHistory: _showHistoryManager,
                  onChangeEdition: _loading ? null : _pickEdition,
                  onManagePacks: askTitoDexSettings.extensionEnabled
                      ? () => context.push('/journey/packs')
                      : null,
                  onRemoveLocation: _loading || contextValue == null
                      ? null
                      : () => setState(
                          () => _context = contextValue.copyWith(
                            includeLocation: false,
                          ),
                        ),
                  onRemoveBadges: _loading || contextValue == null
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
                  child: Container(
                    key: const Key('ask-titodex-answer-viewport'),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: _assistantCanvas.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: TitoColors.deepBlue.withValues(alpha: 0.12),
                      ),
                    ),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _handleAnswerScrollNotification,
                      child: Scrollbar(
                        controller: _answerScrollController,
                        child: ListView(
                          key: const Key('ask-titodex-answer-scroll'),
                          controller: _answerScrollController,
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                          children: [
                            if (_history.isEmpty &&
                                _submittedQuestion == null &&
                                !_loading)
                              const _ConversationEmptyState(),
                            for (final entry in _history)
                              if (entry.createdAt.microsecondsSinceEpoch !=
                                  _activeEntryId) ...[
                                _QuestionBubble(
                                  question: entry.question,
                                  game: entry.game,
                                  showGame: entry.game != contextValue?.game,
                                ),
                                const SizedBox(height: 8),
                                _AnswerReveal(
                                  key: ValueKey(
                                    'ask-answer-${entry.createdAt.microsecondsSinceEpoch}',
                                  ),
                                  animate:
                                      entry.createdAt.microsecondsSinceEpoch ==
                                      _revealEntryId,
                                  onComplete:
                                      entry.createdAt.microsecondsSinceEpoch ==
                                          _revealEntryId
                                      ? _scrollToLatest
                                      : null,
                                  child: _AnswerCard(
                                    question: entry.question,
                                    result: entry.result,
                                    entityResolver: _entityResolver,
                                    sourceOpener:
                                        widget.sourceOpener ??
                                        _openExternalSource,
                                    animateEvidence:
                                        entry
                                            .createdAt
                                            .microsecondsSinceEpoch ==
                                        _revealEntryId,
                                    onRetry: () => _submit(entry.question),
                                    onClarificationSelected: (candidate) =>
                                        _submitClarification(
                                          entry.question,
                                          candidate,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            if (_submittedQuestion case final question?) ...[
                              _QuestionBubble(question: question),
                              const SizedBox(height: 8),
                              _LiveAnswerCard(
                                key: ValueKey('ask-live-turn-$_requestSeed'),
                                question: question,
                                progress: _progress,
                                streamedBlocks: _streamedBlocks,
                                clarification: _streamedClarification,
                                result: _activeResult,
                                entityResolver: _entityResolver,
                                sourceOpener:
                                    widget.sourceOpener ?? _openExternalSource,
                                onRetry: () => _submit(question),
                                onClarificationSelected: (candidate) =>
                                    _submitClarification(question, candidate),
                                onContentSettled: _scrollToLatest,
                              ),
                            ],
                          ],
                        ),
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
    required this.contextValue,
    required this.edition,
    required this.onRefresh,
    required this.onShowHistory,
    required this.onChangeEdition,
    this.onManagePacks,
    required this.onRemoveLocation,
    required this.onRemoveBadges,
  });

  final AskTitoDexWorkerStatus status;
  final int historyCount;
  final AskTitoDexContext? contextValue;
  final GameEdition edition;
  final VoidCallback onRefresh;
  final VoidCallback onShowHistory;
  final VoidCallback? onChangeEdition;
  final VoidCallback? onManagePacks;
  final VoidCallback? onRemoveLocation;
  final VoidCallback? onRemoveBadges;

  @override
  Widget build(BuildContext context) {
    final online = status.availability == AskTitoDexAvailability.online;
    final capabilities = _connectionCapabilities(status);
    final enabledCount = online
        ? capabilities.where((capability) => capability.$2).length
        : 0;
    final capabilityCount = capabilities.length;
    final editionLabel = assistantEditionDisplayLabel(edition);
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
    final showSaveContext =
        showLocation || showVerifiedBadges || showBadgeCount;
    final statusColor = switch (status.availability) {
      AskTitoDexAvailability.checking => TitoColors.skyBlue,
      AskTitoDexAvailability.online => TitoColors.mint,
      AskTitoDexAvailability.disabled => TitoColors.softYellow,
      AskTitoDexAvailability.unavailable => TitoColors.coral,
    };
    final statusLabel = switch (status.availability) {
      AskTitoDexAvailability.checking => '检查 --',
      AskTitoDexAvailability.online => '在线 $enabledCount/$capabilityCount',
      AskTitoDexAvailability.disabled => '已关闭',
      AskTitoDexAvailability.unavailable => '仅本地',
    };
    final radius = showSaveContext ? DeviceLayout.rLg(context) : 999.0;

    return AssistantSurface(
      key: const Key('ask-titodex-connection-status'),
      padding: EdgeInsets.zero,
      radius: radius,
      color: Color.alphaBlend(
        TitoColors.skyBlue.withValues(alpha: 0.18),
        TitoColors.card,
      ),
      borderColor: TitoColors.deepBlue.withValues(alpha: 0.55),
      borderWidth: 1.5,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _StatusSegment(
                      key: const Key('ask-titodex-connection-summary'),
                      leading: _StatusDot(
                        color: statusColor,
                        checking:
                            status.availability ==
                            AskTitoDexAvailability.checking,
                      ),
                      label: statusLabel,
                      semanticsLabel: '连接状态：$statusLabel',
                      onTap: () => _showConnectionDetails(
                        context,
                        status: status,
                        enabledCount: enabledCount,
                        capabilityCount: capabilityCount,
                        historyCount: historyCount,
                        onRefresh: onRefresh,
                      ),
                    ),
                  ),
                  const _StatusDivider(),
                  Expanded(
                    flex: 4,
                    child: _StatusSegment(
                      key: const Key('ask-titodex-history-summary'),
                      leading: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: TitoColors.deepBlue,
                        size: 18,
                      ),
                      label: '问答 $historyCount/$askTitoDexHistoryLimit',
                      semanticsLabel:
                          '问答记录 $historyCount/$askTitoDexHistoryLimit，点击管理',
                      onTap: onShowHistory,
                    ),
                  ),
                  const _StatusDivider(),
                  Expanded(
                    flex: 5,
                    child: _StatusSegment(
                      key: const Key('ask-titodex-edition-summary'),
                      leading: const Icon(
                        Icons.shield_outlined,
                        color: TitoColors.deepBlue,
                        size: 19,
                      ),
                      label: editionLabel,
                      textKey: const Key('ask-titodex-current-edition'),
                      semanticsLabel: '当前游戏版本 $editionLabel，点击切换',
                      onTap: onChangeEdition,
                      trailing: onManagePacks == null
                          ? null
                          : IconButton(
                              key: const Key('ask-titodex-packs-entry'),
                              tooltip: '管理 Journey 资料包',
                              onPressed: onManagePacks,
                              constraints: const BoxConstraints.tightFor(
                                width: 28,
                                height: 32,
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.download_for_offline_outlined,
                                color: TitoColors.deepBlue,
                                size: 18,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            if (showSaveContext) ...[
              Divider(
                height: 1,
                thickness: 1,
                indent: 11,
                endIndent: 11,
                color: TitoColors.deepBlue.withValues(alpha: 0.12),
              ),
              Padding(
                key: const Key('ask-titodex-save-context'),
                padding: const EdgeInsets.fromLTRB(11, 6, 11, 7),
                child: Wrap(
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusSegment extends StatelessWidget {
  const _StatusSegment({
    super.key,
    required this.leading,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
    this.textKey,
    this.trailing,
  });

  final Widget leading;
  final String label;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final Key? textKey;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: semanticsLabel,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    key: textKey,
                    maxLines: 1,
                    style: SecondaryTypography.onCard.body14.copyWith(
                      color: TitoColors.deepBlue,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
              if (trailing case final trailing?) trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDivider extends StatelessWidget {
  const _StatusDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 24,
    color: TitoColors.deepBlue.withValues(alpha: 0.16),
  );
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.checking});

  final Color color;
  final bool checking;

  @override
  Widget build(BuildContext context) => Container(
    width: 13,
    height: 13,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: TitoColors.deepBlue, width: 1.25),
    ),
    child: checking
        ? const Padding(
            padding: EdgeInsets.all(2),
            child: CircularProgressIndicator(strokeWidth: 1),
          )
        : null,
  );
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

enum _HistoryManagerAction { compact, clear }

class _HistoryManagerSheet extends StatelessWidget {
  const _HistoryManagerSheet({required this.entries});

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
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Row(
                children: [
                  const Icon(Icons.forum_outlined, color: TitoColors.deepBlue),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '问答记录 · ${entries.length}/$askTitoDexHistoryLimit',
                      style: SecondaryTypography.onCard.h15.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                '记录只保存在当前设备；连续追问只会带入当前游戏最近 $askTitoDexContextEntryLimit 条。',
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
                        '还没有问答记录',
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
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: TitoColors.cardWarm,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: TitoColors.deepBlue.withValues(alpha: 0.2),
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
                              _HistoryManagerAction.compact,
                            )
                          : null,
                      icon: const Icon(Icons.compress_rounded),
                      label: const Text('压缩到 10 条'),
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
                              _HistoryManagerAction.clear,
                            ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('清除全部'),
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
      backgroundColor: TitoColors.cardWarm,
      side: BorderSide(color: TitoColors.ink.withValues(alpha: 0.55), width: 1),
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
            color: TitoColors.skyBlue.withValues(alpha: 0.82),
          ),
          const SizedBox(height: 6),
          Text(
            '回答会显示在这里',
            textAlign: TextAlign.center,
            style: SecondaryTypography.onCard.small12.copyWith(
              color: TitoColors.deepBlue.withValues(alpha: 0.72),
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
            color: TitoColors.softYellow,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(
              color: TitoColors.ink.withValues(alpha: 0.3),
              width: 1.25,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F18283B),
                offset: Offset(0, 4),
                blurRadius: 9,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (showGame && game != null) ...[
                  Text(
                    _assistantGameLabel(game!),
                    style: SecondaryTypography.onCard.small12.copyWith(
                      color: TitoColors.deepBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  question,
                  key: const Key('ask-titodex-question-bubble'),
                  style: SecondaryTypography.onCard.body14.copyWith(
                    color: TitoColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
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
    return AssistantSurface(
      key: const Key('ask-titodex-composer'),
      padding: const EdgeInsets.fromLTRB(8, 7, 7, 7),
      radius: DeviceLayout.rLg(context),
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

class _LiveAnswerCard extends StatelessWidget {
  const _LiveAnswerCard({
    super.key,
    required this.question,
    required this.progress,
    required this.streamedBlocks,
    required this.clarification,
    required this.result,
    required this.entityResolver,
    required this.sourceOpener,
    required this.onRetry,
    required this.onClarificationSelected,
    required this.onContentSettled,
  });

  final String question;
  final AskTitoDexProgress progress;
  final List<AskTitoDexAnswerBlock> streamedBlocks;
  final AskTitoDexClarification? clarification;
  final AskTitoDexResult? result;
  final AskTitoDexEntityResolver entityResolver;
  final AskTitoDexSourceOpener sourceOpener;
  final VoidCallback onRetry;
  final ValueChanged<AskTitoDexClarificationCandidate> onClarificationSelected;
  final VoidCallback onContentSettled;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final stage = switch (progress) {
      AskTitoDexProgress.checkingLocal => '正在翻本地资料',
      AskTitoDexProgress.contactingWorker => '正在交叉核对资料与联网来源',
      AskTitoDexProgress.retrievingSources => '正在从资料库和联网来源找线索',
      AskTitoDexProgress.resolvingQuestion => '正在确认版本与问题里的对象',
      AskTitoDexProgress.verifyingAnswer => '正在交叉核对资料与联网来源',
      AskTitoDexProgress.revealingAnswer => '正在写入已核验回答',
    };
    final hasSemanticAnswer = streamedBlocks.isNotEmpty;
    final streamedSemanticBody = streamedBlocks
        .map((block) {
          final title = block.title?.trim() ?? '';
          final text = block.text.trim();
          final projectedText = text.isNotEmpty
              ? text
              : block.items.isNotEmpty
              ? block.items.join('，')
              : block.rows.map((row) => row.join('，')).join('；');
          return [
            if (title.isNotEmpty) title,
            if (projectedText.isNotEmpty) projectedText,
          ].join('，');
        })
        .where((value) => value.isNotEmpty)
        .join('；');
    final liveAnswerBody = streamedSemanticBody;
    final completed = result;
    return Semantics(
      key: const Key('ask-titodex-live-answer-semantics'),
      liveRegion: completed == null,
      label: completed == null
          ? liveAnswerBody.isNotEmpty
                ? '$stage，$liveAnswerBody'
                : stage
          : '回答完成',
      child: AssistantSurface(
        key: const Key('ask-titodex-active-answer-surface'),
        color: _assistantPaper,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        radius: 18,
        borderColor: TitoColors.deepBlue.withValues(alpha: 0.24),
        child: _MotionAwareAnimatedSize(
          onEnd: onContentSettled,
          child: completed == null
              ? Column(
                  key: const Key('ask-titodex-generating-answer'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 220),
                            child: Text(
                              stage,
                              key: ValueKey(stage),
                              style: SecondaryTypography.onCard.small12
                                  .copyWith(
                                    color: TitoColors.deepBlue,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                        ),
                        const AssistantSparkle(size: 15),
                        const SizedBox(width: 5),
                        const AssistantSparkle(
                          size: 8,
                          color: TitoColors.softYellow,
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.topLeft,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      ),
                      child: hasSemanticAnswer
                          ? _AnswerBlocksView(
                              key: const Key('ask-titodex-streaming-answer'),
                              blocks: streamedBlocks,
                              animateBlocks: true,
                            )
                          : clarification != null
                          ? _StreamingClarification(
                              clarification: clarification!,
                              onSelected: onClarificationSelected,
                            )
                          : Shimmer.fromColors(
                              key: const ValueKey('answer-skeleton'),
                              enabled: !reduceMotion,
                              baseColor: _assistantSkeleton,
                              highlightColor: _assistantPaper,
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _AnswerSkeletonLine(fraction: 1),
                                  SizedBox(height: 7),
                                  _AnswerSkeletonLine(fraction: 0.84),
                                  SizedBox(height: 7),
                                  _AnswerSkeletonLine(fraction: 0.58),
                                  SizedBox(height: 12),
                                  _AnswerSkeletonEvidence(),
                                ],
                              ),
                            ),
                    ),
                  ],
                )
              : KeyedSubtree(
                  key: const Key('ask-titodex-answer-card'),
                  child: _AnswerCardContent(
                    question: question,
                    result: completed,
                    entityResolver: entityResolver,
                    sourceOpener: sourceOpener,
                    animateEvidence: true,
                    onRetry: onRetry,
                    onClarificationSelected: onClarificationSelected,
                    onContentSettled: onContentSettled,
                  ),
                ),
        ),
      ),
    );
  }
}

class _MotionAwareAnimatedSize extends StatelessWidget {
  const _MotionAwareAnimatedSize({required this.child, this.onEnd});

  final Widget child;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      onEnd: onEnd,
      child: child,
    );
  }
}

class _BlinkingMarkdown extends StatefulWidget {
  const _BlinkingMarkdown({required this.data});

  final String data;

  @override
  State<_BlinkingMarkdown> createState() => _BlinkingMarkdownState();
}

class _BlinkingMarkdownState extends State<_BlinkingMarkdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursor;

  @override
  void initState() {
    super.initState();
    _cursor = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 940),
      value: 1,
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _cursor.stop();
      _cursor.value = 1;
    } else if (!_cursor.isAnimating) {
      _cursor.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _cursor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      return _AssistantMarkdown(data: '${widget.data}▍');
    }
    return AnimatedBuilder(
      animation: _cursor,
      builder: (context, _) => _AssistantMarkdown(
        data: _cursor.value >= 0.38
            ? '${widget.data}▍'
            : '${widget.data}\u2009',
      ),
    );
  }
}

class _StreamingClarification extends StatelessWidget {
  const _StreamingClarification({
    required this.clarification,
    required this.onSelected,
  });

  final AskTitoDexClarification clarification;
  final ValueChanged<AskTitoDexClarificationCandidate> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('ask-titodex-streaming-clarification'),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: TitoColors.softYellow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: TitoColors.softYellow.withValues(alpha: 0.56),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BlinkingMarkdown(data: clarification.prompt),
          if (clarification.candidates.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ClarificationCandidateChips(
              candidates: clarification.candidates,
              onSelected: onSelected,
            ),
          ],
        ],
      ),
    );
  }
}

class _ClarificationCandidateChips extends StatelessWidget {
  const _ClarificationCandidateChips({
    required this.candidates,
    required this.onSelected,
  });

  final List<AskTitoDexClarificationCandidate> candidates;
  final ValueChanged<AskTitoDexClarificationCandidate> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('ask-titodex-clarification-candidates'),
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final candidate in candidates)
          ActionChip(
            key: ValueKey('ask-clarification-${candidate.id}'),
            visualDensity: VisualDensity.compact,
            avatar: const Icon(Icons.touch_app_rounded, size: 15),
            label: Text(candidate.label),
            onPressed: () => onSelected(candidate),
          ),
      ],
    );
  }
}

class _AnswerBlocksView extends StatelessWidget {
  const _AnswerBlocksView({
    super.key,
    required this.blocks,
    this.animateBlocks = false,
  });

  final List<AskTitoDexAnswerBlock> blocks;
  final bool animateBlocks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          _SemanticAnswerBlock(
            key: ValueKey('ask-answer-block-${blocks[index].id}'),
            block: blocks[index],
            animate: animateBlocks,
          ),
          if (index != blocks.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SemanticAnswerBlock extends StatelessWidget {
  const _SemanticAnswerBlock({
    super.key,
    required this.block,
    required this.animate,
  });

  final AskTitoDexAnswerBlock block;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final child = switch (block.kind) {
      AskTitoDexAnswerBlockKind.summary => _AnswerTextPanel(
        block: block,
        icon: Icons.auto_awesome_rounded,
        color: TitoColors.skyBlue.withValues(alpha: 0.18),
      ),
      AskTitoDexAnswerBlockKind.paragraph => _AnswerTextPanel(block: block),
      AskTitoDexAnswerBlockKind.bullets => _AnswerBulletsBlock(block: block),
      AskTitoDexAnswerBlockKind.table => _AnswerTableBlock(block: block),
      AskTitoDexAnswerBlockKind.warning => _AnswerTextPanel(
        block: block,
        icon: Icons.info_outline_rounded,
        color: TitoColors.coral.withValues(alpha: 0.1),
        borderColor: TitoColors.coral.withValues(alpha: 0.34),
      ),
      AskTitoDexAnswerBlockKind.clarification => _AnswerTextPanel(
        block: block,
        icon: Icons.help_outline_rounded,
        color: TitoColors.softYellow.withValues(alpha: 0.18),
        borderColor: TitoColors.softYellow.withValues(alpha: 0.56),
      ),
    };
    if (!animate || reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 7 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _AnswerTextPanel extends StatelessWidget {
  const _AnswerTextPanel({
    required this.block,
    this.icon,
    this.color,
    this.borderColor,
  });

  final AskTitoDexAnswerBlock block;
  final IconData? icon;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final text = _answerBlockBody(block);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (block.title case final title?) ...[
          Row(
            children: [
              if (icon case final iconData?) ...[
                Icon(iconData, size: 17, color: TitoColors.deepBlue),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  style: SecondaryTypography.onCard.h15.copyWith(
                    color: TitoColors.deepBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (text.isNotEmpty) const SizedBox(height: 5),
        ] else if (icon case final iconData?) ...[
          Icon(iconData, size: 17, color: TitoColors.deepBlue),
          const SizedBox(height: 5),
        ],
        if (text.isNotEmpty)
          block.isComplete
              ? _AssistantMarkdown(data: text)
              : _BlinkingMarkdown(data: text),
      ],
    );
    if (color == null && borderColor == null) return content;
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: borderColor ?? TitoColors.deepBlue.withValues(alpha: 0.12),
        ),
      ),
      child: content,
    );
  }
}

class _AnswerBulletsBlock extends StatelessWidget {
  const _AnswerBulletsBlock({required this.block});

  final AskTitoDexAnswerBlock block;

  @override
  Widget build(BuildContext context) {
    final items = block.items.isNotEmpty
        ? block.items
        : _bulletItemsFromText(_answerBlockBody(block));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (block.title case final title?) ...[
          Text(
            title,
            style: SecondaryTypography.onCard.h15.copyWith(
              color: TitoColors.deepBlue,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
        ],
        for (var index = 0; index < items.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 7, right: 8),
                  decoration: const BoxDecoration(
                    color: TitoColors.mint,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: !block.isComplete && index == items.length - 1
                      ? _BlinkingMarkdown(data: items[index])
                      : _AssistantMarkdown(data: items[index]),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AnswerTableBlock extends StatelessWidget {
  const _AnswerTableBlock({required this.block});

  final AskTitoDexAnswerBlock block;

  @override
  Widget build(BuildContext context) {
    final rows = block.rows.isNotEmpty
        ? block.rows
        : _tableRowsFromText(_answerBlockBody(block));
    if (rows.isEmpty) {
      return _AnswerTextPanel(block: block);
    }
    final columnCount = rows.fold<int>(
      1,
      (count, row) => row.length > count ? row.length : count,
    );
    final compact = SecondaryTypography.onCard.small12.copyWith(
      color: TitoColors.ink,
      height: 1.3,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (block.title case final title?) ...[
          Text(
            title,
            style: SecondaryTypography.onCard.h15.copyWith(
              color: TitoColors.deepBlue,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(
                color: TitoColors.deepBlue.withValues(alpha: 0.2),
              ),
              children: [
                for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
                  TableRow(
                    decoration: rowIndex == 0
                        ? BoxDecoration(
                            color: TitoColors.skyBlue.withValues(alpha: 0.2),
                          )
                        : null,
                    children: [
                      for (var column = 0; column < columnCount; column++)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child:
                              !block.isComplete &&
                                  rowIndex == rows.length - 1 &&
                                  column == rows[rowIndex].length - 1
                              ? _BlinkingInlineText(
                                  text: column < rows[rowIndex].length
                                      ? rows[rowIndex][column]
                                      : '',
                                  style: compact,
                                )
                              : Text(
                                  column < rows[rowIndex].length
                                      ? rows[rowIndex][column]
                                      : '',
                                  style: rowIndex == 0
                                      ? compact.copyWith(
                                          color: TitoColors.deepBlue,
                                          fontWeight: FontWeight.w900,
                                        )
                                      : compact,
                                ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BlinkingInlineText extends StatefulWidget {
  const _BlinkingInlineText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_BlinkingInlineText> createState() => _BlinkingInlineTextState();
}

class _BlinkingInlineTextState extends State<_BlinkingInlineText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursor;

  @override
  void initState() {
    super.initState();
    _cursor = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 940),
      value: 1,
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _cursor.stop();
      _cursor.value = 1;
    }
  }

  @override
  void dispose() {
    _cursor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _cursor,
      builder: (context, _) => Text(
        _cursor.value >= 0.38 ? '${widget.text}▍' : '${widget.text}\u2009',
        style: widget.style,
      ),
    );
  }
}

String _answerBlockBody(AskTitoDexAnswerBlock block) {
  final text = block.text.trim();
  final title = block.title;
  if (title == null || text.isEmpty) return text;
  final lines = text.split('\n');
  if (lines.isNotEmpty &&
      lines.first.replaceFirst(RegExp(r'^#{1,6}\s+'), '').trim() == title) {
    return lines.skip(1).join('\n').trim();
  }
  return text;
}

List<String> _bulletItemsFromText(String text) => text
    .split('\n')
    .map(
      (line) =>
          line.replaceFirst(RegExp(r'^\s*(?:[-*+]\s+|\d+[.)、]\s*)'), '').trim(),
    )
    .where((line) => line.isNotEmpty)
    .toList(growable: false);

List<List<String>> _tableRowsFromText(String text) {
  final lines = text.split('\n').where((line) => line.contains('|')).toList();
  final rows = <List<String>>[];
  for (var index = 0; index < lines.length; index++) {
    if (index == 1 && RegExp(r'^\s*\|?\s*:?-{3,}:?').hasMatch(lines[index])) {
      continue;
    }
    final cells = lines[index]
        .replaceFirst(RegExp(r'^\s*\|'), '')
        .replaceFirst(RegExp(r'\|\s*$'), '')
        .split('|')
        .map((cell) => cell.trim())
        .toList(growable: false);
    if (cells.isNotEmpty) rows.add(cells);
  }
  return rows;
}

class _AssistantMarkdown extends StatelessWidget {
  const _AssistantMarkdown({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final body = SecondaryTypography.onCard.body14.copyWith(
      height: 1.45,
      color: TitoColors.ink,
    );
    final compact = SecondaryTypography.onCard.small12.copyWith(
      height: 1.35,
      color: TitoColors.ink,
    );
    final heading = SecondaryTypography.onCard.h15.copyWith(
      color: TitoColors.deepBlue,
      fontWeight: FontWeight.w900,
    );
    final headingPadding = const EdgeInsets.only(top: 7, bottom: 4);
    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      fitContent: true,
      // Answer links are intentionally inert. Only the structured citation
      // sheet may launch externally audited source URLs.
      onTapLink: (_, _, _) {},
      // Never let model-authored Markdown fetch arbitrary remote images.
      imageBuilder: (_, _, _) => const SizedBox.shrink(),
      styleSheet: MarkdownStyleSheet(
        p: body,
        pPadding: EdgeInsets.zero,
        h1: heading.copyWith(fontSize: 17),
        h1Padding: headingPadding,
        h2: heading,
        h2Padding: headingPadding,
        h3: body.copyWith(
          color: TitoColors.deepBlue,
          fontWeight: FontWeight.w900,
        ),
        h3Padding: headingPadding,
        h4: body.copyWith(fontWeight: FontWeight.w900),
        h4Padding: headingPadding,
        h5: body.copyWith(fontWeight: FontWeight.w900),
        h5Padding: headingPadding,
        h6: body.copyWith(fontWeight: FontWeight.w900),
        h6Padding: headingPadding,
        strong: body.copyWith(fontWeight: FontWeight.w900),
        em: body.copyWith(fontStyle: FontStyle.italic),
        a: body.copyWith(
          color: TitoColors.deepBlue,
          decoration: TextDecoration.none,
        ),
        code: compact.copyWith(
          backgroundColor: TitoColors.skyBlue.withValues(alpha: 0.26),
          fontFamily: 'monospace',
        ),
        blockSpacing: 8,
        listIndent: 18,
        listBullet: body.copyWith(fontWeight: FontWeight.w900),
        listBulletPadding: const EdgeInsets.only(right: 6),
        tableHead: compact.copyWith(
          color: TitoColors.deepBlue,
          fontWeight: FontWeight.w900,
        ),
        tableBody: compact,
        tableHeadAlign: TextAlign.left,
        tablePadding: const EdgeInsets.symmetric(vertical: 4),
        tableBorder: TableBorder.all(
          color: TitoColors.deepBlue.withValues(alpha: 0.25),
        ),
        tableColumnWidth: const IntrinsicColumnWidth(),
        tableScrollbarThumbVisibility: true,
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 6,
        ),
        tableHeadCellsDecoration: BoxDecoration(
          color: TitoColors.skyBlue.withValues(alpha: 0.22),
        ),
        blockquote: body.copyWith(color: TitoColors.mutedInk),
        blockquotePadding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
        blockquoteDecoration: BoxDecoration(
          color: TitoColors.skyBlue.withValues(alpha: 0.16),
          border: Border(
            left: BorderSide(
              color: TitoColors.deepBlue.withValues(alpha: 0.45),
              width: 3,
            ),
          ),
        ),
        codeblockPadding: const EdgeInsets.all(10),
        codeblockDecoration: BoxDecoration(
          color: TitoColors.skyBlue.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: TitoColors.deepBlue.withValues(alpha: 0.24)),
          ),
        ),
      ),
    );
  }
}

class _AnswerSkeletonLine extends StatelessWidget {
  const _AnswerSkeletonLine({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction,
        child: Container(
          height: 8,
          decoration: BoxDecoration(
            color: _assistantSkeleton,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _AnswerSkeletonEvidence extends StatelessWidget {
  const _AnswerSkeletonEvidence();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: _assistantSkeleton,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _AnswerReveal extends StatefulWidget {
  const _AnswerReveal({
    super.key,
    required this.animate,
    required this.child,
    this.onComplete,
  });

  final bool animate;
  final Widget child;
  final VoidCallback? onComplete;

  @override
  State<_AnswerReveal> createState() => _AnswerRevealState();
}

class _AnswerRevealState extends State<_AnswerReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _size;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  var _prepared = false;
  var _notified = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 460),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) _notifyComplete();
        });
    _size = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.86, curve: Curves.easeOutCubic),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.08, 1, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.045),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prepared) return;
    _prepared = true;
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      if (widget.animate) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _notifyComplete());
      }
    } else {
      _controller.forward();
    }
  }

  void _notifyComplete() {
    if (_notified || !mounted) return;
    _notified = true;
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _size,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}

class _EvidenceReveal extends StatefulWidget {
  const _EvidenceReveal({
    required this.animate,
    required this.child,
    this.onComplete,
  });

  final bool animate;
  final Widget child;
  final VoidCallback? onComplete;

  @override
  State<_EvidenceReveal> createState() => _EvidenceRevealState();
}

class _EvidenceRevealState extends State<_EvidenceReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;
  var _prepared = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 280),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onComplete?.call();
        });
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prepared) return;
    _prepared = true;
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      if (widget.animate) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.onComplete?.call(),
        );
      }
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 170), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _curve,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(_curve),
          child: widget.child,
        ),
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
            ? TitoColors.skyBlue.withValues(alpha: 0.38)
            : TitoColors.cardWarm,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: TitoColors.ink.withValues(alpha: 0.62),
          width: 1,
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

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.question,
    required this.result,
    required this.entityResolver,
    required this.sourceOpener,
    required this.animateEvidence,
    required this.onRetry,
    required this.onClarificationSelected,
  });

  final String question;
  final AskTitoDexResult result;
  final AskTitoDexEntityResolver entityResolver;
  final AskTitoDexSourceOpener sourceOpener;
  final bool animateEvidence;
  final VoidCallback onRetry;
  final ValueChanged<AskTitoDexClarificationCandidate> onClarificationSelected;

  @override
  Widget build(BuildContext context) {
    return AssistantSurface(
      key: const Key('ask-titodex-answer-card'),
      color: _assistantPaper,
      radius: 18,
      child: _AnswerCardContent(
        question: question,
        result: result,
        entityResolver: entityResolver,
        sourceOpener: sourceOpener,
        animateEvidence: animateEvidence,
        onRetry: onRetry,
        onClarificationSelected: onClarificationSelected,
      ),
    );
  }
}

class _AnswerCardContent extends StatelessWidget {
  const _AnswerCardContent({
    required this.question,
    required this.result,
    required this.entityResolver,
    required this.sourceOpener,
    required this.animateEvidence,
    required this.onRetry,
    required this.onClarificationSelected,
    this.onContentSettled,
  });

  final String question;
  final AskTitoDexResult result;
  final AskTitoDexEntityResolver entityResolver;
  final AskTitoDexSourceOpener sourceOpener;
  final bool animateEvidence;
  final VoidCallback onRetry;
  final ValueChanged<AskTitoDexClarificationCandidate> onClarificationSelected;
  final VoidCallback? onContentSettled;

  @override
  Widget build(BuildContext context) {
    if (result.status == AskTitoDexStatus.failed) {
      return Column(
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
      return Column(
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
          if (result.clarificationCandidates.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '请选择你明确指的是哪一个：',
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            _ClarificationCandidateChips(
              candidates: result.clarificationCandidates,
              onSelected: onClarificationSelected,
            ),
          ],
        ],
      );
    }
    final sourceKinds = result.sourceKinds.toSet().toList(growable: false);
    final sources = _uniqueSources(result.sources);
    final answerBody = askTitoDexAnswerBody(result.answer ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          key: const Key('ask-titodex-answer-trace'),
          spacing: 9,
          runSpacing: 4,
          children: [
            _AnswerMetaLabel(label: _answerModeLabel(result.answerMode)),
            _AnswerMetaLabel(
              label: result.modelUsed
                  ? AppZh.askTitoDexTraceModel
                  : AppZh.askTitoDexTraceNoModel,
              emphasized: result.modelUsed,
            ),
            if (result.aiSearchUsed)
              const _AnswerMetaLabel(
                label: AppZh.askTitoDexTraceAiSearch,
                emphasized: true,
              ),
            if (sourceKinds.isNotEmpty)
              _AnswerMetaLabel(
                label: AppZh.askTitoDexTraceSearchRoutes(sourceKinds.length),
                emphasized: true,
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (result.answerBlocks.isNotEmpty)
          _AnswerBlocksView(
            key: const Key('ask-titodex-answer'),
            blocks: result.answerBlocks,
          )
        else
          _AssistantMarkdown(
            key: const Key('ask-titodex-answer'),
            data: answerBody,
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
        const SizedBox(height: 12),
        _EvidenceReveal(
          animate: animateEvidence,
          onComplete: onContentSettled,
          child: _AnswerEvidenceSummary(
            confidence: result.confidence,
            sources: sources,
            sourceKinds: sourceKinds,
            sourceOpener: sourceOpener,
          ),
        ),
        if (answerBody.isNotEmpty) ...[
          const SizedBox(height: 10),
          _EntityLinkCards(
            question: question,
            answer: answerBody,
            resolver: entityResolver,
          ),
        ],
      ],
    );
  }
}

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

class _AnswerEvidenceSummary extends StatelessWidget {
  const _AnswerEvidenceSummary({
    required this.confidence,
    required this.sources,
    required this.sourceKinds,
    required this.sourceOpener,
  });

  final String confidence;
  final List<ProgressionSource> sources;
  final List<String> sourceKinds;
  final AskTitoDexSourceOpener sourceOpener;

  @override
  Widget build(BuildContext context) {
    final hasSources = sources.isNotEmpty;
    final verified = confidence != 'low';
    final label = hasSources
        ? verified
              ? AppZh.askTitoDexEvidenceVerified(sources.length)
              : AppZh.askTitoDexEvidenceLowConfidence(sources.length)
        : verified
        ? AppZh.askTitoDexEvidenceLocalVerified
        : AppZh.askTitoDexEvidenceUnverified;
    return Semantics(
      button: hasSources,
      label: hasSources ? '$label，查看详细引用' : label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('ask-titodex-source-summary'),
          borderRadius: BorderRadius.circular(12),
          onTap: hasSources
              ? () => _showAnswerSources(
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
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TitoColors.ink.withValues(alpha: 0.45)),
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
                    '查看',
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

Future<void> _showAnswerSources(
  BuildContext context, {
  required List<ProgressionSource> sources,
  required List<String> sourceKinds,
  required AskTitoDexSourceOpener sourceOpener,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: TitoColors.cardWarm,
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
    return Material(
      color: TitoColors.card,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        key: ValueKey('ask-titodex-source-$index'),
        enabled: uri != null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: TitoColors.ink.withValues(alpha: 0.38)),
        ),
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
              accessedAt == null ? host : '$host · 查阅 $accessedAt',
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
                    const SnackBar(
                      content: Text(AppZh.askTitoDexSourceLinkUnavailable),
                    ),
                  );
                }
              },
      ),
    );
  }
}

List<ProgressionSource> _uniqueSources(List<ProgressionSource> sources) {
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
                    visualDensity: const VisualDensity(
                      horizontal: -3,
                      vertical: -3,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: _entityChipColor(link.kind),
                    side: BorderSide(
                      color: TitoColors.deepBlue.withValues(alpha: 0.28),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    labelPadding: const EdgeInsets.only(left: 3, right: 4),
                    avatar: Icon(
                      _entityIcon(link.kind),
                      size: 15,
                      color: TitoColors.deepBlue,
                    ),
                    label: Text(
                      '${link.nameZh} · ${_entityKindLabel(link.kind)}',
                      style: SecondaryTypography.onCard.small12.copyWith(
                        color: TitoColors.deepBlue,
                        fontWeight: FontWeight.w900,
                      ),
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

Color _entityChipColor(AskTitoDexEntityKind kind) => switch (kind) {
  AskTitoDexEntityKind.pokemon => TitoColors.skyBlue.withValues(alpha: 0.34),
  AskTitoDexEntityKind.item => TitoColors.softYellow.withValues(alpha: 0.3),
  AskTitoDexEntityKind.move => TitoColors.coral.withValues(alpha: 0.16),
  AskTitoDexEntityKind.ability => TitoColors.mint.withValues(alpha: 0.24),
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
