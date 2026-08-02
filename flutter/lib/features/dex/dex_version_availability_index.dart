import 'dart:convert';

import 'package:flutter/services.dart';

import '../game/game_edition.dart';

typedef VersionAvailabilityAssetLoader = Future<String> Function();

/// Tiny APK-local lookup used by the Dex progress filters.
///
/// Detail pages still calculate a full chain-completion plan for the selected
/// family. The list only needs a species-id bucket, so shipping this ~27 KB
/// JSON avoids opening many detail files or making per-species network calls.
class DexVersionAvailabilityIndex {
  DexVersionAvailabilityIndex({VersionAvailabilityAssetLoader? loadAsset})
    : _loadAsset = loadAsset ?? _loadBundledAsset;

  static const assetPath = 'assets/config/version_availability_index.json';

  final VersionAvailabilityAssetLoader _loadAsset;
  Future<Map<String, Set<int>>>? _bySelectionFuture;

  Future<Set<int>> idsForEdition(GameEdition edition) async {
    final selection =
        edition.selectedFlavor ?? '@${edition.dataVersionGroupKey}';
    final bySelection = await (_bySelectionFuture ??= _load());
    return bySelection[selection] ?? const {};
  }

  Future<Map<String, Set<int>>> _load() async {
    final source = await _loadAsset();
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return decodeSelections(decoded);
  }

  static Map<String, Set<int>> decodeSelections(Map<String, dynamic> json) {
    final raw = json['bySelection'];
    if (raw is! Map) {
      return const {};
    }
    return {
      for (final entry in raw.entries)
        entry.key.toString(): {
          for (final value in entry.value as List<dynamic>)
            if (value is num) value.toInt(),
        },
    };
  }

  static Future<String> _loadBundledAsset() => rootBundle.loadString(assetPath);
}
