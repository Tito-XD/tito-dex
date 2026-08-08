import 'dart:convert';

import 'package:flutter/services.dart';

class MoveVersionDataRepository {
  Future<Map<int, Set<String>>>? _future;
  Set<String> knownVersionGroups = const {};

  Future<Map<int, Set<String>>> load() => _future ??= _load();

  Future<Map<int, Set<String>>> _load() async {
    final source = await rootBundle.loadString(
      'assets/data/move_version_matrix.json',
    );
    final payload = jsonDecode(source) as Map<String, dynamic>;
    final moves = payload['moves'] as Map<String, dynamic>? ?? const {};
    final result = <int, Set<String>>{};
    for (final entry in moves.entries) {
      final id = int.tryParse(entry.key);
      final groups = entry.value;
      if (id != null && groups is List<dynamic>) {
        result[id] = groups.whereType<String>().toSet();
      }
    }
    knownVersionGroups = {for (final groups in result.values) ...groups};
    return result;
  }
}

final moveVersionDataRepository = MoveVersionDataRepository();
