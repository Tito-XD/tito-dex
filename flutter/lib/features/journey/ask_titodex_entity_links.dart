import 'dart:convert';

import 'package:flutter/services.dart';

enum AskTitoDexEntityKind { pokemon, item, move, ability }

class AskTitoDexEntityLink {
  const AskTitoDexEntityLink({
    required this.kind,
    required this.id,
    required this.nameZh,
    required this.nameEn,
    required this.route,
  });

  final AskTitoDexEntityKind kind;
  final int id;
  final String nameZh;
  final String nameEn;
  final String route;
}

abstract class AskTitoDexEntityResolver {
  Future<List<AskTitoDexEntityLink>> resolve({
    required String question,
    required String answer,
  });
}

class DexAskTitoDexEntityResolver implements AskTitoDexEntityResolver {
  DexAskTitoDexEntityResolver();

  Future<List<_EntityCandidate>>? _candidates;

  @override
  Future<List<AskTitoDexEntityLink>> resolve({
    required String question,
    required String answer,
  }) async {
    final candidates = await (_candidates ??= _loadCandidates());
    final questionLower = question.toLowerCase();
    final answerLower = answer.toLowerCase();
    final matches =
        candidates
            .where((candidate) {
              return candidate.matches(questionLower) ||
                  candidate.matches(answerLower);
            })
            .toList(growable: false)
          ..sort((left, right) {
            final leftInQuestion = left.matches(questionLower);
            final rightInQuestion = right.matches(questionLower);
            if (leftInQuestion != rightInQuestion) {
              return leftInQuestion ? -1 : 1;
            }
            final lengthCompare = right.nameZh.length.compareTo(
              left.nameZh.length,
            );
            if (lengthCompare != 0) {
              return lengthCompare;
            }
            final kindCompare = left.kind.index.compareTo(right.kind.index);
            if (kindCompare != 0) {
              return kindCompare;
            }
            return left.id.compareTo(right.id);
          });

    final seen = <String>{};
    final result = <AskTitoDexEntityLink>[];
    for (final candidate in matches) {
      final key = '${candidate.kind.name}:${candidate.id}';
      if (!seen.add(key)) continue;
      result.add(candidate.toLink());
      if (result.length == 6) {
        break;
      }
    }
    return result;
  }

  Future<List<_EntityCandidate>> _loadCandidates() async {
    final catalogs = await Future.wait([
      _loadLabelCatalog('species_labels.json'),
      _loadLabelCatalog('moves_labels.json'),
      _loadLabelCatalog('abilities_labels.json'),
      _loadLabelCatalog('items_labels.json'),
    ]);
    return [
      for (final group in [
        (AskTitoDexEntityKind.pokemon, catalogs[0]),
        (AskTitoDexEntityKind.move, catalogs[1]),
        (AskTitoDexEntityKind.ability, catalogs[2]),
        (AskTitoDexEntityKind.item, catalogs[3]),
      ])
        for (final entry in group.$2.entries)
          _EntityCandidate(
            kind: group.$1,
            id: int.parse(entry.key),
            nameZh: entry.value.$2,
            nameEn: entry.value.$1,
          ),
    ];
  }

  Future<Map<String, (String, String)>> _loadLabelCatalog(
    String filename,
  ) async {
    try {
      final source = await rootBundle.loadString('assets/l10n/zh/$filename');
      final decoded = jsonDecode(source);
      if (decoded is! Map) return const {};
      final result = <String, (String, String)>{};
      for (final entry in decoded.entries) {
        final id = int.tryParse(entry.key.toString());
        final value = entry.value;
        if (id == null || value is! Map) continue;
        final en = value['en'];
        final zh = value['zh'];
        if (en is String && zh is String && zh.trim().isNotEmpty) {
          result['$id'] = (en, zh);
        }
      }
      return result;
    } on Object {
      return const {};
    }
  }
}

class _EntityCandidate {
  const _EntityCandidate({
    required this.kind,
    required this.id,
    required this.nameZh,
    required this.nameEn,
  });

  final AskTitoDexEntityKind kind;
  final int id;
  final String nameZh;
  final String nameEn;

  bool matches(String haystack) {
    final zh = nameZh.trim().toLowerCase();
    final en = nameEn.trim().toLowerCase();
    return (zh.length >= 2 && haystack.contains(zh)) ||
        (en.length >= 4 && haystack.contains(en));
  }

  AskTitoDexEntityLink toLink() {
    final query = Uri.encodeQueryComponent(nameZh);
    final route = switch (kind) {
      AskTitoDexEntityKind.pokemon => '/dex/$id',
      AskTitoDexEntityKind.move => '/dex/moves?q=$query',
      AskTitoDexEntityKind.ability => '/dex/abilities?q=$query',
      AskTitoDexEntityKind.item => '/search/reference/json?kind=items&q=$query',
    };
    return AskTitoDexEntityLink(
      kind: kind,
      id: id,
      nameZh: nameZh,
      nameEn: nameEn,
      route: route,
    );
  }
}

final askTitoDexEntityResolver = DexAskTitoDexEntityResolver();
