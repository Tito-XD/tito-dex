import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_cdn_config.dart';

void main() {
  group('DexBundleManifest', () {
    test('fromJson parses live CDN manifest shape', () {
      final manifest = DexBundleManifest.fromJson({
        'bundleVersion': 2,
        'pokemonCount': 493,
        'archiveUrl': 'https://dex.tito.cafe/v2/bundle.tar.zst',
        'archiveSha256':
            '62B98E263C45B398FC157545D427FA2D279EE1445F1DB8A1BCD8A2AF4BADD8D7',
        'archiveSizeBytes': 3749451,
        'publishedAt': '2026-07-09T14:54:52+00:00',
      });

      expect(manifest.bundleVersion, 2);
      expect(manifest.pokemonCount, 493);
      expect(manifest.archiveUrl, 'https://dex.tito.cafe/v2/bundle.tar.zst');
      expect(
        manifest.archiveSha256,
        '62b98e263c45b398fc157545d427fa2d279ee1445f1db8a1bcd8a2af4badd8d7',
      );
      expect(manifest.archiveSizeBytes, 3749451);
      expect(manifest.publishedAt, '2026-07-09T14:54:52+00:00');
      expect(manifest.hasIntegrityCheck, isTrue);
    });

    test('fromJson applies config defaults for missing fields', () {
      final manifest = DexBundleManifest.fromJson({});

      expect(manifest.bundleVersion, DexCdnConfig.bundleVersion);
      expect(manifest.archiveUrl, DexCdnConfig.bundleUrl);
      expect(manifest.archiveSha256, isEmpty);
      expect(manifest.archiveSizeBytes, 0);
      expect(manifest.hasIntegrityCheck, isFalse);
    });

    test('toJson round-trips core fields', () {
      const manifest = DexBundleManifest(
        bundleVersion: 2,
        archiveUrl: 'https://dex.tito.cafe/v2/bundle.tar.zst',
        archiveSha256: 'abc123',
        archiveSizeBytes: 100,
        pokemonCount: 493,
        publishedAt: '2026-07-09T14:54:52+00:00',
      );

      final json = manifest.toJson();
      final restored = DexBundleManifest.fromJson(json);

      expect(restored.bundleVersion, manifest.bundleVersion);
      expect(restored.archiveUrl, manifest.archiveUrl);
      expect(restored.archiveSha256, manifest.archiveSha256);
      expect(restored.archiveSizeBytes, manifest.archiveSizeBytes);
      expect(restored.pokemonCount, manifest.pokemonCount);
      expect(restored.publishedAt, manifest.publishedAt);
    });
  });

  group('DexCdnConfig', () {
    test('manifestUrl and spriteUrl use CDN base', () {
      const config = DexCdnConfig();

      expect(
        config.manifestUrl,
        '${DexCdnConfig.cdnBase}/bundle-manifest.json',
      );
      expect(config.spriteUrl(25), '${DexCdnConfig.cdnBase}/v2/sprites/25.png');
      expect(config.artworkUrl(25), '${DexCdnConfig.cdnBase}/v2/artwork/25.png');
      expect(
        config.typeIconUrl('fire'),
        '${DexCdnConfig.cdnBase}/v2/type_icons/fire.png',
      );
    });

    test('fallbackManifest uses compile-time defaults', () {
      const config = DexCdnConfig();
      final fallback = config.fallbackManifest();

      expect(fallback.bundleVersion, DexCdnConfig.bundleVersion);
      expect(fallback.archiveUrl, DexCdnConfig.bundleUrl);
    });
  });
}
