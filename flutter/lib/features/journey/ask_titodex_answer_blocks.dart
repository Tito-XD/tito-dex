const askTitoDexMaxAnswerBlocks = 16;
const askTitoDexMaxBlockItems = 12;
const askTitoDexMaxBlockRows = 12;
const askTitoDexMaxBlockColumns = 6;
const askTitoDexMaxClarificationCandidates = 6;

final _askTitoDexStableId = RegExp(r'^[A-Za-z0-9._:-]{1,64}$');

bool isAskTitoDexStableId(Object? value) =>
    value is String && _askTitoDexStableId.hasMatch(value);

enum AskTitoDexStreamStage {
  retrieving('retrieving'),
  resolving('resolving'),
  verifying('verifying'),
  writing('writing');

  const AskTitoDexStreamStage(this.wireValue);

  final String wireValue;

  static AskTitoDexStreamStage? fromWire(Object? value) {
    for (final stage in values) {
      if (stage.wireValue == value) return stage;
    }
    return null;
  }
}

enum AskTitoDexAnswerBlockKind {
  summary('summary'),
  paragraph('paragraph'),
  bullets('bullets'),
  table('table'),
  warning('warning'),
  clarification('clarification');

  const AskTitoDexAnswerBlockKind(this.wireValue);

  final String wireValue;

  static AskTitoDexAnswerBlockKind? fromWire(Object? value) {
    for (final kind in values) {
      if (kind.wireValue == value) return kind;
    }
    return null;
  }
}

class AskTitoDexAnswerBlock {
  const AskTitoDexAnswerBlock({
    required this.id,
    required this.kind,
    this.turnId,
    this.title,
    this.text = '',
    this.items = const [],
    this.rows = const [],
    this.isComplete = true,
  });

  final String id;
  final String? turnId;
  final AskTitoDexAnswerBlockKind kind;
  final String? title;
  final String text;
  final List<String> items;
  final List<List<String>> rows;
  final bool isComplete;

  static AskTitoDexAnswerBlock? tryFromJson(
    Map<String, dynamic> json, {
    String? turnId,
    bool isComplete = true,
  }) {
    final id = json['id'];
    final kind = AskTitoDexAnswerBlockKind.fromWire(json['kind']);
    final title = json['title'];
    final text = json['text'];
    if (!isAskTitoDexStableId(id) ||
        kind == null ||
        (title != null &&
            (title is! String || title.isEmpty || title.length > 80)) ||
        text is! String ||
        text.length > 1200) {
      return null;
    }
    final rawItems =
        _boundedStrings(
          json['items'],
          maxCount: askTitoDexMaxBlockItems,
          maxLength: 240,
        ) ??
        const <String>[];
    final rawRows = _boundedRows(json['rows']) ?? const <List<String>>[];
    final canonicalBody = _canonicalBlockBody(text, title as String?);
    final canonicalItems = kind == AskTitoDexAnswerBlockKind.bullets
        ? _bulletItemsFromText(canonicalBody)
        : const <String>[];
    final canonicalRows = kind == AskTitoDexAnswerBlockKind.table
        ? _tableRowsFromText(canonicalBody)
        : const <List<String>>[];
    // `text` is the canonical answer. Projections are only rendering hints;
    // discard a partial or contradictory hint so the completed UI parses the
    // full canonical text instead of silently hiding content.
    final items = rawItems.isNotEmpty && _sameStrings(rawItems, canonicalItems)
        ? rawItems
        : const <String>[];
    final rows = rawRows.isNotEmpty && _sameRows(rawRows, canonicalRows)
        ? rawRows
        : const <List<String>>[];
    return AskTitoDexAnswerBlock(
      id: id as String,
      turnId: turnId,
      kind: kind,
      title: title,
      text: text,
      items: items,
      rows: rows,
      isComplete: isComplete,
    );
  }

  AskTitoDexAnswerBlock copyWith({String? text, bool? isComplete}) =>
      AskTitoDexAnswerBlock(
        id: id,
        turnId: turnId,
        kind: kind,
        title: title,
        text: text ?? this.text,
        items: items,
        rows: rows,
        isComplete: isComplete ?? this.isComplete,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.wireValue,
    if (title != null) 'title': title,
    'text': text,
    if (items.isNotEmpty) 'items': items,
    if (rows.isNotEmpty) 'rows': rows,
  };
}

class AskTitoDexAnswerPlan {
  const AskTitoDexAnswerPlan({required this.turnId, required this.blocks});

  final String turnId;
  final List<AskTitoDexAnswerBlock> blocks;
}

class AskTitoDexClarificationCandidate {
  const AskTitoDexClarificationCandidate({
    required this.id,
    required this.label,
    this.kind,
  });

  final String id;
  final String label;
  final String? kind;

  static AskTitoDexClarificationCandidate? tryFromJson(
    Map<String, dynamic> json,
  ) {
    final id = json['id'];
    final label = json['label'];
    final kind = json['kind'];
    if (!isAskTitoDexStableId(id) ||
        label is! String ||
        label.isEmpty ||
        label.length > 80 ||
        (kind != null &&
            (kind is! String ||
                !const {
                  'pokemon',
                  'move',
                  'item',
                  'ability',
                  'journey_hint',
                }.contains(kind)))) {
      return null;
    }
    return AskTitoDexClarificationCandidate(
      id: id as String,
      label: label,
      kind: kind as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    if (kind != null) 'kind': kind,
  };
}

class AskTitoDexClarification {
  const AskTitoDexClarification({
    required this.turnId,
    required this.prompt,
    required this.candidates,
  });

  final String turnId;
  final String prompt;
  final List<AskTitoDexClarificationCandidate> candidates;
}

List<String>? _boundedStrings(
  Object? value, {
  required int maxCount,
  required int maxLength,
}) {
  if (value == null) return const [];
  if (value is! List || value.length > maxCount) return null;
  final values = <String>[];
  for (final entry in value) {
    if (entry is! String || entry.isEmpty || entry.length > maxLength) {
      return null;
    }
    values.add(entry);
  }
  return List.unmodifiable(values);
}

List<List<String>>? _boundedRows(Object? value) {
  if (value == null) return const [];
  if (value is! List || value.length > askTitoDexMaxBlockRows) return null;
  final rows = <List<String>>[];
  for (final row in value) {
    final parsed = _boundedStrings(
      row,
      maxCount: askTitoDexMaxBlockColumns,
      maxLength: 240,
    );
    if (parsed == null || parsed.isEmpty) return null;
    rows.add(parsed);
  }
  return List.unmodifiable(rows);
}

String _canonicalBlockBody(String text, String? title) {
  final body = text.trim();
  if (title == null || body.isEmpty) return body;
  final lines = body.split('\n');
  if (lines.isNotEmpty &&
      lines.first.replaceFirst(RegExp(r'^#{1,6}\s+'), '').trim() == title) {
    return lines.skip(1).join('\n').trim();
  }
  return body;
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
  for (var index = 0; index < lines.length; index += 1) {
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

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _sameRows(List<List<String>> left, List<List<String>> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (!_sameStrings(left[index], right[index])) return false;
  }
  return true;
}
