import 'package:flutter/foundation.dart';

import 'dex_repository.dart';
import 'sprite_generation_catalog.dart';

/// One cry audio (title like `0025_cry.opus`, `0025GM_cry.opus`, ...).
@immutable
class OnlineCry {
  const OnlineCry({required this.title, required this.url});

  factory OnlineCry.fromJson(Map<String, dynamic> json) => OnlineCry(
    title: json['title'] as String? ?? '',
    url: json['url'] as String? ?? '',
  );

  final String title;
  final String url;

  /// Standard species cry: `NNNN_cry.opus` with no forme/gimmick suffix.
  bool get isStandard => RegExp(r'^\d+_cry\.(?:opus|ogg)$').hasMatch(title);

  String get suffix {
    final stem = title.split('_cry').first;
    return stem.replaceFirst(RegExp(r'^\d+'), '');
  }

  /// Compact Chinese label for the selector. Unknown suffixes stay visible
  /// instead of being guessed, so newly added 52poke forms remain selectable.
  String get labelZh {
    if (isStandard) return '标准叫声';
    const labels = <String, String>{
      'M': '超级进化',
      'MX': '超级进化 X',
      'MY': '超级进化 Y',
      'MZ': '超级进化 Z',
      'GM': '超极巨化',
      'DM': '极巨化',
      'O': '初始帽子',
      'P': '原始回归',
      'S': '天空形态',
      'T': '灵兽形态',
      'B': '暗黑酋雷姆',
      'W': '焰白酋雷姆',
      'C': '完全体形态',
      'U': '解放形态',
      'D': '黄昏形态',
      'DW': '究极奈克洛兹玛',
      'L': '低调形态',
      'NF': '结冻头形态',
      'F': '雌性',
      'HM': '满腹花纹',
      'R': '连击流',
      'I': '骑白马形态',
      'H': '英雄形态',
    };
    return labels[suffix] ?? '形态 $suffix';
  }
}

/// Forme / HOME artwork file reference (resolved to a URL by the viewer).
@immutable
class OnlineFormArt {
  const OnlineFormArt({required this.file, required this.kind});

  factory OnlineFormArt.fromJson(Map<String, dynamic> json) => OnlineFormArt(
    file: json['file'] as String? ?? '',
    kind: json['kind'] as String? ?? 'forme',
  );

  final String file;
  final String kind;
}

/// Per-species online media (cries + forme art) from the 52poke catalog.
@immutable
class OnlineMediaEntry {
  const OnlineMediaEntry({
    required this.id,
    required this.nameZh,
    required this.cries,
    required this.forms,
  });

  factory OnlineMediaEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    return OnlineMediaEntry(
      id: id is int ? id : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      nameZh: json['nameZh'] as String? ?? '',
      cries: [
        for (final cry in json['cries'] as List<dynamic>? ?? const [])
          if (cry is Map<String, dynamic>) OnlineCry.fromJson(cry),
      ],
      forms: [
        for (final form in json['forms'] as List<dynamic>? ?? const [])
          if (form is Map<String, dynamic>) OnlineFormArt.fromJson(form),
      ],
    );
  }

  final int id;
  final String nameZh;
  final List<OnlineCry> cries;
  final List<OnlineFormArt> forms;

  /// Best cry for the species: forme-specific when [formKey] matches a cry
  /// title token, otherwise the standard `NNNN_cry.opus` (or first cry).
  String? bestCryUrl({String? formKey}) {
    final tokens = <String>[];
    if (formKey != null) {
      final raw = formKey.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (raw.isNotEmpty) {
        tokens.add(raw);
      }
      final lower = formKey.toLowerCase();
      if (lower.contains('gmax') || lower.contains('gigantamax')) {
        tokens.add('GM');
      }
      if (lower.contains('dmax') || lower.contains('dynamax')) {
        tokens.add('DM');
      }
      if (lower.contains('mega')) {
        if (lower.contains('x')) {
          tokens.add('MX');
        }
        if (lower.contains('y')) {
          tokens.add('MY');
        }
      }
      if (lower.contains('cap') || lower.contains('original')) {
        tokens.add('O');
      }
      const namedFormTokens = <String, String>{
        'primal': 'P',
        'sky': 'S',
        'therian': 'T',
        'black': 'B',
        'white': 'W',
        'complete': 'C',
        'unbound': 'U',
        'dusk': 'D',
        'ultra': 'DW',
        'low-key': 'L',
        'noice': 'NF',
        'female': 'F',
        'hangry': 'HM',
        'rapid-strike': 'R',
        'ice-rider': 'I',
        'hero': 'H',
        'limited-build': 'L',
        'low-power-mode': 'L',
      };
      for (final entry in namedFormTokens.entries) {
        if (lower.contains(entry.key)) {
          tokens.add(entry.value);
        }
      }
    }
    for (final token in tokens) {
      for (final cry in cries) {
        if (cry.title.toUpperCase().contains(token)) {
          return cry.url;
        }
      }
    }
    for (final cry in cries) {
      if (cry.isStandard) {
        return cry.url;
      }
    }
    return cries.isEmpty ? null : cries.first.url;
  }
}

/// Lazy loader for `media_catalog_52poke.json` through the dex reference
/// layer. The file is an id-keyed object (items.json style); it ships with
/// the bundle from v18 and is also served as a loose CDN object. Until a
/// bundle with the catalog exists the load degrades to an empty map, which
/// keeps every existing caller on the old CDN/PokeAPI candidates.
class OnlineMediaCatalog {
  Future<Map<int, OnlineMediaEntry>>? _future;

  Future<Map<int, OnlineMediaEntry>> load() => _future ??= _load();

  Future<Map<int, OnlineMediaEntry>> _load() async {
    try {
      final entries = await dexRepository.getReferenceEntries(
        'media_catalog_52poke.json',
      );
      final result = <int, OnlineMediaEntry>{};
      for (final entry in entries) {
        final parsed = OnlineMediaEntry.fromJson(entry);
        if (parsed.id > 0) {
          result[parsed.id] = parsed;
        }
      }
      return result;
    } catch (_) {
      return const {};
    }
  }

  Future<OnlineMediaEntry?> entryFor(int speciesId) async {
    final catalog = await load();
    return catalog[speciesId];
  }
}

final onlineMediaCatalog = OnlineMediaCatalog();

/// Cry candidates for a species/form: 52poke catalog best first, then the
/// existing CDN + PokeAPI latest cries.
List<String> cryCandidatesForMedia(
  int speciesId,
  OnlineMediaEntry? entry, {
  String? formKey,
}) {
  final best = entry?.bestCryUrl(formKey: formKey);
  return [if (best != null) best, ...cryCandidatesFor(speciesId)];
}
