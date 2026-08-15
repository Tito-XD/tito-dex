import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'progression_hints.dart';

const askTitoDexHistoryLimit = 50;
const askTitoDexContextEntryLimit = 6;
const _historyStorageKey = 'ask_titodex_conversation_v1';

class AskTitoDexHistoryEntry {
  const AskTitoDexHistoryEntry({
    required this.game,
    required this.question,
    required this.result,
    required this.createdAt,
  });

  final String game;
  final String question;
  final AskTitoDexResult result;
  final DateTime createdAt;

  String? get assistantContent {
    final value = result.answer ?? result.followUp;
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Map<String, dynamic> toJson() => {
    'game': game,
    'question': question,
    'result': result.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory AskTitoDexHistoryEntry.fromJson(Map<String, dynamic> json) {
    final game = json['game'];
    final question = json['question'];
    final result = json['result'];
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (game is! String ||
        game.isEmpty ||
        question is! String ||
        question.trim().isEmpty ||
        question.length > 240 ||
        result is! Map ||
        createdAt == null) {
      throw const FormatException('Invalid Ask TitoDex history entry.');
    }
    return AskTitoDexHistoryEntry(
      game: game,
      question: question.trim(),
      result: AskTitoDexResult.fromJson(Map<String, dynamic>.from(result)),
      createdAt: createdAt,
    );
  }
}

abstract class AskTitoDexHistoryStore {
  Future<List<AskTitoDexHistoryEntry>> load();

  Future<List<AskTitoDexHistoryEntry>> append(AskTitoDexHistoryEntry entry);

  Future<void> clear();
}

class SharedPreferencesAskTitoDexHistoryStore
    implements AskTitoDexHistoryStore {
  const SharedPreferencesAskTitoDexHistoryStore();

  @override
  Future<List<AskTitoDexHistoryEntry>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_historyStorageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map ||
          decoded['version'] != 1 ||
          decoded['entries'] is! List) {
        return const [];
      }
      final entries = <AskTitoDexHistoryEntry>[];
      for (final value in (decoded['entries'] as List).take(
        askTitoDexHistoryLimit,
      )) {
        if (value is! Map) continue;
        try {
          entries.add(
            AskTitoDexHistoryEntry.fromJson(Map<String, dynamic>.from(value)),
          );
        } on Object {
          // A corrupt record must not hide the remaining local conversation.
        }
      }
      entries.sort((left, right) => left.createdAt.compareTo(right.createdAt));
      return List.unmodifiable(
        entries.length > askTitoDexHistoryLimit
            ? entries.sublist(entries.length - askTitoDexHistoryLimit)
            : entries,
      );
    } on Object {
      return const [];
    }
  }

  @override
  Future<List<AskTitoDexHistoryEntry>> append(
    AskTitoDexHistoryEntry entry,
  ) async {
    final entries = [...await load(), entry];
    final trimmed = entries.length > askTitoDexHistoryLimit
        ? entries.sublist(entries.length - askTitoDexHistoryLimit)
        : entries;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _historyStorageKey,
      jsonEncode({
        'version': 1,
        'entries': trimmed.map((value) => value.toJson()).toList(),
      }),
    );
    return List.unmodifiable(trimmed);
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_historyStorageKey);
  }
}

List<Map<String, String>> askTitoDexRequestHistory(
  List<AskTitoDexHistoryEntry> entries, {
  required String game,
}) {
  final eligible = entries
      .where((entry) {
        if (entry.game != game || entry.assistantContent == null) return false;
        return entry.result.status == AskTitoDexStatus.answered ||
            entry.result.status == AskTitoDexStatus.needsClarification;
      })
      .toList(growable: false);
  final recent = eligible.length > askTitoDexContextEntryLimit
      ? eligible.sublist(eligible.length - askTitoDexContextEntryLimit)
      : eligible;
  return [
    for (final entry in recent) ...[
      {'role': 'user', 'content': entry.question},
      {
        'role': 'assistant',
        'content': entry.assistantContent!.length > 600
            ? entry.assistantContent!.substring(0, 600)
            : entry.assistantContent!,
      },
    ],
  ];
}

const askTitoDexHistoryStore = SharedPreferencesAskTitoDexHistoryStore();
