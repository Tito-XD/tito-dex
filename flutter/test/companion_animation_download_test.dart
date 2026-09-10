import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:titodex/features/companion/companion_media.dart';

import 'fixtures/companion_animation_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'companion-download-test-',
    );
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'explicit source bypasses old numeric cache and remains available offline',
    () async {
      final old = File('${directory.path}/162.gif');
      await old.writeAsBytes([1, 2, 3]);
      var requests = 0;
      final cache = CompanionMediaCache(
        cacheDirectory: () async => directory,
        clientFactory: () => MockClient((request) async {
          requests++;
          return http.Response.bytes(twoFrameGif, 200);
        }),
      );
      final first = animationFixture();
      final second = animationFixture(
        id: 'source-b',
        url: 'https://example.test/b.gif',
      );
      final firstPath = await cache.ensureAnimation(first);
      final secondPath = await cache.ensureAnimation(second);
      expect(requests, 2);
      expect(firstPath, isNotNull);
      expect(firstPath, isNot(old.path));
      expect(secondPath, isNot(firstPath));
      expect(await old.readAsBytes(), [1, 2, 3]);
      expect(await cache.ensureAnimation(first), firstPath);
      expect(requests, 2);
      final offline = CompanionMediaCache(
        cacheDirectory: () async => directory,
        clientFactory: () => throw StateError('offline'),
      );
      expect(await offline.ensureAnimation(second), secondPath);
      await offline.deleteCached(second.cacheFileName);
      expect(await offline.cachedAnimationPath(second), isNull);
    },
  );

  test(
    'rejects static, wrong-size and truncated data without leaving cache files',
    () async {
      final cases = [
        oneFrameGif,
        Uint8List.fromList([60, 104, 116, 109, 108, 62]),
        Uint8List.sublistView(twoFrameGif, 0, twoFrameGif.length - 1),
      ];
      for (final bytes in cases) {
        final asset = animationFixture(sizeBytes: bytes.length);
        final cache = CompanionMediaCache(
          cacheDirectory: () async => directory,
          clientFactory: () =>
              MockClient((_) async => http.Response.bytes(bytes, 200)),
        );
        expect(await cache.ensureAnimation(asset), isNull);
        expect(await directory.list().toList(), isEmpty);
      }
      final cache = CompanionMediaCache(
        cacheDirectory: () async => directory,
        clientFactory: () =>
            MockClient((_) async => http.Response.bytes(twoFrameGif, 200)),
      );
      expect(
        await cache.ensureAnimation(animationFixture(sizeBytes: 999)),
        isNull,
      );
      expect(await directory.list().toList(), isEmpty);
    },
  );

  test('failed explicit source never requests a fallback', () async {
    final urls = <String>[];
    final cache = CompanionMediaCache(
      cacheDirectory: () async => directory,
      clientFactory: () => MockClient((request) async {
        urls.add(request.url.toString());
        return http.Response('not found', 404);
      }),
    );
    expect(await cache.ensureAnimation(animationFixture()), isNull);
    expect(urls, ['https://example.test/a.gif']);
  });

  test(
    'cancellation before and during a request cannot commit the file',
    () async {
      final response = Completer<http.Response>();
      final started = Completer<void>();
      final cache = CompanionMediaCache(
        cacheDirectory: () async => directory,
        clientFactory: () => MockClient((_) {
          started.complete();
          return response.future;
        }),
      );
      final early = CompanionDownloadCancellation()..cancel();
      expect(
        await cache.ensureAnimation(animationFixture(), cancellation: early),
        isNull,
      );
      final cancellation = CompanionDownloadCancellation();
      final download = cache.ensureAnimation(
        animationFixture(),
        cancellation: cancellation,
      );
      await started.future;
      cancellation.cancel();
      response.complete(http.Response.bytes(twoFrameGif, 200));
      expect(await download, isNull);
      expect(await directory.list().toList(), isEmpty);
    },
  );

  test('validator decodes multiple frames, not just a GIF header', () async {
    expect(
      await validateCompanionAnimation(twoFrameGif, animationFixture()),
      isTrue,
    );
    expect(
      await validateCompanionAnimation(
        oneFrameGif,
        animationFixture(sizeBytes: oneFrameGif.length),
      ),
      isFalse,
    );
  });
}
