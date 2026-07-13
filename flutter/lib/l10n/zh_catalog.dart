import 'dart:convert';

import 'package:flutter/services.dart';

/// Runtime lookup for Chinese labels from bundled zh catalog assets.
class ZhCatalog {
  ZhCatalog._();

  static final ZhCatalog instance = ZhCatalog._();

  Map<String, String>? _locationAreaLabels;
  Map<String, String>? _hgssMapLabels;
  Future<void>? _loading;

  Future<void> ensureLoaded() {
    return _loading ??= _load();
  }

  Future<void> _load() async {
    final locationJson = await rootBundle.loadString(
      'assets/l10n/zh/location_area_labels.json',
    );
    final locationRaw = jsonDecode(locationJson) as Map<String, dynamic>;
    _locationAreaLabels = locationRaw.map(
      (key, value) => MapEntry(key, value as String),
    );

    try {
      final hgssJson = await rootBundle.loadString(
        'assets/l10n/zh/hgss_map_labels.json',
      );
      final hgssRaw = jsonDecode(hgssJson) as Map<String, dynamic>;
      _hgssMapLabels = hgssRaw.map(
        (key, value) => MapEntry(key, value as String),
      );
    } catch (_) {
      _hgssMapLabels = const {};
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
