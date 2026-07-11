import 'dart:convert';

import 'package:http/http.dart' as http;

/// CDN configuration for the pre-built dex offline bundle.
class DexCdnConfig {
  const DexCdnConfig({http.Client? httpClient})
      : _httpClient = httpClient;

  final http.Client? _httpClient;

  static const String cdnBase = String.fromEnvironment(
    'TITODEX_DEX_CDN_BASE',
    defaultValue: 'https://dex.tito.cafe',
  );

  static const String bundleVersionPrefix = 'v3';

  static const String legacyBundleVersionPrefix = 'v2';

  static const String bundleUrl = String.fromEnvironment(
    'TITODEX_DEX_BUNDLE_URL',
    defaultValue: 'https://dex.tito.cafe/v3/bundle.tar.zst',
  );

  static const String legacyBundleUrl =
      'https://dex.tito.cafe/v2/bundle.tar.zst';

  static const int bundleVersion = int.fromEnvironment(
    'TITODEX_DEX_BUNDLE_VERSION',
    defaultValue: 5,
  );

  String get manifestUrl => '$cdnBase/bundle-manifest.json';

  String summariesUrl({String prefix = bundleVersionPrefix}) =>
      '$cdnBase/$prefix/summaries.json';

  String detailUrl(int id, {String prefix = bundleVersionPrefix}) =>
      '$cdnBase/$prefix/details/$id.json';

  String movesUrl({String prefix = bundleVersionPrefix}) =>
      '$cdnBase/$prefix/moves.json';

  String abilitiesUrl({String prefix = bundleVersionPrefix}) =>
      '$cdnBase/$prefix/abilities.json';

  String bundleArchiveUrl({String prefix = bundleVersionPrefix}) =>
      '$cdnBase/$prefix/bundle.tar.zst';

  String spriteUrl(int id, {String prefix = bundleVersionPrefix}) =>
      '$cdnBase/$prefix/sprites/$id.png';

  String artworkUrl(int id, {String prefix = bundleVersionPrefix}) =>
      '$cdnBase/$prefix/artwork/$id.png';

  String typeIconUrl(String type, {String prefix = legacyBundleVersionPrefix}) =>
      '$cdnBase/$prefix/type_icons/$type.png';

  DexBundleManifest fallbackManifest() => DexBundleManifest(
        bundleVersion: bundleVersion,
        archiveUrl: bundleUrl,
        archiveSha256: '',
        archiveSizeBytes: 0,
      );

  Future<DexBundleManifest> fetchManifest({http.Client? client}) async {
    final httpClient = client ?? _httpClient ?? http.Client();
    final ownsClient = client == null && _httpClient == null;
    try {
      final response = await httpClient.get(Uri.parse(manifestUrl));
      if (response.statusCode != 200) {
        throw DexCdnException(
          'Failed to fetch bundle manifest: HTTP ${response.statusCode}',
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return DexBundleManifest.fromJson(json);
    } finally {
      if (ownsClient) {
        httpClient.close();
      }
    }
  }
}

/// Remote bundle metadata published alongside the CDN archive.
class DexBundleManifest {
  const DexBundleManifest({
    required this.bundleVersion,
    required this.archiveUrl,
    required this.archiveSha256,
    required this.archiveSizeBytes,
    this.pokemonCount,
    this.publishedAt,
  });

  final int bundleVersion;
  final String archiveUrl;
  final String archiveSha256;
  final int archiveSizeBytes;
  final int? pokemonCount;
  final String? publishedAt;

  bool get hasIntegrityCheck => archiveSha256.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'bundleVersion': bundleVersion,
        'archiveUrl': archiveUrl,
        'archiveSha256': archiveSha256,
        'archiveSizeBytes': archiveSizeBytes,
        if (pokemonCount != null) 'pokemonCount': pokemonCount,
        if (publishedAt != null) 'publishedAt': publishedAt,
      };

  factory DexBundleManifest.fromJson(Map<String, dynamic> json) {
    return DexBundleManifest(
      bundleVersion: json['bundleVersion'] as int? ?? DexCdnConfig.bundleVersion,
      archiveUrl: json['archiveUrl'] as String? ?? DexCdnConfig.bundleUrl,
      archiveSha256: (json['archiveSha256'] as String? ?? '').toLowerCase(),
      archiveSizeBytes: json['archiveSizeBytes'] as int? ?? 0,
      pokemonCount: json['pokemonCount'] as int?,
      publishedAt: json['publishedAt'] as String?,
    );
  }
}

class DexCdnException implements Exception {
  DexCdnException(this.message);

  final String message;

  @override
  String toString() => 'DexCdnException: $message';
}
