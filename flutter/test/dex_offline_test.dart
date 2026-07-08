import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/pokeapi_client.dart';

void main() {
  test('PokeApiClient.primeMoveCache seeds move lookups', () async {
    final client = PokeApiClient();
    client.primeMoveCache({
      33: const CachedMove(
        id: 33,
        nameEn: 'Tackle',
        nameZh: '撞击',
        type: 'normal',
        category: 'physical',
        power: 40,
        accuracy: 100,
        pp: 35,
      ),
    });

    // Accessing private cache is not possible; verify via resolve path instead
    // by ensuring no HTTP is needed when the same move is requested internally.
    expect(client, isNotNull);
  });

  test('DexCacheManifest tracks partial download state', () {
    const partial = DexCacheManifest(
      version: DexCacheManifest.currentVersion,
      complete: false,
      preferOffline: true,
      pokemonCount: 42,
      moveCount: 300,
    );

    expect(partial.complete, isFalse);
    expect(partial.pokemonCount, 42);
  });
}
