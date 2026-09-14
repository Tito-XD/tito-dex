import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ask_titodex_answer_blocks.dart';
import 'ask_titodex_service.dart';
import 'progression_hints.dart';

/// Owns only semantic presentation. The page supplies its existing request
/// validity check, so network results, reveal work and history use one identity.
/// Preference reads occur when a queued block begins, matching the page's
/// original timing. Notifications leave rendering and scrolling with the page.
class AskTitoDexRevealController {
  AskTitoDexRevealController({
    required bool Function(int requestId, String editionToken) isActiveRequest,
    required bool Function() reduceMotion,
    required VoidCallback onChanged,
    required VoidCallback onBlocksChanged,
  }) : _requestIsActive = isActiveRequest,
       _reduceMotion = reduceMotion,
       _onChanged = onChanged,
       _onBlocksChanged = onBlocksChanged;

  static const revealFrame = Duration(milliseconds: 20);
  static const revealStepLimit = 112;
  static const cursorHold = Duration(milliseconds: 96);
  static const progressStageMinimum = Duration(milliseconds: 150);

  final bool Function(int requestId, String editionToken) _requestIsActive;
  final bool Function() _reduceMotion;
  final VoidCallback _onChanged;
  final VoidCallback _onBlocksChanged;
  AskTitoDexProgress _progress = AskTitoDexProgress.checkingLocal;
  List<AskTitoDexAnswerBlock> _streamedBlocks = const [];
  AskTitoDexClarification? _streamedClarification;
  var _semanticRevealSteps = 0;
  Future<void> _semanticRevealQueue = Future<void>.value();
  Timer? _progressTimer;
  DateTime _progressChangedAt = DateTime.fromMillisecondsSinceEpoch(0);
  var _disposed = false;

  AskTitoDexProgress get progress => _progress;
  List<AskTitoDexAnswerBlock> get blocks => _streamedBlocks;
  AskTitoDexClarification? get clarification => _streamedClarification;
  Future<void> get pending => _semanticRevealQueue;

  /// Called inside the page's request-start state update, after its identity
  /// advances. Old asynchronous work is invalidated by that same identity.
  void begin() {
    clear();
    _progress = AskTitoDexProgress.checkingLocal;
    _progressChangedAt = DateTime.now();
  }

  /// Silent reset: the page already rebuilds for an edition or request change.
  void clear() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _semanticRevealQueue = Future<void>.value();
    _resetStream();
  }

  void _resetStream() {
    _streamedBlocks = const [];
    _streamedClarification = null;
    _semanticRevealSteps = 0;
  }

  bool _isActiveRequest(int requestId, String editionToken) =>
      !_disposed && _requestIsActive(requestId, editionToken);

  void dispose() {
    _disposed = true;
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  Future<void> enqueue(
    AskTitoDexOnlineStreamEvent event,
    int requestId,
    String editionToken,
  ) {
    final next = _semanticRevealQueue.then(
      (_) => _applySemanticEvent(event, requestId, editionToken),
    );
    _semanticRevealQueue = next;
    return next;
  }

  Future<void> _applySemanticEvent(
    AskTitoDexOnlineStreamEvent event,
    int requestId,
    String editionToken,
  ) async {
    if (!_isActiveRequest(requestId, editionToken)) return;
    if (event.semanticReset) {
      _resetStream();
      _onBlocksChanged();
      return;
    }
    if (event.answerBlock case final block?) {
      await _revealBlock(block, requestId, editionToken);
    }
    if (event.clarification case final clarification?) {
      if (_isActiveRequest(requestId, editionToken)) {
        _streamedClarification = clarification;
        _onChanged();
      }
    }
  }

  void queueProgress(
    AskTitoDexProgress progress,
    int requestId,
    String editionToken,
  ) {
    if (!_isActiveRequest(requestId, editionToken) || progress == _progress) {
      return;
    }
    _progressTimer?.cancel();
    if (_reduceMotion()) {
      _showProgressNow(progress, requestId, editionToken);
      return;
    }
    final elapsed = DateTime.now().difference(_progressChangedAt);
    final delay = progressStageMinimum - elapsed;
    if (delay <= Duration.zero) {
      _showProgressNow(progress, requestId, editionToken);
      return;
    }
    _progressTimer = Timer(
      delay,
      () => _showProgressNow(progress, requestId, editionToken),
    );
  }

  void _showProgressNow(
    AskTitoDexProgress progress,
    int requestId,
    String editionToken,
  ) {
    if (!_isActiveRequest(requestId, editionToken)) return;
    _progressTimer?.cancel();
    _progressTimer = null;
    if (_progress != progress) {
      _progress = progress;
      _onChanged();
      _progressChangedAt = DateTime.now();
    }
  }

  Future<void> revealVerifiedResult(
    AskTitoDexResult result,
    int requestId,
    String editionToken,
  ) async {
    if (!_isActiveRequest(requestId, editionToken) ||
        result.status != AskTitoDexStatus.answered) {
      return;
    }
    final answer = askTitoDexAnswerBody(result.answer ?? '');
    final targetBlocks = result.answerBlocks.isNotEmpty
        ? result.answerBlocks
        : synthesizeAskTitoDexAnswerBlocks(answer);
    if (targetBlocks.isEmpty) return;
    final mustResetStream =
        _streamedBlocks.isNotEmpty &&
        ((result.errorCode?.contains('_fallback') ?? false) ||
            !_streamedBlocksAreCompatibleWith(targetBlocks));
    if (mustResetStream) {
      _resetStream();
      _onBlocksChanged();
    }
    _showProgressNow(
      AskTitoDexProgress.revealingAnswer,
      requestId,
      editionToken,
    );
    for (final block in targetBlocks) {
      await _revealBlock(block, requestId, editionToken);
      if (!_isActiveRequest(requestId, editionToken)) return;
    }
    if (_isActiveRequest(requestId, editionToken)) {
      _streamedBlocks = List.unmodifiable(targetBlocks);
      _onChanged();
    }
  }

  bool _streamedBlocksAreCompatibleWith(
    List<AskTitoDexAnswerBlock> authoritative,
  ) {
    if (_streamedBlocks.length > authoritative.length) return false;
    for (var index = 0; index < _streamedBlocks.length; index += 1) {
      final streamed = _streamedBlocks[index];
      final finalBlock = authoritative[index];
      if (streamed.id != finalBlock.id ||
          streamed.kind != finalBlock.kind ||
          streamed.title != finalBlock.title ||
          !finalBlock.text.startsWith(streamed.text)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _revealBlock(
    AskTitoDexAnswerBlock target,
    int requestId,
    String editionToken,
  ) async {
    if (!_isActiveRequest(requestId, editionToken)) return;
    final index = _streamedBlocks.indexWhere((block) => block.id == target.id);
    final current = index < 0 ? null : _streamedBlocks[index];
    final currentText = current?.text ?? '';
    final reduceMotion = _reduceMotion();
    if (current != null &&
        (current.kind != target.kind ||
            current.title != target.title ||
            !target.text.startsWith(currentText))) {
      _replaceStreamBlock(target);
      return;
    }
    if (index < 0) {
      _replaceStreamBlock(
        target.copyWith(
          text: '',
          isComplete: target.text.isEmpty && target.isComplete,
        ),
      );
    }
    final suffix = target.text.substring(currentText.length);
    if (suffix.isNotEmpty &&
        !reduceMotion &&
        _semanticRevealSteps < revealStepLimit) {
      final runes = suffix.runes.toList(growable: false);
      final remainingBudget = revealStepLimit - _semanticRevealSteps;
      var steps = runes.length < 28 ? runes.length : 28;
      if (steps > remainingBudget) steps = remainingBudget;
      final runesPerStep = (runes.length / steps).ceil();
      final visible = StringBuffer(currentText);
      var offset = 0;
      while (offset < runes.length &&
          _isActiveRequest(requestId, editionToken)) {
        final end = offset + runesPerStep < runes.length
            ? offset + runesPerStep
            : runes.length;
        visible.writeAll(runes.sublist(offset, end).map(String.fromCharCode));
        _semanticRevealSteps += 1;
        _replaceStreamBlock(
          target.copyWith(text: visible.toString(), isComplete: false),
        );
        offset = end;
        await Future<void>.delayed(revealFrame);
      }
    } else if (suffix.isNotEmpty) {
      _replaceStreamBlock(target.copyWith(isComplete: false));
    }
    if (!_isActiveRequest(requestId, editionToken)) return;
    final visible = _streamedBlocks.firstWhere(
      (block) => block.id == target.id,
      orElse: () => target,
    );
    if (visible.text != target.text) {
      _replaceStreamBlock(target.copyWith(isComplete: false));
    }
    if (target.isComplete) {
      if (!reduceMotion && !visible.isComplete) {
        await Future<void>.delayed(cursorHold);
      }
      if (_isActiveRequest(requestId, editionToken)) {
        _replaceStreamBlock(target);
      }
    }
  }

  void _replaceStreamBlock(AskTitoDexAnswerBlock block) {
    if (_disposed) return;
    final blocks = [..._streamedBlocks];
    final index = blocks.indexWhere((value) => value.id == block.id);
    if (index < 0) {
      blocks.add(block);
    } else {
      blocks[index] = block;
    }
    _streamedBlocks = List.unmodifiable(blocks);
    _onBlocksChanged();
  }
}
