import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_cache_store.dart';
import 'package:titodex/features/dex/dex_cdn_config.dart';
import 'package:titodex/features/dex/dex_offline_service.dart';
import 'package:titodex/features/journey/ask_motion_images.dart';
import 'package:titodex/features/journey/ask_motion_theme.dart';
import 'package:titodex/widgets/ask_answer_motion_title.dart';

class _Cdn extends DexCdnConfig {
  int reads = 0;
  @override
  String referenceUrl(
    String filename, {
    String prefix = DexCdnConfig.bundleVersionPrefix,
  }) {
    reads++;
    return 'https://example.invalid/$prefix/$filename';
  }
}

class _DecodeImages extends AskMotionImages {
  final List<String> requested = [];
  bool fail = false;
  @override
  Future<ImageProvider> resolve(String resource) async {
    requested.add(resource);
    if (fail) throw const FileSystemException('unavailable');
    return const AssetImage('assets/type_icons/fire.png');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _Cdn cdn;
  late AskMotionImages images;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ask-motion-images-');
    cdn = _Cdn();
    images = AskMotionImages(
      offline: DexOfflineService(
        store: DexCacheStore(paths: DexCachePaths(directory)),
      ),
      cdn: cdn,
    );
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'installed bundle images take priority without a network lookup',
    () async {
      final file = File('${directory.path}/item-sprites/leftovers.png');
      await file.parent.create();
      await File('assets/ask_motion/leftovers.png').copy(file.path);
      final provider = await images.resolve('item-sprites/leftovers.png');
      expect(provider, isA<FileImage>());
      expect((provider as FileImage).file.path, file.path);
      expect(cdn.reads, 0);
    },
  );

  test(
    'Lite uses the same single-image CDN URL and Flutter cache identity',
    () async {
      final provider = await images.resolve('item-sprites/occa-berry.png');
      expect(
        provider,
        const NetworkImage(
          'https://example.invalid/v5/item-sprites/occa-berry.png',
        ),
      );
      expect(cdn.reads, 1);
    },
  );

  test(
    'starter props work before installing any bundle without a download',
    () async {
      for (final slug in AskMotionImages.fallbackSlugs) {
        expect(
          await images.resolve('item-sprites/$slug.png'),
          AssetImage('assets/ask_motion/$slug.png'),
        );
      }
      expect(cdn.reads, 0);
    },
  );

  test(
    'bundle installed later replaces the initial starter fallback',
    () async {
      expect(await images.resolve(AskMotionImages.ball), isA<AssetImage>());
      final file = File('${directory.path}/${AskMotionImages.ball}');
      await file.parent.create();
      await File('assets/ask_motion/poke-ball.png').copy(file.path);
      expect(await images.resolve(AskMotionImages.ball), isA<FileImage>());
      await file.delete();
      expect(await images.resolve(AskMotionImages.ball), isA<AssetImage>());
    },
  );

  test(
    'non-resource inputs cannot choose arbitrary URLs or local paths',
    () async {
      for (final value in [
        '../private.png',
        'item-sprites/../../private.png',
        'https://other.invalid/test.png',
      ]) {
        expect(
          await images.resolve(value),
          const AssetImage('assets/ask_motion/sonias-book.png'),
        );
      }
      expect(cdn.reads, 0);
    },
  );

  testWidgets(
    'preparation decodes only the chosen props and shared finish props',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      final repo = _DecodeImages();
      final selected = [
        'item-sprites/occa-berry.png',
        'item-sprites/sitrus-berry.png',
      ];
      final prepared = await tester.runAsync(
        () => repo.prepare(context, selected),
      );
      expect(prepared!.keys.toSet(), {
        ...selected,
        AskMotionImages.book,
        AskMotionImages.ball,
      });
      expect(repo.requested, hasLength(4));
      expect(prepared.values.every((p) => p is AssetImage), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unavailable exact artwork resolves to the neutral offline book',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      final repo = _DecodeImages()..fail = true;
      final prepared = await tester.runAsync(
        () => repo.prepare(context, ['item-sprites/occa-berry.png']),
      );
      expect(
        prepared!['item-sprites/occa-berry.png'],
        const AssetImage('assets/ask_motion/sonias-book.png'),
      );
      expect(
        prepared[AskMotionImages.ball],
        const AssetImage('assets/ask_motion/poke-ball.png'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending images keep text visible and old requests cannot replace new props',
    (tester) async {
      final first = Completer<Map<String, ImageProvider>>();
      final second = Completer<Map<String, ImageProvider>>();
      var reads = 0;
      Future<Map<String, ImageProvider>> prepare(
        BuildContext _,
        Iterable<String> resources,
      ) {
        reads++;
        return resources.first.contains('occa') ? first.future : second.future;
      }

      Widget host(
        String resource,
        String title, {
        AskMotionOutcome? outcome,
        bool reduced = false,
      }) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: AskAnswerMotionTitle(
                  text: title,
                  outcome: outcome,
                  theme: AskMotionTheme(
                    topic: 'berry',
                    kind: AskMotionKind.berry,
                    assets: [resource],
                  ),
                  prepareImages: prepare,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(host('item-sprites/occa-berry.png', '查询巧可果'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('查询巧可果'), findsOneWidget);
      expect(find.byKey(const ValueKey('ask-motion-berry-0')), findsNothing);
      await tester.pumpWidget(host('item-sprites/sitrus-berry.png', '查询文柚果'));
      first.complete({
        'item-sprites/occa-berry.png': const AssetImage(
          'assets/type_icons/fire.png',
        ),
      });
      await tester.pump();
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      second.complete({
        'item-sprites/sitrus-berry.png': const AssetImage(
          'assets/type_icons/water.png',
        ),
      });
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('ask-motion-berry-0')), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image).first).image,
        const AssetImage('assets/type_icons/water.png'),
      );
      await tester.pumpWidget(host('item-sprites/sitrus-berry.png', '核验文柚果'));
      expect(reads, 2, reason: 'Stage changes must reuse prepared images.');
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'neutral completion and disposal do not replay late image preparation',
    (tester) async {
      final ready = Completer<Map<String, ImageProvider>>();
      Widget host(AskMotionOutcome? outcome) => MaterialApp(
        home: Scaffold(
          body: AskAnswerMotionTitle(
            text: outcome == null ? '正在查询' : '请补充问题',
            theme: const AskMotionTheme(
              topic: 'berry',
              kind: AskMotionKind.berry,
              assets: ['item-sprites/occa-berry.png'],
            ),
            outcome: outcome,
            prepareImages: (_, _) => ready.future,
          ),
        ),
      );
      await tester.pumpWidget(host(null));
      await tester.pumpWidget(host(AskMotionOutcome.neutral));
      ready.complete({});
      await tester.pump();
      await tester.pump();
      expect(find.text('请补充问题'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
