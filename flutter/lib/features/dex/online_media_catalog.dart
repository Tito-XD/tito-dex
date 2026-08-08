import 'package:flutter/foundation.dart';

import 'dex_repository.dart';
import 'sprite_generation_catalog.dart';

/// One cry audio (title like `0025_cry.opus`, `0025GM_cry.opus`, ...).
@immutable
class OnlineCry {
  const OnlineCry({
    required this.title,
    required this.url,
    this.formKeys = const [],
    this.formCode,
    this.mappingStatus = 'unresolved',
    this.isFormSpecific = false,
    this.fallbackForAllForms = false,
    this.source,
  });

  factory OnlineCry.fromJson(Map<String, dynamic> json) => OnlineCry(
    title: json['title'] as String? ?? '',
    url: json['url'] as String? ?? '',
    formKeys: [
      for (final key in json['formKeys'] as List<dynamic>? ?? const [])
        if (key is String && key.isNotEmpty) key,
    ],
    formCode: json['formCode'] as String?,
    mappingStatus: json['mappingStatus'] as String? ?? 'unresolved',
    isFormSpecific: json['isFormSpecific'] as bool? ?? false,
    fallbackForAllForms: json['fallbackForAllForms'] as bool? ?? false,
    source: json['source'] as String?,
  );

  final String title;
  final String url;
  final List<String> formKeys;
  final String? formCode;
  final String mappingStatus;
  final bool isFormSpecific;
  final bool fallbackForAllForms;
  final String? source;

  /// Standard species cry: `NNNN_cry.opus` with no forme/gimmick suffix.
  bool get isStandard => RegExp(r'^\d+_cry\.(?:opus|ogg)$').hasMatch(title);

  String get suffix {
    final stem = title.split('_cry').first;
    return stem.replaceFirst(RegExp(r'^\d+'), '');
  }

  bool matchesForm(String formKey) => formKeys.contains(formKey);

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
  const OnlineFormArt({
    required this.file,
    required this.kind,
    this.formKeys = const [],
    this.formCode,
    this.mappingStatus = 'unresolved',
    this.url,
    this.source,
    this.license,
    this.mediaType = 'static',
    this.isShiny = false,
    this.urlVerified = false,
  });

  factory OnlineFormArt.fromJson(Map<String, dynamic> json) => OnlineFormArt(
    file: json['file'] as String? ?? '',
    kind: json['kind'] as String? ?? 'forme',
    formKeys: [
      for (final key in json['formKeys'] as List<dynamic>? ?? const [])
        if (key is String && key.isNotEmpty) key,
    ],
    formCode: json['formCode'] as String?,
    mappingStatus: json['mappingStatus'] as String? ?? 'unresolved',
    url: json['url'] as String?,
    source: json['source'] as String?,
    license: json['license'] as String?,
    mediaType: json['mediaType'] as String? ?? 'static',
    isShiny: json['isShiny'] as bool? ?? false,
    urlVerified: json['urlVerified'] as bool? ?? false,
  );

  final String file;
  final String kind;
  final List<String> formKeys;
  final String? formCode;
  final String mappingStatus;
  final String? url;
  final String? source;
  final String? license;
  final String mediaType;
  final bool isShiny;
  final bool urlVerified;

  /// Only imageinfo-resolved URLs that also passed an HTTP content check are
  /// eligible. A catalog filename alone is never converted into a guessed URL.
  bool get isAvailable =>
      urlVerified && url != null && url!.isNotEmpty && mediaType == 'static';

  bool matchesForm(String formKey) => formKeys.contains(formKey);
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

  /// Best cry for the species: an explicitly mapped form cry first, then the
  /// catalog's declared all-form fallback / standard cry. Filename substring
  /// guessing is intentionally not used because compact codes overlap.
  String? bestCryUrl({String? formKey}) {
    if (formKey != null) {
      for (final cry in cries) {
        if (cry.url.isNotEmpty && cry.matchesForm(formKey)) {
          return cry.url;
        }
      }
    }
    for (final cry in cries) {
      if (cry.url.isNotEmpty && (cry.fallbackForAllForms || cry.isStandard)) {
        return cry.url;
      }
    }
    for (final cry in cries) {
      if (cry.url.isNotEmpty) return cry.url;
    }
    return null;
  }

  /// Verified static candidates for [formKey], exact mappings first and a
  /// documented shared upstream fallback last (for example ride-mode art).
  List<String> artCandidatesFor(String? formKey, {bool shiny = false}) {
    if (formKey == null) return const [];
    final matching =
        [
          for (final art in forms)
            if (art.isAvailable &&
                art.isShiny == shiny &&
                art.matchesForm(formKey))
              art,
        ]..sort((a, b) {
          final mapping = _artRank(a).compareTo(_artRank(b));
          if (mapping != 0) return mapping;
          return a.file.compareTo(b.file);
        });
    return [for (final art in matching) art.url!];
  }

  static int _artRank(OnlineFormArt art) {
    final mappingRank = art.mappingStatus == 'exact'
        ? 0
        : art.mappingStatus == 'shared'
        ? 2
        : 4;
    final kindRank = art.kind == 'HOME' ? 0 : 1;
    return mappingRank + kindRank;
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

  /// Discard a possibly stale/failed lazy result and read the active bundle
  /// again. A transient network or bundle-install failure must not leave the
  /// resource manager empty until the process is restarted.
  Future<Map<int, OnlineMediaEntry>> reload() {
    _future = null;
    return load();
  }

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
