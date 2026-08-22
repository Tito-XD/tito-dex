import 'dart:convert';

import 'package:flutter/services.dart';

import '../dex/dex_models.dart';
import '../dex/dex_repository.dart';

enum AskTitoDexEntityKind { pokemon, item, move, ability }

class AskTitoDexEntityLink {
  const AskTitoDexEntityLink({
    required this.kind,
    required this.id,
    required this.nameZh,
    required this.nameEn,
    required this.route,
    this.slug = '',
  });

  final AskTitoDexEntityKind kind;
  final int id;
  final String nameZh;
  final String nameEn;

  /// Stable machine name from the bundle. Older v14/v19 data may omit it.
  final String slug;
  final String route;
}

class AskTitoDexEntityRecord {
  const AskTitoDexEntityRecord({
    required this.kind,
    required this.id,
    required this.nameZh,
    required this.nameEn,
    this.slug = '',
    this.aliasesZh = const [],
    this.aliasesEn = const [],
  });

  final AskTitoDexEntityKind kind;
  final int id;
  final String nameZh;
  final String nameEn;
  final String slug;
  final List<String> aliasesZh;
  final List<String> aliasesEn;
}

typedef AskTitoDexEntityCatalogLoader =
    Future<List<AskTitoDexEntityRecord>> Function();

abstract class AskTitoDexEntityResolver {
  Future<List<AskTitoDexEntityLink>> resolve({
    required String question,
    required String answer,
  });
}

class DexAskTitoDexEntityResolver implements AskTitoDexEntityResolver {
  DexAskTitoDexEntityResolver({AskTitoDexEntityCatalogLoader? catalogLoader})
    : _catalogLoader = catalogLoader;

  final AskTitoDexEntityCatalogLoader? _catalogLoader;

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
    final duplicateNames = <String, int>{};
    for (final candidate in matches) {
      final key = '${candidate.kind.name}:${candidate.nameZh.trim()}';
      duplicateNames[key] = (duplicateNames[key] ?? 0) + 1;
    }
    final result = <AskTitoDexEntityLink>[];
    for (final candidate in matches) {
      final nameKey = '${candidate.kind.name}:${candidate.nameZh.trim()}';
      if ((duplicateNames[nameKey] ?? 0) > 1 &&
          !candidate.matchesStableIdentifier(questionLower) &&
          !candidate.matchesStableIdentifier(answerLower)) {
        // A translated label can legitimately map to multiple upstream
        // records. Without an English name, slug, or explicit #id there is no
        // safe target, so do not manufacture a misleading chip.
        continue;
      }
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
    if (_catalogLoader != null) {
      return (await _catalogLoader())
          .map(_EntityCandidate.fromRecord)
          .toList(growable: false);
    }

    final runtime = await _loadRuntimeCandidates();
    final runtimeKinds = runtime.map((entry) => entry.kind).toSet();
    final catalogs = await Future.wait([
      _loadLabelCatalog('species_labels.json'),
      _loadLabelCatalog('moves_labels.json'),
      _loadLabelCatalog('abilities_labels.json'),
      _loadLabelCatalog('items_labels.json'),
    ]);
    final legacyFallback = [
      for (final group in [
        (AskTitoDexEntityKind.pokemon, catalogs[0]),
        (AskTitoDexEntityKind.move, catalogs[1]),
        (AskTitoDexEntityKind.ability, catalogs[2]),
        (AskTitoDexEntityKind.item, catalogs[3]),
      ])
        if (!runtimeKinds.contains(group.$1))
          for (final entry in group.$2.entries)
            _EntityCandidate(
              kind: group.$1,
              id: int.parse(entry.key),
              nameZh: entry.value.$2,
              nameEn: entry.value.$1,
            ),
    ];
    return _mergeCandidates([...runtime, ...legacyFallback]);
  }

  Future<List<_EntityCandidate>> _loadRuntimeCandidates() async {
    final results = await Future.wait<List<_EntityCandidate>>([
      _loadEntityIndex(),
      _loadPokemonCandidates(),
      _loadMoveCandidates(),
      _loadAbilityCandidates(),
      _loadItemCandidates(),
    ]);
    return _mergeCandidates(results.expand((group) => group));
  }

  Future<List<_EntityCandidate>> _loadEntityIndex() async {
    try {
      final entries = await dexRepository.getReferenceEntries(
        'entity_index.json',
      );
      return entries
          .map(_candidateFromEntityIndex)
          .whereType<_EntityCandidate>()
          .toList(growable: false);
    } on Object {
      // v19 and the compact v14 seed predate entity_index.json. Runtime
      // catalogs below remain authoritative for those bundles.
      return const [];
    }
  }

  Future<List<_EntityCandidate>> _loadPokemonCandidates() async {
    try {
      final entries = await dexRepository.getAllSummaries();
      return entries
          .map(
            (entry) => _EntityCandidate(
              kind: AskTitoDexEntityKind.pokemon,
              id: entry.id,
              nameZh: entry.nameZh,
              nameEn: entry.nameEn,
              slug: _stableSlug(entry.nameEn),
            ),
          )
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  Future<List<_EntityCandidate>> _loadMoveCandidates() async {
    try {
      final entries = await dexRepository.getAllMoves();
      return entries.map(_candidateFromMove).toList(growable: false);
    } on Object {
      return const [];
    }
  }

  Future<List<_EntityCandidate>> _loadAbilityCandidates() async {
    try {
      final entries = await dexRepository.getAllAbilities();
      return entries
          .map(
            (entry) => _EntityCandidate(
              kind: AskTitoDexEntityKind.ability,
              id: entry.id,
              nameZh: entry.nameZh,
              nameEn: entry.nameEn,
              slug: _stableSlug(entry.nameEn),
            ),
          )
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  Future<List<_EntityCandidate>> _loadItemCandidates() async {
    try {
      final entries = await dexRepository.getReferenceEntries('items.json');
      return entries
          .map(_candidateFromItem)
          .whereType<_EntityCandidate>()
          .toList(growable: false);
    } on Object {
      return const [];
    }
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
    this.slug = '',
    this.aliasesZh = const [],
    this.aliasesEn = const [],
  });

  factory _EntityCandidate.fromRecord(AskTitoDexEntityRecord record) =>
      _EntityCandidate(
        kind: record.kind,
        id: record.id,
        nameZh: record.nameZh,
        nameEn: record.nameEn,
        slug: record.slug,
        aliasesZh: record.aliasesZh,
        aliasesEn: record.aliasesEn,
      );

  final AskTitoDexEntityKind kind;
  final int id;
  final String nameZh;
  final String nameEn;
  final String slug;
  final List<String> aliasesZh;
  final List<String> aliasesEn;

  bool matches(String haystack) {
    final zhNames = [nameZh, ...aliasesZh]
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.length >= 2);
    final enNames = [nameEn, slug, ...aliasesEn]
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.length >= 4);
    return zhNames.any(haystack.contains) ||
        enNames.any((name) => _containsEnglishToken(haystack, name));
  }

  bool matchesStableIdentifier(String haystack) {
    if (haystack.contains('#$id')) return true;
    return [nameEn, slug, ...aliasesEn]
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.length >= 4)
        .any((value) => _containsEnglishToken(haystack, value));
  }

  AskTitoDexEntityLink toLink() {
    final query = Uri.encodeQueryComponent(nameZh);
    final route = switch (kind) {
      AskTitoDexEntityKind.pokemon => '/dex/$id',
      AskTitoDexEntityKind.move => '/dex/moves?id=$id&open=1&q=$query',
      AskTitoDexEntityKind.ability => '/dex/abilities?id=$id&open=1&q=$query',
      AskTitoDexEntityKind.item =>
        '/search/reference/json?kind=items&id=$id&open=1&q=$query',
    };
    return AskTitoDexEntityLink(
      kind: kind,
      id: id,
      nameZh: nameZh,
      nameEn: nameEn,
      slug: slug,
      route: route,
    );
  }
}

List<_EntityCandidate> _mergeCandidates(Iterable<_EntityCandidate> entries) {
  final result = <String, _EntityCandidate>{};
  for (final entry in entries) {
    if (entry.id <= 0 || entry.nameZh.trim().isEmpty) continue;
    final key = '${entry.kind.name}:${entry.id}';
    final existing = result[key];
    if (existing == null || existing.slug.isEmpty) {
      result[key] = entry;
    }
  }
  return result.values.toList(growable: false);
}

_EntityCandidate? _candidateFromEntityIndex(Map<String, dynamic> entry) {
  final kind = _entityKindFromValue(entry['kind'] ?? entry['type']);
  final idValue = entry['id'];
  final id = idValue is num ? idValue.toInt() : int.tryParse('$idValue');
  final nameZh = entry['nameZh'] as String?;
  final nameEn = entry['nameEn'] as String? ?? '';
  if (kind == null || id == null || nameZh == null || nameZh.isEmpty) {
    return null;
  }
  return _EntityCandidate(
    kind: kind,
    id: id,
    nameZh: nameZh,
    nameEn: nameEn,
    slug: entry['slug'] as String? ?? _stableSlug(nameEn),
    aliasesZh: _stringList(entry['aliasesZh']),
    aliasesEn: _stringList(entry['aliasesEn']),
  );
}

_EntityCandidate _candidateFromMove(CachedMove entry) => _EntityCandidate(
  kind: AskTitoDexEntityKind.move,
  id: entry.id,
  nameZh: entry.nameZh,
  nameEn: entry.nameEn,
  slug: _stableSlug(entry.nameEn),
);

_EntityCandidate? _candidateFromItem(Map<String, dynamic> entry) {
  final idValue = entry['id'];
  final id = idValue is num ? idValue.toInt() : int.tryParse('$idValue');
  final nameZh = entry['nameZh'] as String?;
  if (id == null || nameZh == null || nameZh.isEmpty) return null;
  final nameEn = entry['nameEn'] as String? ?? '';
  return _EntityCandidate(
    kind: AskTitoDexEntityKind.item,
    id: id,
    nameZh: nameZh,
    nameEn: nameEn,
    slug: entry['slug'] as String? ?? _stableSlug(nameEn),
  );
}

AskTitoDexEntityKind? _entityKindFromValue(Object? value) => switch (value) {
  'pokemon' || 'species' => AskTitoDexEntityKind.pokemon,
  'move' || 'moves' => AskTitoDexEntityKind.move,
  'ability' || 'abilities' => AskTitoDexEntityKind.ability,
  'item' || 'items' => AskTitoDexEntityKind.item,
  _ => null,
};

List<String> _stringList(Object? value) => (value as List<dynamic>? ?? const [])
    .whereType<String>()
    .toList(growable: false);

String _stableSlug(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

bool _containsEnglishToken(String haystack, String needle) {
  final escaped = RegExp.escape(needle).replaceAll(r'\ ', r'[\s-]+');
  return RegExp('(?:^|[^a-z0-9])$escaped(?:[^a-z0-9]|\$)').hasMatch(haystack);
}

final askTitoDexEntityResolver = DexAskTitoDexEntityResolver();
