import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../features/dex/dex_cache_store.dart';

/// Runtime lookup for Chinese labels from offline bundle or bundled APK assets.
class ZhCatalog {
  ZhCatalog._();

  static final ZhCatalog instance = ZhCatalog._();

  Map<String, String>? _locationAreaLabels;
  Map<String, String>? _hgssMapLabels;
  Future<void>? _loading;

  Future<void> ensureLoaded() {
    return _loading ??= _load();
  }

  Future<void> reload() async {
    _locationAreaLabels = null;
    _hgssMapLabels = null;
    _loading = null;
    await ensureLoaded();
  }

  Future<void> _load() async {
    final locationJson = await _readL10nJson('location_area_labels.json');
    if (locationJson != null) {
      final locationRaw = jsonDecode(locationJson) as Map<String, dynamic>;
      _locationAreaLabels = locationRaw.map(
        (key, value) => MapEntry(key, value as String),
      );
    } else {
      _locationAreaLabels = const {};
    }

    final hgssJson = await _readL10nJson('hgss_map_labels.json');
    if (hgssJson != null) {
      final hgssRaw = jsonDecode(hgssJson) as Map<String, dynamic>;
      _hgssMapLabels = hgssRaw.map(
        (key, value) => MapEntry(key, value as String),
      );
    } else {
      _hgssMapLabels = const {};
    }
  }

  Future<String?> _readL10nJson(String filename) async {
    if (!kIsWeb) {
      try {
        final paths = await DexCachePaths.resolve();
        final offlineFile = paths.l10nFile(filename);
        if (await offlineFile.exists()) {
          return offlineFile.readAsString();
        }
      } on Object {
        // Fall back to bundled assets.
      }
    }

    try {
      return await rootBundle.loadString('assets/l10n/zh/$filename');
    } on Object {
      return null;
    }
  }

  String? locationAreaLabel(String slug) => _locationAreaLabels?[slug];

  String? hgssMapLabel(String mapId) => _hgssMapLabels?[mapId];

  /// Test-only reset.
  void resetForTest() {
    _locationAreaLabels = null;
    _hgssMapLabels = null;
    _loading = null;
  }
}

/// Sync lookup after [ZhCatalog.ensureLoaded]; falls back to null.
String? zhCatalogLocationAreaLabel(String slug) {
  return ZhCatalog.instance.locationAreaLabel(slug);
}

String? zhCatalogHgssMapLabel(String mapId) {
  return ZhCatalog.instance.hgssMapLabel(mapId);
}
