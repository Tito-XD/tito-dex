import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/companion/companion_animation_catalog.dart';
import 'package:titodex/features/companion/companion_media.dart';
import 'package:titodex/features/companion/companion_repository.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/widgets/companion_picker_sheet.dart';
import 'package:titodex/widgets/fallback_sprite_image.dart';

import 'fixtures/companion_animation_fixtures.dart';

class _PickerCache extends CompanionMediaCache {
  final pending = <Completer<String?>>[];
  CompanionDownloadCancellation? cancellation;
  String? ready;
  @override
  Future<List<CachedMediaFile>> listCached() async => [];
  @override
  Future<String?> cachedAnimationPath(CompanionAnimationAsset asset) async =>
      ready;
  @override
  Future<String?> ensureAnimation(
    CompanionAnimationAsset asset, {
    CompanionDownloadCancellation? cancellation,
    void Function(int, int)? onProgress,
  }) {
    this.cancellation = cancellation;
    final completer = Completer<String?>();
    pending.add(completer);
    return completer.future;
  }
}

const _starter = PokemonSummary(
  id: 1,
  nameEn: 'Bulbasaur',
  nameZh: '妙蛙种子',
  types: ['grass'],
);
const _detail = PokemonDetail(
  summary: _starter,
  genusZh: '',
  heightDm: 7,
  weightHg: 69,
  weaknesses: [],
  resistances: [],
  immunities: [],
  stabSuperEffective: [],
  evolutionChain: null,
);

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await companionRepository.clear();
    await companionRepository.save(
      const CompanionChoice(pokemonId: 162, nameZh: '大尾立'),
    );
    final messenger = binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (_) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        final args = call.arguments as Map<dynamic, dynamic>?;
        if (call.method == 'create' && args?['playerId'] != null) {
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/${args!['playerId']}'),
            (_) async => null,
          );
        }
        return 1;
      },
    );
  });

  Future<void> open(WidgetTester tester, _PickerCache cache) async {
    final normal = animationFixture(speciesId: 1, formKey: 'bulbasaur');
    final shiny = animationFixture(
      id: 'shiny',
      speciesId: 1,
      formKey: 'bulbasaur',
      shiny: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCompanionFormPickerSheet(
                context,
                _starter,
                data: Future.value((_detail, null)),
                animationCatalog: CompanionAnimationCatalog([normal, shiny]),
                mediaCache: cache,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('通用 · 测试来源').last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'browse and choose do not download; even a bundled starter waits for confirmation',
    (tester) async {
      final cache = _PickerCache();
      await open(tester, cache);
      await choose(tester);
      expect(cache.pending, isEmpty);
      for (final image in tester.widgetList<FallbackSpriteImage>(
        find.byType(FallbackSpriteImage),
      )) {
        expect(
          image.sources.where((url) => url.contains('example.test')),
          isEmpty,
        );
        expect(image.sources.where((url) => url.endsWith('.gif')), isEmpty);
      }
      await tester.tap(find.text('下载并使用'));
      await tester.pumpAndSettle();
      expect(cache.pending, hasLength(1));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(companionRepository.choice?.pokemonId, 162);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(cache.cancellation?.isCancelled, isTrue);
      cache.pending.single.complete(null);
      await tester.pumpAndSettle();
      expect(companionRepository.choice?.pokemonId, 162);
    },
  );

  testWidgets(
    'failed download stays retryable and only success commits the selected asset',
    (tester) async {
      final cache = _PickerCache();
      await open(tester, cache);
      await choose(tester);
      await tester.tap(find.text('下载并使用'));
      await tester.pumpAndSettle();
      cache.pending.single.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('重试下载'), findsOneWidget);
      expect(companionRepository.choice?.pokemonId, 162);
      await tester.tap(find.text('重试下载'));
      await tester.pumpAndSettle();
      cache.pending.last.complete('/validated/local.gif');
      await tester.pumpAndSettle();
      expect(companionRepository.choice?.pokemonId, 1);
      expect(
        companionRepository.choice?.animationAssetId,
        'source-a:162:furret:normal',
      );
      expect(companionRepository.choice?.isShiny, isFalse);
    },
  );

  testWidgets(
    'shiny toggle resets normal asset selection and commits only the shiny candidate',
    (tester) async {
      final cache = _PickerCache();
      await open(tester, cache);
      await choose(tester);
      await tester.tap(find.byType(FilterChip));
      await tester.pumpAndSettle();
      expect(find.text('下载并使用'), findsNothing);
      await choose(tester);
      await tester.tap(find.text('下载并使用'));
      await tester.pumpAndSettle();
      cache.pending.single.complete('/validated/shiny.gif');
      await tester.pumpAndSettle();
      expect(companionRepository.choice?.animationAssetId, 'shiny');
      expect(companionRepository.choice?.isShiny, isTrue);
    },
  );

  testWidgets('source metadata fits a handheld landscape sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cache = _PickerCache();
    await open(tester, cache);
    await choose(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('下载并使用'), findsOneWidget);
  });

  testWidgets(
    'an unavailable stored legacy URL cannot hide behind automatic selection',
    (tester) async {
      await companionRepository.save(
        const CompanionChoice(
          pokemonId: 1,
          nameZh: '妙蛙种子',
          animationSourceUrl: 'https://removed.example/old.gif',
        ),
      );
      await open(tester, _PickerCache());
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(companionRepository.choice?.animationSourceUrl, isNull);
      expect(companionRepository.choice?.animationAssetId, isNull);
    },
  );
}
