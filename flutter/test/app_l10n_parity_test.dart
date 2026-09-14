import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guard for the zh/en copy pair: [kAppEn] is a plain string map looked up by
/// `AppZh.t`, so a missing key silently falls back to Chinese in the English
/// UI and a stale key is dead copy. Both directions must stay in lockstep.
///
/// The ids are collected from `lib/l10n/app_zh.dart` instead of a runtime
/// registry because `AppZh.t` receives plain string literals (and, in
/// `itemPriceBuy`/`itemPriceSell`, ternaries over literals).
void main() {
  test('kAppEn keys exactly match the ids requested by AppZh.t', () {
    final zhSource = File('lib/l10n/app_zh.dart').readAsStringSync();
    final enSource = File('lib/l10n/app_en.dart').readAsStringSync();

    final requestedIds = _translationIdsRequestedByAppZh(zhSource);
    final providedKeys = _kAppEnKeys(enSource);

    expect(
      requestedIds.difference(providedKeys).toList()..sort(),
      isEmpty,
      reason: 'These AppZh.t ids have no kAppEn entry and silently fall back '
          'to Chinese in the English UI. Add them to lib/l10n/app_en.dart.',
    );
    expect(
      providedKeys.difference(requestedIds).toList()..sort(),
      isEmpty,
      reason: 'These kAppEn entries are never requested by AppZh.t and are '
          'dead copy. Remove them from lib/l10n/app_en.dart.',
    );
  });
}

/// Collects every string literal that can become the id of an `AppZh.t(...)`
/// call. The first argument is either a literal or a ternary over literals,
/// so the quoted literals of each first argument cover both forms. String and
/// comment aware scanning keeps zh prose from producing fake ids.
Set<String> _translationIdsRequestedByAppZh(String source) {
  final ids = <String>{};
  var index = 0;
  while (index < source.length) {
    final skipped = _skipStringOrComment(source, index);
    if (skipped != null) {
      index = skipped;
      continue;
    }
    final isTCall =
        source[index] == 't' &&
        (index == 0 || !_isIdentifierChar(source.codeUnitAt(index - 1))) &&
        _nextMeaningfulChar(source, index + 1) == '(';
    if (isTCall) {
      ids.addAll(_quotedLiterals(_firstArgument(source, index + 1)));
    }
    index += 1;
  }
  return ids;
}

/// Returns the index just past a string literal or comment starting at
/// [index], or null when [index] does not start one.
int? _skipStringOrComment(String source, int index) {
  final char = source[index];
  if (char == "'" || char == '"') {
    var cursor = index + 1;
    while (cursor < source.length) {
      if (source[cursor] == r'\') {
        cursor += 2;
        continue;
      }
      if (source[cursor] == char) {
        return cursor + 1;
      }
      cursor += 1;
    }
    return cursor;
  }
  if (char == '/' && index + 1 < source.length) {
    if (source[index + 1] == '/') {
      final end = source.indexOf('\n', index);
      return end < 0 ? source.length : end + 1;
    }
    if (source[index + 1] == '*') {
      final end = source.indexOf('*/', index + 2);
      return end < 0 ? source.length : end + 2;
    }
  }
  return null;
}

/// Extracts the first argument of the call whose `(` sits at [openParen]:
/// the text up to the first top-level comma or the closing parenthesis.
String _firstArgument(String source, int openParen) {
  var depth = 0;
  var index = openParen + 1;
  while (index < source.length) {
    final skipped = _skipStringOrComment(source, index);
    if (skipped != null) {
      index = skipped;
      continue;
    }
    final char = source[index];
    if (char == '(' || char == '[' || char == '{') {
      depth += 1;
    } else if (char == ')' || char == ']' || char == '}') {
      if (depth == 0) {
        return source.substring(openParen + 1, index);
      }
      depth -= 1;
    } else if (char == ',' && depth == 0) {
      return source.substring(openParen + 1, index);
    }
    index += 1;
  }
  return source.substring(openParen + 1);
}

Set<String> _quotedLiterals(String text) => {
      for (final match in RegExp("'([^']*)'|\"([^\"]*)\"").allMatches(text))
        match.group(1) ?? match.group(2)!,
    };

Set<String> _kAppEnKeys(String source) => {
      for (final match in RegExp(
        "^\\s*'([^']+)'\\s*:|^\\s*\"([^\"]+)\"\\s*:",
        multiLine: true,
      ).allMatches(source))
        match.group(1) ?? match.group(2)!,
    };

bool _isIdentifierChar(int codeUnit) =>
    (codeUnit >= 0x30 && codeUnit <= 0x39) ||
    (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
    (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
    codeUnit == 0x5F ||
    codeUnit == 0x24;

String _nextMeaningfulChar(String source, int index) {
  for (var cursor = index; cursor < source.length; cursor += 1) {
    final char = source[cursor];
    if (char != ' ' && char != '\t' && char != '\n' && char != '\r') {
      return char;
    }
  }
  return '';
}
