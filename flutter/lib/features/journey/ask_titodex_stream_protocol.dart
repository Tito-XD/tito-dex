import 'ask_titodex_answer_blocks.dart';

const _maxStreamBlockDeltaLength = 512;
const _maxStreamBlockTextLength = 1200;

class AskTitoDexSemanticStreamUpdate {
  const AskTitoDexSemanticStreamUpdate({
    this.stage,
    this.turnId,
    this.answerPlan,
    this.answerBlock,
    this.clarification,
  });

  final AskTitoDexStreamStage? stage;
  final String? turnId;
  final AskTitoDexAnswerPlan? answerPlan;
  final AskTitoDexAnswerBlock? answerBlock;
  final AskTitoDexClarification? clarification;
}

/// Stateful validator for the optional semantic NDJSON layer.
///
/// An invalid, oversized, duplicate or out-of-order semantic event disables
/// the progressive layer. The caller still consumes the authoritative final
/// `result`, which replaces any incomplete semantic projection.
class AskTitoDexSemanticStreamDecoder {
  String? _turnId;
  AskTitoDexAnswerPlan? _plan;
  AskTitoDexAnswerBlock? _openBlock;
  final List<AskTitoDexAnswerBlock> _completedBlocks = [];
  var _nextBlockIndex = 0;
  var _disabled = false;

  bool get isDisabled => _disabled;

  AskTitoDexSemanticStreamUpdate? decode(Map<String, dynamic> event) {
    final type = event['type'];
    if (type == 'progress') return _decodeProgress(event);
    if (_disabled) return null;
    return switch (type) {
      'answer_plan' => _decodePlan(event),
      'block_start' => _decodeBlockStart(event),
      'block_delta' => _decodeBlockDelta(event),
      'block_end' => _decodeBlockEnd(event),
      'clarification' => _decodeClarification(event),
      _ => null,
    };
  }

  bool validateFinal({
    required Object? turnId,
    required List<AskTitoDexAnswerBlock> blocks,
  }) {
    if (_disabled || _plan == null) return true;
    if (!_acceptTurnId(turnId) ||
        _openBlock != null ||
        _nextBlockIndex != _plan!.blocks.length ||
        blocks.length != _completedBlocks.length) {
      return false;
    }
    for (var index = 0; index < blocks.length; index += 1) {
      final streamed = _completedBlocks[index];
      final finalBlock = blocks[index];
      if (streamed.id != finalBlock.id ||
          streamed.kind != finalBlock.kind ||
          streamed.title != finalBlock.title ||
          streamed.text != finalBlock.text) {
        return false;
      }
    }
    return true;
  }

  AskTitoDexSemanticStreamUpdate? _decodeProgress(Map<String, dynamic> event) {
    final stage = AskTitoDexStreamStage.fromWire(event['stage']);
    if (stage == null) return null;
    final rawTurnId = event['turnId'];
    String? turnId;
    if (rawTurnId != null && isAskTitoDexStableId(rawTurnId)) {
      turnId = rawTurnId as String;
      if (!_disabled && !_acceptTurnId(turnId)) return null;
    }
    return AskTitoDexSemanticStreamUpdate(stage: stage, turnId: turnId);
  }

  AskTitoDexSemanticStreamUpdate? _decodePlan(Map<String, dynamic> event) {
    if (_plan != null || !_acceptTurnId(event['turnId'])) {
      return _disable();
    }
    final rawBlocks = event['blocks'];
    if (rawBlocks is! List ||
        rawBlocks.isEmpty ||
        rawBlocks.length > askTitoDexMaxAnswerBlocks) {
      return _disable();
    }
    final blocks = <AskTitoDexAnswerBlock>[];
    final ids = <String>{};
    for (final rawBlock in rawBlocks) {
      if (rawBlock is! Map) return _disable();
      final block = Map<String, dynamic>.from(rawBlock);
      final id = block['blockId'];
      final kind = AskTitoDexAnswerBlockKind.fromWire(block['kind']);
      final title = block['title'];
      if (!isAskTitoDexStableId(id) ||
          !ids.add(id as String) ||
          kind == null ||
          (title != null &&
              (title is! String || title.isEmpty || title.length > 80))) {
        return _disable();
      }
      blocks.add(
        AskTitoDexAnswerBlock(
          id: id,
          turnId: _turnId,
          kind: kind,
          title: title as String?,
          isComplete: false,
        ),
      );
    }
    final plan = AskTitoDexAnswerPlan(
      turnId: _turnId!,
      blocks: List.unmodifiable(blocks),
    );
    _plan = plan;
    return AskTitoDexSemanticStreamUpdate(turnId: _turnId, answerPlan: plan);
  }

  AskTitoDexSemanticStreamUpdate? _decodeBlockStart(
    Map<String, dynamic> event,
  ) {
    if (!_matchesTurn(event) ||
        _plan == null ||
        _openBlock != null ||
        _nextBlockIndex >= _plan!.blocks.length) {
      return _disable();
    }
    final planned = _plan!.blocks[_nextBlockIndex];
    if (event['blockId'] != planned.id ||
        AskTitoDexAnswerBlockKind.fromWire(event['kind']) != planned.kind ||
        event['title'] != planned.title) {
      return _disable();
    }
    _openBlock = planned;
    return AskTitoDexSemanticStreamUpdate(
      turnId: _turnId,
      answerBlock: planned,
    );
  }

  AskTitoDexSemanticStreamUpdate? _decodeBlockDelta(
    Map<String, dynamic> event,
  ) {
    final delta = event['delta'];
    if (!_matchesOpenBlock(event) ||
        delta is! String ||
        delta.isEmpty ||
        delta.length > _maxStreamBlockDeltaLength ||
        _openBlock!.text.length + delta.length > _maxStreamBlockTextLength) {
      return _disable();
    }
    _openBlock = _openBlock!.copyWith(text: _openBlock!.text + delta);
    return AskTitoDexSemanticStreamUpdate(
      turnId: _turnId,
      answerBlock: _openBlock,
    );
  }

  AskTitoDexSemanticStreamUpdate? _decodeBlockEnd(Map<String, dynamic> event) {
    if (!_matchesOpenBlock(event)) return _disable();
    final completed = _openBlock!.copyWith(isComplete: true);
    _completedBlocks.add(completed);
    _openBlock = null;
    _nextBlockIndex += 1;
    return AskTitoDexSemanticStreamUpdate(
      turnId: _turnId,
      answerBlock: completed,
    );
  }

  AskTitoDexSemanticStreamUpdate? _decodeClarification(
    Map<String, dynamic> event,
  ) {
    if (!_acceptTurnId(event['turnId'])) return _disable();
    final prompt = event['prompt'];
    final rawCandidates = event['candidates'];
    if (prompt is! String ||
        prompt.isEmpty ||
        prompt.length > 240 ||
        rawCandidates is! List ||
        rawCandidates.length > askTitoDexMaxClarificationCandidates) {
      return _disable();
    }
    final candidates = <AskTitoDexClarificationCandidate>[];
    final ids = <String>{};
    for (final rawCandidate in rawCandidates) {
      if (rawCandidate is! Map) return _disable();
      final candidate = AskTitoDexClarificationCandidate.tryFromJson(
        Map<String, dynamic>.from(rawCandidate),
      );
      if (candidate == null || !ids.add(candidate.id)) return _disable();
      candidates.add(candidate);
    }
    final clarification = AskTitoDexClarification(
      turnId: _turnId!,
      prompt: prompt,
      candidates: List.unmodifiable(candidates),
    );
    return AskTitoDexSemanticStreamUpdate(
      turnId: _turnId,
      clarification: clarification,
    );
  }

  bool _matchesTurn(Map<String, dynamic> event) =>
      _acceptTurnId(event['turnId']);

  bool _matchesOpenBlock(Map<String, dynamic> event) =>
      _openBlock != null &&
      _matchesTurn(event) &&
      event['blockId'] == _openBlock!.id;

  bool _acceptTurnId(Object? value) {
    if (!isAskTitoDexStableId(value)) return false;
    final valueAsString = value as String;
    if (_turnId != null && _turnId != valueAsString) return false;
    _turnId ??= valueAsString;
    return true;
  }

  AskTitoDexSemanticStreamUpdate? _disable() {
    _disabled = true;
    _plan = null;
    _openBlock = null;
    _completedBlocks.clear();
    return null;
  }
}
