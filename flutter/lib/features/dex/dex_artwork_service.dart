import 'package:http/http.dart' as http;

import 'dex_cache_store.dart';
import 'dex_sprite_codec.dart';

/// Lazy-loads full-size artwork (CDN → PokeAPI → thumb fallback).
class DexArtworkService {
  DexArtworkService({
    DexCacheStore? store,
    DexSpriteCodec? codec,
    http.Client? httpClient,
  })  : _store = store ?? DexCacheStore(),
        _codec = codec ?? const DexSpriteCodec(),
        _http = httpClient ?? http.Client();

  final DexCacheStore _store;
  final DexSpriteCodec _codec;
  final http.Client _http;

  Future<String?> resolveArtworkSource({
    required int pokemonId,
    String? artworkUrl,
    String? thumbSource,
  }) async {
    final cached = await _store.artworkAbsolutePath(pokemonId);
    if (cached != null) {
      return cached;
    }

    final candidates = <String>[
      if (artworkUrl != null && artworkUrl.isNotEmpty) artworkUrl,
      pokeApiOfficialArtworkUrl(pokemonId),
    ];

    for (final url in candidates) {
      final local = await _downloadAndCache(pokemonId, url);
      if (local != null) {
        return local;
      }
    }

    return thumbSource;
  }

  Future<String?> _downloadAndCache(int id, String url) async {
    final response = await _http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      return null;
    }

    final encoded =
        _codec.compressArtworkPngBytes(response.bodyBytes) ?? response.bodyBytes;
    await _store.writeArtworkBytes(id, encoded);
    return _store.artworkAbsolutePath(id);
  }
}

final dexArtworkService = DexArtworkService();
