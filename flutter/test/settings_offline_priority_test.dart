import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/pages/settings_page.dart';

DexCacheStatus _status({required bool complete, required int pokemonCount}) =>
    DexCacheStatus(
      manifest: DexCacheManifest(
        version: DexCacheManifest.currentVersion,
        complete: complete,
        preferOffline: true,
        pokemonCount: pokemonCount,
      ),
      sizeBytes: 0,
      isDownloading: false,
    );

void main() {
  test('settings categories map to stable secondary routes', () {
    expect(SettingsSection.overview.route, '/settings');
    expect(SettingsSection.profile.route, '/settings/profile');
    expect(SettingsSection.appearance.route, '/settings/appearance');
    expect(SettingsSection.data.route, '/settings/data');
    expect(SettingsSection.about.title, '关于与高级');
  });

  test(
    'offline download is prioritized only when the cache is known empty',
    () {
      expect(shouldPrioritizeOfflineData(null), isFalse);
      expect(
        shouldPrioritizeOfflineData(_status(complete: false, pokemonCount: 0)),
        isTrue,
      );
      expect(
        shouldPrioritizeOfflineData(_status(complete: false, pokemonCount: 12)),
        isFalse,
      );
      expect(
        shouldPrioritizeOfflineData(
          _status(complete: true, pokemonCount: 1025),
        ),
        isFalse,
      );
    },
  );
}
