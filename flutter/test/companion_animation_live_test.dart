import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/companion/companion_animation_catalog.dart';
import 'package:titodex/features/companion/companion_media.dart';

class _RealHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'live selected GIFs validate and reopen from disk with network disabled',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final catalog = await CompanionAnimationCatalog.load();
        final assets = [
          catalog.forForm(162).singleWhere((a) => a.source == 'shinyhunters'),
          catalog
              .forForm(162, shiny: true)
              .singleWhere((a) => a.source == 'shinyhunters'),
          catalog.forForm(155).singleWhere((a) => a.source == 'usum-hd'),
        ];
        final directory = await Directory.systemTemp.createTemp(
          'titodex-live-animation-',
        );
        try {
          final cache = CompanionMediaCache(
            cacheDirectory: () async => directory,
          );
          for (final asset in assets) {
            final path = await cache.ensureAnimation(asset);
            expect(path, isNotNull, reason: asset.url);
            expect(await File(path!).length(), asset.sizeBytes);
            final offline = CompanionMediaCache(
              cacheDirectory: () async => directory,
              clientFactory: () =>
                  throw StateError('Network disabled for offline recheck'),
            );
            expect(await offline.ensureAnimation(asset), path);
          }
        } finally {
          await directory.delete(recursive: true);
        }
      }, _RealHttp());
    },
    skip: Platform.environment['TITODEX_LIVE_MEDIA_TEST'] != '1',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
