import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_cdn_config.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_update_service.dart';

void main() {
  group('DexUpdateService.compareManifests', () {
    test('detects full update when remote bundleVersion is newer', () {
      const remote = DexBundleManifest(
        bundleVersion: 6,
        archiveUrl: 'https://dex.tito.cafe/v3/bundle.tar.zst',
        archiveSha256: '',
        archiveSizeBytes: 0,
        l10nVersion: '2026-07-13T00:00:00Z',
        configVersion: 1,
      );
      const local = DexCacheManifest(
        version: 5,
        complete: true,
        preferOffline: true,
        l10nVersion: '2026-07-13T00:00:00Z',
        configVersion: 1,
      );

      expect(
        DexUpdateService.compareManifests(remote: remote, local: local),
        DexUpdateKind.full,
      );
    });

    test('detects l10nOnly when l10nVersion differs', () {
      const remote = DexBundleManifest(
        bundleVersion: 5,
        archiveUrl: 'https://dex.tito.cafe/v3/bundle.tar.zst',
        archiveSha256: '',
        archiveSizeBytes: 0,
        l10nVersion: '2026-07-14T00:00:00Z',
        configVersion: 1,
      );
      const local = DexCacheManifest(
        version: 5,
        complete: true,
        preferOffline: true,
        l10nVersion: '2026-07-13T00:00:00Z',
        configVersion: 1,
      );

      expect(
        DexUpdateService.compareManifests(remote: remote, local: local),
        DexUpdateKind.l10nOnly,
      );
    });

    test('detects l10nOnly when configVersion differs', () {
      const remote = DexBundleManifest(
        bundleVersion: 5,
        archiveUrl: 'https://dex.tito.cafe/v3/bundle.tar.zst',
        archiveSha256: '',
        archiveSizeBytes: 0,
        l10nVersion: '2026-07-13T00:00:00Z',
        configVersion: 2,
      );
      const local = DexCacheManifest(
        version: 5,
        complete: true,
        preferOffline: true,
        l10nVersion: '2026-07-13T00:00:00Z',
        configVersion: 1,
      );

      expect(
        DexUpdateService.compareManifests(remote: remote, local: local),
        DexUpdateKind.l10nOnly,
      );
    });

    test('no update when versions match', () {
      const remote = DexBundleManifest(
        bundleVersion: 5,
        archiveUrl: 'https://dex.tito.cafe/v3/bundle.tar.zst',
        archiveSha256: '',
        archiveSizeBytes: 0,
        l10nVersion: '2026-07-13T00:00:00Z',
        configVersion: 1,
      );
      const local = DexCacheManifest(
        version: 5,
        complete: true,
        preferOffline: true,
        l10nVersion: '2026-07-13T00:00:00Z',
        configVersion: 1,
      );

      expect(
        DexUpdateService.compareManifests(remote: remote, local: local),
        isNull,
      );
    });
  });

  group('DexCdnConfig l10n URLs', () {
    test('l10nFileUrl points to v3/l10n/zh/', () {
      const config = DexCdnConfig();
      expect(
        config.l10nFileUrl('location_area_labels.json'),
        '${DexCdnConfig.cdnBase}/v3/l10n/zh/location_area_labels.json',
      );
      expect(
        config.mapFileUrl('hgss_map_list.json'),
        '${DexCdnConfig.cdnBase}/v3/maps/hgss_map_list.json',
      );
      expect(
        config.configFileUrl('app_config.json'),
        '${DexCdnConfig.cdnBase}/v3/config/app_config.json',
      );
    });
  });
}
