import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../features/companion/companion_repository.dart';
import '../features/game/game_edition.dart';
import '../features/journey/ask_titodex_answer_blocks.dart';
import '../features/journey/ask_motion_images.dart';
import '../features/journey/ask_titodex_entity_links.dart';
import '../features/journey/ask_titodex_history.dart';
import '../features/journey/ask_titodex_reveal_controller.dart';
import '../features/journey/ask_titodex_service.dart';
import '../features/journey/ask_titodex_settings.dart';
import '../features/journey/ask_titodex_source_browser.dart';
import '../features/journey/progression_hints.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../navigation/tito_route_work.dart';
import '../theme/device_layout.dart';
import '../widgets/ask/ask_answer_card.dart';
import '../widgets/ask/ask_answer_sources.dart';
import '../widgets/ask/ask_connection_status_card.dart';
import '../widgets/ask/ask_conversation.dart';
import '../widgets/ask/ask_sessions_sheet.dart';
import '../features/journey/ask_titodex_sessions.dart';
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
  final _questionFocus = FocusNode();
  AskTitoDexSessions? _sessions;
  late final AskTitoDexSessionStore _sessionStore;
  bool _sessionBusy = false;
  String? _notice;
  final _sessionDrafts = <String, TextEditingValue>{};
  int _draftRevision = 0;
  String _draftText = '';
  late final bool _ownsService;
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
    _questionController.addListener(() {
      final text = _questionController.text;
      if (text != _draftText) {
        _draftText = text;
        _draftRevision += 1;
      }
    });
    _answerScrollController = ScrollController();
    _ownsService = widget.service == null;
    _service = widget.service ?? AskTitoDexService();
    _historyStore = widget.historyStore ?? askTitoDexHistoryStore;
    _sessionStore = AskTitoDexSessionStore(legacy: _historyStore);
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
      _service.cancelActiveQuestion();
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
    final snapshot = await _sessionStore.load();
    if (!mounted) return;
    setState(() {
      _sessions = snapshot;
      _history = snapshot.active.entries;
    });
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

  void _stopWaiting({bool announce = true}) {
    if (!_loading) return;
    setState(() {
      _requestSeed += 1;
      _loading = false;
      _submittedQuestion = null;
      _activeEntryId = null;
      _activeResult = null;
      _reveal.clear();
      _notice = announce ? AppZh.askTitoDexStoppedWaiting : null;
    });
    _service.cancelActiveQuestion();
    _scrollToLatest(animate: false, force: true);
  }

  void _applySessions(AskTitoDexSessions snapshot, {bool reset = true}) {
    if (reset) {
      _stopWaiting(announce: false);
      _service.cancelActiveQuestion();
    }
    final previousId = _sessions?.activeId;
    if (reset && previousId != snapshot.activeId) {
      if (previousId != null) {
        _sessionDrafts[previousId] = _questionController.value;
      }
      _questionController.value =
          _sessionDrafts[snapshot.activeId] ?? TextEditingValue.empty;
    }
    setState(() {
      if (reset) {
        _notice = null;
        _requestSeed += 1;
        _reveal.clear();
        _submittedQuestion = null;
        _activeEntryId = null;
        _activeResult = null;
      }
      _sessions = snapshot;
      _history = snapshot.active.entries;
    });
    if (reset) _scrollToLatest(animate: false, force: true);
  }

  Future<bool> _confirmSessionDelete(AskTitoDexSession session) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            session.title.isEmpty ? AppZh.askTitoDexNewTopic : session.title,
          ),
          content: Text(
            '${AppZh.askTitoDexDeleteSessionBody}\n\n${askSessionSummary(session)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppZh.cancel),
            ),
            FilledButton(
              key: const Key('ask-session-delete-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(AppZh.askTitoDexDeleteSession),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _startNewTopic() async {
    await _historyReady;
    if (!mounted || _sessionBusy || _sessions == null) return;
    _stopWaiting(announce: false);
    setState(() => _sessionBusy = true);
    try {
      final snapshot = await _sessionStore.load();
      if (!mounted) return;
      String? replacement;
      if (snapshot.sessions.length >= askTitoDexSessionLimit &&
          snapshot.active.entries.isNotEmpty) {
        final choice = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(AppZh.askTitoDexSessionLimitTitle),
            content: Text(AppZh.askTitoDexSessionLimitBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(AppZh.cancel),
              ),
              TextButton(
                key: const Key('ask-session-limit-select'),
                onPressed: () => Navigator.pop(dialogContext, 'select'),
                child: Text(AppZh.askTitoDexPickSessionDelete),
              ),
              FilledButton(
                key: const Key('ask-session-limit-oldest'),
                onPressed: () => Navigator.pop(dialogContext, 'oldest'),
                child: Text(AppZh.askTitoDexDeleteOldestSession),
              ),
            ],
          ),
        );
        if (!mounted || choice == null) return;
        if (choice == 'oldest') {
          final oldest = [...snapshot.sessions]
            ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
          replacement = oldest.first.id;
        } else {
          final action = await showAskSessions(
            context,
            snapshot,
            chooseDeletion: true,
          );
          if (!mounted || action == null) return;
          replacement = action.id;
        }
        final selected = snapshot.sessions.firstWhere(
          (session) => session.id == replacement,
        );
        if (!await _confirmSessionDelete(selected) || !mounted) return;
      }
      final updated = await _sessionStore.create(replaceId: replacement);
      if (!mounted) return;
      _applySessions(updated);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppZh.askTitoDexSessionSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _sessionBusy = false);
    }
  }

  Future<void> _showSessionManager() async {
    final snapshot = _sessions;
    if (snapshot == null || _sessionBusy) return;
    final action = await showAskSessions(context, snapshot);
    if (!mounted || action == null) return;
    if (action.kind == 'create') {
      await _startNewTopic();
      return;
    }
    if (action.kind == 'delete') {
      final selected = snapshot.sessions.firstWhere(
        (session) => session.id == action.id,
      );
      if (!await _confirmSessionDelete(selected) || !mounted) return;
    }
    setState(() => _sessionBusy = true);
    try {
      final updated = action.kind == 'delete'
          ? await _sessionStore.delete(action.id!)
          : await _sessionStore.select(action.id!);
      if (mounted) {
        _applySessions(
          updated,
          reset: action.kind != 'delete' || action.id == snapshot.activeId,
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppZh.askTitoDexSessionSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _sessionBusy = false);
    }
  }

  void _selectSuggestion(String question) {
    _questionController.value = TextEditingValue(
      text: question,
      selection: TextSelection.collapsed(offset: question.length),
    );
    _questionFocus.requestFocus();
  }

  List<String> get _suggestions => _edition.isGeneral
      ? [
          AppZh.askTitoDexExampleGeneralEvolution,
          AppZh.askTitoDexExampleGeneralTypes,
        ]
      : [
          AppZh.askTitoDexExampleEvolution(_edition.selectedLabel),
          AppZh.askTitoDexExampleMoves(_edition.selectedLabel),
        ];

  Future<void> _submit([String? retryQuestion]) async {
    await _historyReady;
    if (!mounted) return;
    final contextValue = _context;
    final question = (retryQuestion ?? _questionController.text).trim();
    if (contextValue == null ||
        question.isEmpty ||
        _loading ||
        _sessionBusy ||
        _sessions == null) {
      return;
    }
    final sessionId = _sessions!.activeId;
    final draftRevision = _draftRevision;
    final requestId = _requestSeed + 1;
    final editionToken = _editionToken(_edition);
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _notice = null;
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
        includeOtherGames: true,
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
      game: result.contextUsed['game'] is String
          ? result.contextUsed['game'] as String
          : contextValue.game ?? 'general',
      question: question,
      result: result,
      createdAt: DateTime.now(),
    );
    List<AskTitoDexHistoryEntry> saved;
    AskTitoDexSessions? savedSessions;
    try {
      savedSessions = await _sessionStore.append(sessionId, entry);
      saved = savedSessions.active.entries;
      // Preserve existing integrations that supply their own legacy store.
      if (widget.historyStore != null) await _historyStore.append(entry);
    } on Object {
      saved = [..._history, entry];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppZh.askTitoDexSessionSaveFailed)),
        );
      }
    }
    if (!_isActiveRequest(requestId, editionToken)) return;
    setState(() {
      _loading = false;
      _history = saved;
      if (savedSessions != null) _sessions = savedSessions;
      _activeEntryId = entry.createdAt.microsecondsSinceEpoch;
      _activeResult = result;
      if (retryQuestion == null &&
          result.status == AskTitoDexStatus.answered &&
          _draftRevision == draftRevision) {
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

    _service.cancelActiveQuestion();
    if (_ownsService) _service.dispose();
    _reveal.dispose();
    _questionFocus.dispose();
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
          sourceOpener:
              widget.sourceOpener ??
              (uri) => openAskTitoDexSource(uri, theme: Theme.of(context)),
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
          sourceOpener:
              widget.sourceOpener ??
              (uri) => openAskTitoDexSource(uri, theme: Theme.of(context)),
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
                  onShowHistory: _showSessionManager,
                  sessionTitle: _sessions?.active.title.isNotEmpty == true
                      ? _sessions!.active.title
                      : AppZh.askTitoDexNewTopic,
                  onShowSessions: _sessionBusy ? null : _showSessionManager,
                  onChangeEdition: null,
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
                                        suggestions: _suggestions,
                                        onSelectSuggestion: _selectSuggestion,
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
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _notice!,
                        key: const Key('ask-titodex-notice'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                AskQuestionComposer(
                  questionLimit: _askTitoDexQuestionLimit,
                  controller: _questionController,
                  focusNode: _questionFocus,
                  onStop: _stopWaiting,
                  loading: _loading,
                  enabled:
                      contextValue != null &&
                      _sessions != null &&
                      !_sessionBusy,
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
