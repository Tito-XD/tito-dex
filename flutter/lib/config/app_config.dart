import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../features/dex/dex_cache_store.dart';
import '../l10n/app_zh.dart';

/// Remote-updatable app configuration (sleep tools, feature flags, …).
class AppConfig {
  AppConfig._();

  static final AppConfig instance = AppConfig._();

  static const _assetPath = 'assets/config/app_config.json';

  int configVersion = 0;
  String sleepToolsTierAHint = AppZh.sleepToolsTierAHint;
  List<({String labelZh, String url})> sleepToolsLinks = _defaultSleepLinks;

  Future<void>? _loading;

  static const List<({String labelZh, String url})> _defaultSleepLinks = [
    (labelZh: AppZh.sleepToolsMain, url: 'https://nerolislab.com'),
    (labelZh: AppZh.sleepToolsGuides, url: 'https://nerolislab.com/guides/'),
    (labelZh: AppZh.sleepToolsDocs, url: 'https://docs.nerolislab.com'),
  ];

  Future<void> ensureLoaded() {
    return _loading ??= _load();
  }

  Future<void> reload() async {
    _loading = null;
    configVersion = 0;
    sleepToolsTierAHint = AppZh.sleepToolsTierAHint;
    sleepToolsLinks = _defaultSleepLinks;
    await ensureLoaded();
  }

  Future<void> _load() async {
    final jsonText = await _readConfigJson();
    if (jsonText == null) {
      return;
    }

    final json = jsonDecode(jsonText) as Map<String, dynamic>;
    configVersion = json['configVersion'] as int? ?? 0;

    final sleepTools = json['sleepTools'] as Map<String, dynamic>?;
    if (sleepTools == null) {
      return;
    }

    final hint = sleepTools['tierAHint'] as String?;
    if (hint != null && hint.isNotEmpty) {
      sleepToolsTierAHint = hint;
    }

    final linksRaw = sleepTools['links'] as List<dynamic>?;
    if (linksRaw == null || linksRaw.isEmpty) {
      return;
    }

    final parsed = <({String labelZh, String url})>[];
    for (final item in linksRaw) {
      if (item is! Map) {
        continue;
      }
      final label = item['labelZh'] as String? ?? '';
      final url = item['url'] as String? ?? '';
      if (label.isEmpty || url.isEmpty) {
        continue;
      }
      parsed.add((labelZh: label, url: url));
    }
    if (parsed.isNotEmpty) {
      sleepToolsLinks = parsed;
    }
  }

  Future<String?> _readConfigJson() async {
    if (!kIsWeb) {
      try {
        final paths = await DexCachePaths.resolve();
        final offlineFile = paths.appConfigFile;
        if (await offlineFile.exists()) {
          return offlineFile.readAsString();
        }
      } on Object {
        // path_provider unavailable — fall back to bundled assets.
      }
    }

    try {
      return await rootBundle.loadString(_assetPath);
    } on Object {
      return null;
    }
  }

  /// Test-only reset.
  void resetForTest() {
    configVersion = 0;
    sleepToolsTierAHint = AppZh.sleepToolsTierAHint;
    sleepToolsLinks = _defaultSleepLinks;
    _loading = null;
  }
}
