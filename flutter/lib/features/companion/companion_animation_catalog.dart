import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_locale.dart';
import '../../l10n/app_zh.dart';
import '../dex/sprite_generation_catalog.dart';

/// A single exact-form, exact-colour online candidate. A valid index entry is
/// not a downloaded animation: the cache validates its bytes before adoption.
class CompanionAnimationAsset {
  const CompanionAnimationAsset({
    required this.id,
    required this.speciesId,
    required this.formKey,
    required this.isDefault,
    required this.source,
    required this.shiny,
    required this.url,
    required this.width,
    required this.height,
    required this.sizeBytes,
    this.generation = spriteGenerationUniversal,
    this.labelZh = '',
    this.labelEn = '',
    this.frameCount,
    this.nameZh = '',
    this.nameEn = '',
  });

  final String id;
  final int speciesId;
  final String formKey;
  final bool isDefault;
  final String source;
  final bool shiny;
  final String url;
  final int width;
  final int height;
  final int sizeBytes;
  final int generation;
  final String labelZh;
  final String labelEn;
  final int? frameCount;
  final String nameZh;
  final String nameEn;

  String get displayName {
    final name = AppLocale.instance.isEnglish ? nameEn : nameZh;
    return name.isEmpty ? '#$speciesId' : name;
  }

  bool matches(int species, String? form, bool isShiny) =>
      speciesId == species &&
      shiny == isShiny &&
      (form == null ? isDefault : form == formKey);

  String get label {
    final group = generation == spriteGenerationUniversal
        ? AppZh.companionAnimationUniversal
        : generationRomanLabel(generation);
    return '$group · ${AppLocale.instance.isEnglish ? labelEn : labelZh}';
  }

  String get dimensionsLabel => '$width×$height';

  String get sizeLabel => sizeBytes >= 1024 * 1024
      ? '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MiB'
      : '${(sizeBytes / 1024).toStringAsFixed(0)} KiB';

  /// Includes identity, URL and audited content size. Never shares the legacy
  /// numeric-ID cache or another form/colour/source's download.
  String get cacheFileName {
    final revision = sha256
        .convert(utf8.encode('$id|$url|$sizeBytes|$width|$height'))
        .toString()
        .substring(0, 24);
    return '$speciesId.animation-$revision.gif';
  }
}

class CompanionAnimationCatalog {
  CompanionAnimationCatalog(Iterable<CompanionAnimationAsset> assets)
    : _byId = {for (final asset in assets) asset.id: asset} {
    for (final asset in _byId.values) {
      (_bySpecies[asset.speciesId] ??= []).add(asset);
    }
  }

  factory CompanionAnimationCatalog.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported companion catalog');
    }
    final sources = json['sources'] as Map<String, dynamic>;
    final assets = <CompanionAnimationAsset>[];
    final ids = <String>{};
    for (final raw in json['entries'] as List<dynamic>) {
      final row = raw as Map<String, dynamic>;
      final source = sources[row['source']] as Map<String, dynamic>;
      final url = row['url'] as String;
      final uri = Uri.parse(url);
      if (uri.scheme != 'https' ||
          uri.host.isEmpty ||
          !ids.add(row['id'] as String) ||
          (row['width'] as int) <= 0 ||
          (row['height'] as int) <= 0 ||
          (row['sizeBytes'] as int) <= 0) {
        throw const FormatException('Invalid companion animation entry');
      }
      assets.add(
        CompanionAnimationAsset(
          id: row['id'] as String,
          speciesId: row['speciesId'] as int,
          formKey: row['formKey'] as String,
          isDefault: row['isDefault'] as bool,
          source: row['source'] as String,
          shiny: row['shiny'] as bool,
          url: url,
          width: row['width'] as int,
          height: row['height'] as int,
          sizeBytes: row['sizeBytes'] as int,
          frameCount: row['frameCount'] as int?,
          nameZh: row['nameZh'] as String? ?? '',
          nameEn: row['nameEn'] as String? ?? '',
          generation: source['generation'] as int,
          labelZh: source['labelZh'] as String,
          labelEn: source['labelEn'] as String,
        ),
      );
    }
    return CompanionAnimationCatalog(assets);
  }

  static const assetPath = 'assets/data/companion_animation_catalog.json';
  static Future<CompanionAnimationCatalog>? _pending;
  final Map<String, CompanionAnimationAsset> _byId;
  final _bySpecies = <int, List<CompanionAnimationAsset>>{};

  static Future<CompanionAnimationCatalog> load() => _pending ??= _read();

  static Future<CompanionAnimationCatalog> _read() async {
    try {
      final text = await rootBundle.loadString(assetPath);
      return CompanionAnimationCatalog.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
      );
    } catch (_) {
      _pending = null;
      rethrow;
    }
  }

  Iterable<CompanionAnimationAsset> get assets => _byId.values;

  CompanionAnimationAsset? entry(String? id) => _byId[id];

  List<CompanionAnimationAsset> forForm(
    int speciesId, {
    String? formKey,
    bool shiny = false,
  }) =>
      (_bySpecies[speciesId] ?? const <CompanionAnimationAsset>[])
          .where((asset) => asset.matches(speciesId, formKey, shiny))
          .toList()
        ..sort((a, b) {
          final order = a.generation.compareTo(b.generation);
          return order == 0 ? a.id.compareTo(b.id) : order;
        });
}
