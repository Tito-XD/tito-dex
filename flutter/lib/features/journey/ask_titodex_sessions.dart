import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'ask_titodex_history.dart';

const askTitoDexSessionLimit = 20;

class AskTitoDexSession {
  const AskTitoDexSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.entries,
  });
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AskTitoDexHistoryEntry> entries;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };
  factory AskTitoDexSession.fromJson(Map<String, dynamic> value) {
    final id = value['id'];
    if (id is! String ||
        !RegExp(r'^[a-z0-9-]{1,80}$').hasMatch(id) ||
        value['entries'] is! List) {
      throw const FormatException('Invalid conversation');
    }
    final entries = <AskTitoDexHistoryEntry>[];
    for (final entry in value['entries'] as List) {
      if (entry is Map) {
        entries.add(
          AskTitoDexHistoryEntry.fromJson(Map<String, dynamic>.from(entry)),
        );
      }
    }
    return AskTitoDexSession(
      id: id,
      title: (value['title'] as String? ?? '').trim(),
      createdAt: DateTime.parse(value['createdAt'] as String),
      updatedAt: DateTime.parse(value['updatedAt'] as String),
      entries: List.unmodifiable(entries),
    );
  }
}

class AskTitoDexSessions {
  const AskTitoDexSessions({required this.activeId, required this.sessions});
  final String activeId;
  final List<AskTitoDexSession> sessions;
  AskTitoDexSession get active =>
      sessions.firstWhere((session) => session.id == activeId);
}

class AskTitoDexSessionLimitException implements Exception {}

/// Serialize local mutations. Reaching capacity never deletes a conversation.
class AskTitoDexSessionStore {
  AskTitoDexSessionStore({AskTitoDexHistoryStore? legacy})
    : _legacy = legacy ?? askTitoDexHistoryStore;
  static const _key = 'ask_titodex_sessions_v2';
  final AskTitoDexHistoryStore _legacy;
  static Future<void>? _pendingWrite;

  Future<T> _mutate<T>(Future<T> Function() operation) {
    final previous = _pendingWrite;
    final gate = Completer<void>();
    final result = Completer<T>();
    _pendingWrite = gate.future;
    Future<void> run() async {
      if (previous != null) await previous;
      try {
        result.complete(await operation());
      } catch (error, stack) {
        result.completeError(error, stack);
      } finally {
        gate.complete();
        if (identical(_pendingWrite, gate.future)) _pendingWrite = null;
      }
    }

    unawaited(run());
    return result.future;
  }

  Future<AskTitoDexSessions> load() => _mutate(_read);

  AskTitoDexSession _empty() {
    final now = DateTime.now();
    final id = List.generate(
      12,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return AskTitoDexSession(
      id: id,
      title: '',
      createdAt: now,
      updatedAt: now,
      entries: const [],
    );
  }

  Future<AskTitoDexSessions> _read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) {
      final previous = await _legacy.load();
      final empty = _empty();
      final initial = previous.isEmpty
          ? empty
          : AskTitoDexSession(
              id: empty.id,
              title: _title(previous.first.question),
              createdAt: previous.first.createdAt,
              updatedAt: previous.last.createdAt,
              entries: List.unmodifiable(previous),
            );
      return _save(
        AskTitoDexSessions(activeId: initial.id, sessions: [initial]),
      );
    }
    final value = jsonDecode(raw);
    if (value is! Map || value['version'] != 2 || value['sessions'] is! List) {
      throw const FormatException('Invalid conversations');
    }
    final sessions = (value['sessions'] as List)
        .map(
          (item) => AskTitoDexSession.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
    if (sessions.isEmpty ||
        sessions.map((session) => session.id).toSet().length !=
            sessions.length) {
      throw const FormatException('Invalid conversation index');
    }
    final requested = value['activeId'];
    return AskTitoDexSessions(
      activeId: sessions.any((session) => session.id == requested)
          ? requested as String
          : sessions.last.id,
      sessions: List.unmodifiable(sessions),
    );
  }

  Future<AskTitoDexSessions> _save(AskTitoDexSessions value) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _key,
      jsonEncode({
        'version': 2,
        'activeId': value.activeId,
        'sessions': value.sessions.map((session) => session.toJson()).toList(),
      }),
    );
    if (!saved) throw StateError('Conversation save failed');
    return value;
  }

  Future<AskTitoDexSessions> create({String? replaceId}) => _mutate(() async {
    final snapshot = await _read();
    if (snapshot.active.entries.isEmpty && replaceId == null) return snapshot;
    var sessions = [...snapshot.sessions];
    if (replaceId != null) {
      if (!sessions.any((session) => session.id == replaceId)) {
        throw StateError('Conversation no longer exists');
      }
      sessions.removeWhere((session) => session.id == replaceId);
    }
    if (sessions.length >= askTitoDexSessionLimit) {
      throw AskTitoDexSessionLimitException();
    }
    final fresh = _empty();
    sessions.add(fresh);
    return _save(
      AskTitoDexSessions(
        activeId: fresh.id,
        sessions: List.unmodifiable(sessions),
      ),
    );
  });

  Future<AskTitoDexSessions> select(String id) => _mutate(() async {
    final snapshot = await _read();
    if (!snapshot.sessions.any((session) => session.id == id)) {
      throw StateError('Conversation no longer exists');
    }
    return _save(AskTitoDexSessions(activeId: id, sessions: snapshot.sessions));
  });

  Future<AskTitoDexSessions> delete(String id) => _mutate(() async {
    final snapshot = await _read();
    final sessions = snapshot.sessions
        .where((session) => session.id != id)
        .toList();
    if (sessions.length == snapshot.sessions.length) return snapshot;
    if (sessions.isEmpty) sessions.add(_empty());
    return _save(
      AskTitoDexSessions(
        activeId: snapshot.activeId == id
            ? sessions.last.id
            : snapshot.activeId,
        sessions: List.unmodifiable(sessions),
      ),
    );
  });

  Future<AskTitoDexSessions> append(String id, AskTitoDexHistoryEntry entry) =>
      _mutate(() async {
        final snapshot = await _read();
        final sessions = snapshot.sessions
            .map(
              (session) => session.id != id
                  ? session
                  : AskTitoDexSession(
                      id: id,
                      title: session.title.isEmpty
                          ? _title(entry.question)
                          : session.title,
                      createdAt: session.createdAt,
                      updatedAt: entry.createdAt,
                      entries: List.unmodifiable([...session.entries, entry]),
                    ),
            )
            .toList(growable: false);
        // A deleted conversation cannot be recreated by a late response.
        return _save(
          AskTitoDexSessions(activeId: snapshot.activeId, sessions: sessions),
        );
      });
  String _title(String question) {
    final runes = question
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .runes
        .toList();
    return String.fromCharCodes(runes.take(30)) +
        (runes.length > 30 ? '…' : '');
  }
}
