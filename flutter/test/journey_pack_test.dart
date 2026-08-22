import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:titodex/features/game/game_edition.dart';
import 'package:titodex/features/journey/journey_pack_client.dart';
import 'package:titodex/features/journey/journey_pack_models.dart';
import 'package:titodex/features/journey/journey_pack_repository.dart';
import 'package:titodex/features/journey/journey_pack_store.dart';
import 'package:titodex/features/journey/journey_worker_config.dart';
import 'package:titodex/features/journey/progression_hints.dart';
import 'package:titodex/pages/journey_pack_manager_page.dart';

void main() {
  group('Journey pack catalog contract', () {
    test('derives catalog and immutable objects from the Worker only', () {
      const worker = 'https://journey.example.test/v1/ask';
      expect(
        JourneyWorkerConfig.packCatalogUri(worker).toString(),
        'https://journey.example.test/v1/journey-packs/catalog',
      );
      final fixture = _packFixture();
      final client = JourneyPackClient(
        workerAskUrl: worker,
        client: MockClient((_) async => http.Response('', 500)),
      );
      expect(
        client.objectUri(fixture.descriptor).toString(),
        'https://journey.example.test${fixture.descriptor.contentPath}',
      );
      client.close();
    });

    test(
      'an already-cancelled download stops before accepting bytes',
      () async {
        final fixture = _packFixture();
        final token = JourneyPackCancelToken();
        await token.cancel();
        final client = JourneyPackClient(
          workerAskUrl: 'https://journey.example.test/v1/ask',
          client: MockClient(
            (request) async =>
                http.Response.bytes(fixture.bytes, 200, request: request),
          ),
        );
        expect(
          client.download(fixture.descriptor, cancelToken: token),
          throwsA(
            isA<JourneyPackClientException>().having(
              (error) => error.code,
              'code',
              'cancelled',
            ),
          ),
        );
        client.close();
      },
    );

    test('rejects unsafe paths, oversize packs and ambiguous game mapping', () {
      final base = _descriptorJson(
        contentPath: '/v1/journey-packs/objects/sv-guide/1.0.0.json',
      );
      for (final path in [
        'https://r2.example/pack.json',
        '/v1/journey-packs/objects/../pack.json',
        '/v1/journey-packs/objects/sv-guide/pack.zip',
      ]) {
        expect(
          () => JourneyPackDescriptor.fromJson({...base, 'contentPath': path}),
          throwsFormatException,
        );
      }
      expect(
        () => JourneyPackDescriptor.fromJson({
          ...base,
          'sizeBytes': journeyPackMaxBytes + 1,
        }),
        throwsFormatException,
      );
      expect(
        () => JourneyPackCatalog.fromJson({
          'schemaVersion': 1,
          'packs': [
            base,
            {
              ...base,
              'id': 'other',
              'gameFamily': 'other',
              'contentPath': '/v1/journey-packs/objects/other/1.0.0.json',
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test('client validates catalog, size and SHA-256', () async {
      final fixture = _packFixture();
      late bool corrupt;
      corrupt = false;
      final httpClient = MockClient((request) async {
        if (request.url.path == '/v1/journey-packs/catalog') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'schemaVersion': 1,
                'packs': [fixture.descriptor.toJson()],
              }),
            ),
            200,
            request: request,
          );
        }
        return http.Response.bytes(
          corrupt ? Uint8List(fixture.bytes.length) : fixture.bytes,
          200,
          request: request,
        );
      });
      final client = JourneyPackClient(
        workerAskUrl: 'https://journey.example.test/v1/ask',
        client: httpClient,
      );
      final catalog = await client.fetchCatalog();
      expect(catalog.packs.single.games, contains('violet'));
      expect(await client.download(catalog.packs.single), fixture.bytes);
      corrupt = true;
      expect(
        client.download(catalog.packs.single),
        throwsA(
          isA<JourneyPackClientException>().having(
            (error) => error.code,
            'code',
            'pack_integrity_failed',
          ),
        ),
      );
      client.close();
    });
  });

  group('Journey pack private store', () {
    late Directory temporary;
    late FileJourneyPackStore store;

    setUp(() async {
      temporary = await Directory.systemTemp.createTemp('titodex-pack-test-');
      store = FileJourneyPackStore(rootProvider: () async => temporary);
    });

    tearDown(() async {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    });

    test(
      'verified update is atomic and failed input preserves old pack',
      () async {
        final old = _packFixture(version: '1.0.0');
        final oldDocument = JourneyPackDocument.fromBytes(
          old.bytes,
          descriptor: old.descriptor,
        );
        await store.install(old.descriptor, old.bytes, oldDocument);

        expect(
          store.install(old.descriptor, Uint8List(1), oldDocument),
          throwsFormatException,
        );
        var snapshot = await store.load();
        expect(snapshot.installed['sv']?.descriptor.version, '1.0.0');

        final updated = _packFixture(version: '1.1.0');
        await store.install(
          updated.descriptor,
          updated.bytes,
          JourneyPackDocument.fromBytes(
            updated.bytes,
            descriptor: updated.descriptor,
          ),
        );
        snapshot = await store.load();
        expect(snapshot.installed['sv']?.descriptor.version, '1.1.0');
        await store.delete('sv');
        expect((await store.load()).installed, isEmpty);
      },
    );

    test('corrupt local object is isolated and can be repaired', () async {
      final fixture = _packFixture();
      final document = JourneyPackDocument.fromBytes(
        fixture.bytes,
        descriptor: fixture.descriptor,
      );
      await store.install(fixture.descriptor, fixture.bytes, document);
      final snapshot = await store.load();
      final objectPath = snapshot.installed['sv']!.objectPath;
      await File('${temporary.path}/$objectPath').writeAsString('broken');
      expect((await store.load()).corruptFamilies, contains('sv'));
      await store.install(fixture.descriptor, fixture.bytes, document);
      expect((await store.load()).installed, contains('sv'));
    });
  });

  group('Journey pack repository and Ask context', () {
    test('disabled master switch never requests the catalog', () async {
      var requests = 0;
      final repository = JourneyPackRepository(
        enabledProvider: () => false,
        store: _MemoryPackStore(),
        client: JourneyPackClient(
          workerAskUrl: 'https://journey.example.test/v1/ask',
          client: MockClient((request) async {
            requests += 1;
            return http.Response('{}', 200, request: request);
          }),
        ),
      );
      expect(await repository.refreshCatalog(), 'disabled');
      expect(requests, 0);
      repository.dispose();
    });

    test(
      'installed pack contributes a bounded reference, never its body',
      () async {
        final fixture = _packFixture();
        final store = _MemoryPackStore();
        await store.install(
          fixture.descriptor,
          fixture.bytes,
          JourneyPackDocument.fromBytes(
            fixture.bytes,
            descriptor: fixture.descriptor,
          ),
        );
        final repository = JourneyPackRepository(
          enabledProvider: () => true,
          store: store,
          client: _catalogClient(fixture),
        );
        final refs = await repository.referencesForGame('violet');
        final context = _context.copyWith(journeyPacks: refs);
        final encoded = jsonEncode(context.toRequestJson());
        expect(refs.single.id, 'sv-guide');
        expect(encoded, contains('journeyPacks'));
        expect(encoded, isNot(contains('overviewZh')));
        expect(encoded, isNot(contains('save')));
        final bounded =
            _context
                    .copyWith(journeyPacks: [refs.single, refs.single])
                    .toRequestJson()['journeyPacks']
                as List<dynamic>;
        expect(bounded, hasLength(1));
        repository.dispose();
      },
    );

    test('online reference requires the latest catalog trust anchor', () async {
      final fixture = _packFixture();
      final store = _MemoryPackStore();
      await store.install(
        fixture.descriptor,
        fixture.bytes,
        JourneyPackDocument.fromBytes(
          fixture.bytes,
          descriptor: fixture.descriptor,
        ),
      );
      final repository = JourneyPackRepository(
        enabledProvider: () => true,
        store: store,
        client: JourneyPackClient(
          workerAskUrl: 'https://journey.example.test/v1/ask',
          client: MockClient(
            (request) async => http.Response.bytes(
              utf8.encode('{"schemaVersion":1,"packs":[]}'),
              200,
              request: request,
            ),
          ),
        ),
      );
      expect(await repository.referencesForGame('violet'), isEmpty);
      repository.dispose();
    });

    test(
      'downloaded progression hints extend and override the old fallback',
      () async {
        final base = _progressionJson('旧说明');
        final downloaded = jsonEncode({
          'schemaVersion': 1,
          'entries': [
            jsonDecode(_progressionJson('新说明'))['entries'][0],
            {'entryType': 'fact', 'id': 'untouched-fact'},
          ],
        });
        final hints = ProgressionHintRepository(
          extensionDataSource: _StringDataSource(base),
          bundledDataSource: const _StringDataSource(null),
          downloadedPackDataSource: _StringDataSource(downloaded),
        );
        final loaded = await hints.load();
        expect(loaded, hasLength(1));
        expect(loaded.single.overviewZh, '新说明');
      },
    );

    testWidgets('manager shows the current game and install state', (
      tester,
    ) async {
      final fixture = _packFixture();
      final repository = JourneyPackRepository(
        enabledProvider: () => true,
        store: _MemoryPackStore(),
        client: JourneyPackClient(
          workerAskUrl: 'https://journey.example.test/v1/ask',
          client: MockClient(
            (request) async => http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'schemaVersion': 1,
                  'packs': [fixture.descriptor.toJson()],
                }),
              ),
              200,
              request: request,
            ),
          ),
        ),
      );
      final router = GoRouter(
        initialLocation: '/packs',
        routes: [
          GoRoute(
            path: '/packs',
            builder: (context, state) => Scaffold(
              body: JourneyPackManagerPage(
                edition: gameEditionFromSlug('sv')!.withFlavor('violet'),
                repository: repository,
                refreshCatalogOnOpen: false,
              ),
            ),
          ),
        ],
      );
      expect(await tester.runAsync(repository.refreshCatalog), 'ok');
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.byKey(const Key('journey-pack-current-game')),
        findsOneWidget,
      );
      expect(find.text('紫'), findsOneWidget);
      expect(find.byKey(const Key('journey-pack-sv')), findsOneWidget);
      expect(find.byKey(const Key('journey-pack-install-sv')), findsOneWidget);
      router.dispose();
      repository.dispose();
    });
  });
}

class _PackFixture {
  const _PackFixture(this.descriptor, this.bytes);

  final JourneyPackDescriptor descriptor;
  final Uint8List bytes;
}

_PackFixture _packFixture({String version = '1.0.0'}) {
  final bytes = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'schemaVersion': 1,
        'id': 'sv-guide',
        'gameFamily': 'sv',
        'version': version,
        'entries': [jsonDecode(_progressionJson('朱紫测试说明'))['entries'][0]],
      }),
    ),
  );
  return _PackFixture(
    JourneyPackDescriptor.fromJson(
      _descriptorJson(
        version: version,
        sizeBytes: bytes.length,
        sha256Hex: sha256.convert(bytes).toString(),
      ),
    ),
    bytes,
  );
}

Map<String, dynamic> _descriptorJson({
  String? contentPath,
  String version = '1.0.0',
  int sizeBytes = 128,
  String sha256Hex =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
}) => {
  'id': 'sv-guide',
  'gameFamily': 'sv',
  'games': ['scarlet', 'violet'],
  'version': version,
  'contentPath':
      contentPath ?? '/v1/journey-packs/objects/sv-guide/$version.json',
  'sizeBytes': sizeBytes,
  'sha256': sha256Hex,
  'entryCount': 1,
  'bundleVersionRequired': 20,
  'titleZh': '朱／紫 Journey 资料',
};

String _progressionJson(String overview) => jsonEncode({
  'schemaVersion': 1,
  'entries': [
    {
      'entryType': 'progression_hint',
      'id': 'sv-test-hint',
      'games': ['violet'],
      'locations': ['test-area'],
      'locationAliases': ['测试地点'],
      'destinationAliases': ['目的地'],
      'subject': {
        'id': 'test-subject',
        'aliases': ['测试问题'],
      },
      'requirements': <Object>[],
      'steps': [
        {'instructionZh': '继续前进。'},
      ],
      'overviewZh': overview,
      'sources': [
        {
          'title': 'TitoDex',
          'url': 'https://example.test/source',
          'accessedAt': '2026-08-23',
        },
      ],
    },
  ],
});

class _StringDataSource implements ProgressionHintDataSource {
  const _StringDataSource(this.value);

  final String? value;

  @override
  Future<String?> loadJson() async => value;
}

class _MemoryPackStore implements JourneyPackStore {
  Map<String, InstalledJourneyPack> installed = {};

  @override
  Future<void> delete(String gameFamily) async {
    installed.remove(gameFamily);
  }

  @override
  Future<void> install(
    JourneyPackDescriptor descriptor,
    Uint8List bytes,
    JourneyPackDocument document,
  ) async {
    installed[descriptor.gameFamily] = InstalledJourneyPack(
      descriptor: descriptor,
      installedAt: DateTime.utc(2026, 8, 23),
      objectPath: 'memory/${descriptor.sha256Hex}.json',
      document: document,
    );
  }

  @override
  Future<JourneyPackStoreSnapshot> load() async =>
      JourneyPackStoreSnapshot(installed: Map.unmodifiable(installed));
}

const _context = AskTitoDexContext(
  game: 'violet',
  generation: 9,
  locationLabel: null,
  locationId: null,
  badgeIds: [],
  milestoneIds: [],
  parserRevision: 0,
  gameReliability: 'user_selected',
  locationReliability: 'unknown',
  badgesReliability: 'unknown',
);

JourneyPackClient _catalogClient(_PackFixture fixture) => JourneyPackClient(
  workerAskUrl: 'https://journey.example.test/v1/ask',
  client: MockClient(
    (request) async => http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'schemaVersion': 1,
          'packs': [fixture.descriptor.toJson()],
        }),
      ),
      200,
      request: request,
    ),
  ),
);
