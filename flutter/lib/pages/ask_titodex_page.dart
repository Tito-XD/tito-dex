import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:url_launcher/url_launcher.dart';

import '../features/companion/companion_repository.dart';
import '../features/game/game_catalog.dart';
import '../features/game/game_edition.dart';
import '../features/game/game_edition_repository.dart';
import '../features/journey/ask_titodex_answer_blocks.dart';
import '../features/journey/ask_motion_images.dart';
import '../features/journey/ask_titodex_entity_links.dart';
import '../features/journey/ask_titodex_history.dart';
import '../features/journey/ask_titodex_reveal_controller.dart';
import '../features/journey/ask_titodex_service.dart';
import '../features/journey/ask_titodex_settings.dart';
import '../features/journey/progression_hints.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../navigation/tito_route_work.dart';
import '../theme/device_layout.dart';
import '../widgets/ask/ask_answer_card.dart';
import '../widgets/ask/ask_answer_sources.dart';
import '../widgets/ask/ask_connection_status_card.dart';
import '../widgets/ask/ask_conversation.dart';
import '../widgets/ask/ask_history_sheet.dart';
import '../widgets/ask/ask_paper_style.dart';
import '../widgets/ask_titodex_loading.dart';
import '../widgets/secondary_page_scaffold.dart';

export '../widgets/ask/ask_answer_sources.dart' show AskTitoDexSourceOpener;

const _askTitoDexQuestionLimit = 240;

String buildAskTitoDexClarificationQuestion({
  required String originalQuestion,
  required String candidateLabel,
}) {
  final original = originalQuestion.trim();
  final label = candidateLabel.trim();
  final prefix = AppZh.askTitoDexClarificationPrefix(label);
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
    this.motionImagePreparer,
    this.historyStore,
    this.entityResolver,
    this.sourceOpener,
  });

  final CurrentJourney journey;
  final GameEdition edition;
  final AskTitoDexService? service;
  final AskMotionImagePreparer? motionImagePreparer;
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
  late final Completer<void> _historyReadyCompleter;
  late GameEdition _edition;
  AskTitoDexContext? _context;
  List<AskTitoDexHistoryEntry> _history = const [];
  AskTitoDexWorkerStatus _workerStatus =
      const AskTitoDexWorkerStatus.checking();
  late final AskTitoDexRevealController _reveal;
  var _requestSeed = 0;
  var _contextRequestId = 0;
  int? _activeEntryId;
  String? _submittedQuestion;
  bool _loading = false;
  AskTitoDexResult? _activeResult;
  var _initializationStarted = false;
  var _initializationPending = false;
  var _followingLatest = false;
  var _userScrolling = false;
  var _scrollUpdateScheduled = false;
  var _startLatestPending = false;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController();
    _answerScrollController = ScrollController();
    _service = widget.service ?? askTitoDexService;
    _historyStore = widget.historyStore ?? askTitoDexHistoryStore;
    _entityResolver = widget.entityResolver ?? askTitoDexEntityResolver;
    _edition = widget.edition;
    _reveal = AskTitoDexRevealController(
      isActiveRequest: _isActiveRequest,
      reduceMotion: () => MediaQuery.disableAnimationsOf(context),
      onChanged: _handleRevealChanged,
      onBlocksChanged: _handleRevealBlocksChanged,
    );
    _historyReadyCompleter = Completer<void>();
    _historyReady = _historyReadyCompleter.future;
    askTitoDexSettings.addListener(_handleSettingsChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Theme changes can recreate a page while another route covers it.
    // Defer until it becomes current, and retry if its first entry was covered.
    if (ModalRoute.isCurrentOf(context) ?? true) {
      unawaited(_startInitialTasksAfterRoute());
    }
  }

  void _handleSettingsChanged() {
    if (_initializationStarted) unawaited(_checkConnection());
  }

  Future<void> _startInitialTasksAfterRoute() async {
    if (_initializationStarted || _initializationPending) return;
    _initializationPending = true;
    try {
      final canStart = await waitForIncomingRouteSettled(context);
      if (canStart && mounted) {
        _startInitialTasks();
      }
    } finally {
      _initializationPending = false;
    }
  }

  void _startInitialTasks() {
    if (!mounted || _initializationStarted) return;
    _initializationStarted = true;
    unawaited(companionRepository.load());
    unawaited(_prepareContext());
    unawaited(_checkConnection());
    unawaited(_loadInitialHistory());
  }

  Future<void> _loadInitialHistory() async {
    try {
      await _loadHistory();
    } on Object {
      // A damaged optional conversation cache must not keep Ask TitoDex locked.
    } finally {
      if (!_historyReadyCompleter.isCompleted) {
        _historyReadyCompleter.complete();
      }
    }
  }

  @override
  void didUpdateWidget(covariant AskTitoDexPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.edition.slug != widget.edition.slug ||
        oldWidget.edition.selectedFlavor != widget.edition.selectedFlavor) {
      _requestSeed += 1;
      _reveal.clear();
      _edition = widget.edition;

      _context = null;
      _loading = false;
      _submittedQuestion = null;
      _activeEntryId = null;
      _activeResult = null;
      if (_initializationStarted) {
        unawaited(_prepareContext());
      }
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
      _reveal.clear();
      _edition = picked;
      _context = null;
      _submittedQuestion = null;
      _activeEntryId = null;
      _activeResult = null;
    });
    await _prepareContext();
  }

  Future<void> _showHistoryManager() async {
    final action = await showModalBottomSheet<AskHistoryManagerAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AskHistoryManagerSheet(entries: _history),
    );
    if (!mounted || action == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          action == AskHistoryManagerAction.clear
              ? AppZh.askTitoDexHistoryClearTitle
              : AppZh.askTitoDexHistoryCompactTitle,
        ),
        content: Text(
          action == AskHistoryManagerAction.clear
              ? AppZh.askTitoDexHistoryClearBody
              : AppZh.askTitoDexHistoryCompactBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppZh.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              action == AskHistoryManagerAction.clear
                  ? AppZh.askTitoDexHistoryClearConfirm
                  : AppZh.askTitoDexHistoryCompactConfirm,
            ),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    if (action == AskHistoryManagerAction.clear) {
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

      _requestSeed = requestId;
      _reveal.begin();
      _activeResult = null;
      _activeEntryId = null;
      _followingLatest = false;
    });

    // The latest turn grows down from a stable origin. Start there once;
    // incoming blocks must not move the reader to the end of a long answer.
    _scrollToLatest(animate: false, force: true);
    final result = await _service.ask(
      question,
      contextValue,
      history: askTitoDexRequestHistory(
        _history,
        game: contextValue.game ?? 'general',
      ),
      onProgress: (progress) {
        _reveal.queueProgress(progress, requestId, editionToken);
      },
      onStreamEvent: (event) => _reveal.enqueue(event, requestId, editionToken),
    );
    if (!_isActiveRequest(requestId, editionToken)) return;
    await _reveal.pending;
    if (!_isActiveRequest(requestId, editionToken)) return;
    await _reveal.revealVerifiedResult(result, requestId, editionToken);
    if (!_isActiveRequest(requestId, editionToken)) return;
    final entry = AskTitoDexHistoryEntry(
      game: contextValue.game ?? 'general',
      question: question,
      result: result,
      createdAt: DateTime.now(),
    );
    List<AskTitoDexHistoryEntry> saved;
    try {
      saved = await _historyStore.append(entry);
    } on Object catch (error) {
      // Persistence is best-effort: keep the turn for this session and
      // surface the failure instead of dropping it silently.
      debugPrint('AskTitoDex history append failed: $error');
      saved = askTitoDexHistoryAppend(_history, entry);
    }
    if (!_isActiveRequest(requestId, editionToken)) return;
    setState(() {
      _loading = false;
      _history = saved;
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

  void _handleRevealChanged() {
    if (mounted) setState(() {});
  }

  void _handleRevealBlocksChanged() {
    _handleRevealChanged();
    _scrollToLatest(animate: false);
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
    if (notification.depth != 0) return false;
    if (notification is UserScrollNotification) {
      _userScrolling = notification.direction != ScrollDirection.idle;
      if (notification.direction == ScrollDirection.forward) {
        _followingLatest = false;
      }
    }
    if (notification is ScrollUpdateNotification &&
        (notification.dragDetails != null || _userScrolling)) {
      if ((notification.scrollDelta ?? 0) < 0) {
        _followingLatest = false;
      } else if ((notification.scrollDelta ?? 0) > 0) {
        _followingLatest = notification.metrics.extentAfter <= 48;
      }
    } else if (notification is OverscrollNotification &&
        (notification.dragDetails != null || _userScrolling)) {
      _followingLatest =
          notification.overscroll > 0 && notification.metrics.extentAfter <= 48;
    }
    return false;
  }

  void _scrollToLatest({bool animate = true, bool force = false}) {
    if (!force && !_followingLatest) return;
    _startLatestPending = _startLatestPending || force;
    if (_scrollUpdateScheduled) return;
    _scrollUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollUpdateScheduled = false;
      final startLatest = _startLatestPending;
      _startLatestPending = false;
      if (!mounted ||
          !_answerScrollController.hasClients ||
          (!startLatest && !_followingLatest)) {
        return;
      }
      final duration =
          !animate || startLatest || MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220);
      final position = _answerScrollController.position;
      final target = startLatest
          ? 0.0.clamp(position.minScrollExtent, position.maxScrollExtent)
          : position.maxScrollExtent;
      if (duration == Duration.zero) {
        _answerScrollController.jumpTo(target);
        return;
      }
      unawaited(
        _answerScrollController.animateTo(
          target,
          duration: duration,
          curve: Curves.easeOut,
        ),
      );
    });
  }

  @override
  void dispose() {
    askTitoDexSettings.removeListener(_handleSettingsChanged);
    if (!_historyReadyCompleter.isCompleted) {
      _historyReadyCompleter.complete();
    }

    _reveal.dispose();
    _questionController.dispose();
    _answerScrollController.dispose();
    super.dispose();
  }

  Widget _buildHistoryTurn(AskTitoDexHistoryEntry entry, String? currentGame) {
    final entryId = entry.createdAt.microsecondsSinceEpoch;
    return Column(
      key: ValueKey('ask-turn-$entryId'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AskQuestionBubble(
          question: entry.question,
          game: entry.game,
          showGame: entry.game != (currentGame ?? 'general'),
        ),
        const SizedBox(height: 8),
        AskAnswerCard(
          key: ValueKey('ask-answer-$entryId'),
          question: entry.question,
          result: entry.result,
          entityResolver: _entityResolver,
          sourceOpener: widget.sourceOpener ?? _openExternalSource,
          animateEvidence: false,
          onRetry: () => _submit(entry.question),
          onClarificationSelected: (candidate) =>
              _submitClarification(entry.question, candidate),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildLiveTurn(String question) {
    return Column(
      key: ValueKey('ask-live-turn-container-$_requestSeed'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AskQuestionBubble(question: question),
        const SizedBox(height: 8),
        AskLiveAnswerCard(
          key: ValueKey('ask-live-turn-$_requestSeed'),
          question: question,
          prepareImages: widget.motionImagePreparer,
          progress: _reveal.progress,
          streamedBlocks: _reveal.blocks,
          clarification: _reveal.clarification,
          result: _activeResult,
          entityResolver: _entityResolver,
          sourceOpener: widget.sourceOpener ?? _openExternalSource,
          onRetry: () => _submit(question),
          onClarificationSelected: (candidate) =>
              _submitClarification(question, candidate),
          onContentSettled: _scrollToLatest,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final contextValue = _context;
    final pagePadding = DeviceLayout.pagePadding(context);
    final spacing = DeviceLayout.isCompact(context) ? 6.0 : 8.0;
    final historyTurns = _history
        .where(
          (entry) => entry.createdAt.microsecondsSinceEpoch != _activeEntryId,
        )
        .toList(growable: false);
    final showEmptyConversation =
        _history.isEmpty && _submittedQuestion == null && !_loading;
    final hasLiveTurn = _submittedQuestion != null;
    final olderTurns = hasLiveTurn || historyTurns.isEmpty
        ? historyTurns
        : historyTurns.sublist(0, historyTurns.length - 1);
    const latestTurnOrigin = ValueKey('ask-titodex-latest-turn-origin');
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
          child: SecondaryPageAppBar(title: AppZh.askTitoDexTitle),
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
                AskConnectionStatusCard(
                  status: _workerStatus,
                  historyCount: _history.length,
                  contextValue: contextValue,
                  edition: _edition,
                  onRefresh: _checkConnection,
                  onShowHistory: _showHistoryManager,
                  onChangeEdition: _loading ? null : _pickEdition,
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
                  progress: _reveal.progress,
                  requestSeed: _requestSeed,
                ),
                SizedBox(height: spacing),
                Expanded(
                  child: Container(
                    key: const Key('ask-titodex-answer-viewport'),
                    clipBehavior: Clip.antiAlias,
                    decoration: askAnswerViewportDecoration(context),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _handleAnswerScrollNotification,
                      child: Scrollbar(
                        controller: _answerScrollController,
                        child: CustomScrollView(
                          key: const Key('ask-titodex-answer-scroll'),
                          controller: _answerScrollController,
                          center: latestTurnOrigin,
                          slivers: [
                            // Older turns remain lazy above the origin; the
                            // live turn's growing bottom cannot push its top up.
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                              sliver: SliverList.builder(
                                itemCount: olderTurns.length,
                                itemBuilder: (context, index) =>
                                    _buildHistoryTurn(
                                      olderTurns[olderTurns.length - 1 - index],
                                      contextValue?.game,
                                    ),
                              ),
                            ),
                            SliverPadding(
                              key: latestTurnOrigin,
                              padding: const EdgeInsets.fromLTRB(
                                10,
                                10,
                                10,
                                12,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: showEmptyConversation
                                    ? AskConversationEmptyState(
                                        revealFrame: AskTitoDexRevealController
                                            .revealFrame,
                                        cursorHold: AskTitoDexRevealController
                                            .cursorHold,
                                        prepareImages:
                                            widget.motionImagePreparer,
                                      )
                                    : hasLiveTurn
                                    ? _buildLiveTurn(_submittedQuestion!)
                                    : _buildHistoryTurn(
                                        historyTurns.last,
                                        contextValue?.game,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: spacing),
                AskQuestionComposer(
                  questionLimit: _askTitoDexQuestionLimit,
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
