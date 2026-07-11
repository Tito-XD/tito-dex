import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dex_cdn_config.dart';
import 'dex_models.dart';

/// Live dex data straight from the Cloudflare R2 CDN (`dex.tito.cafe`).
///
/// Default online path: one `summaries.json` request replaces ~1000 PokeAPI
/// calls, and per-Pokémon `details/{id}.json` is a single cached edge fetch.
/// The Settings-downloaded offline bundle still takes priority; PokeAPI stays
/// as the last-resort fallback.
class DexCdnDataSource {
  DexCdnDataSource({
    http.Client? client,
    DexCdnConfig config = const DexCdnConfig(),
  })  : _client = client ?? http.Client(),
        _config = config;

  final http.Client _client;
  final DexCdnConfig _config;

  static const _timeout = Duration(seconds: 12);

  Future<List<PokemonSummary>>? _summariesFuture;
  Future<Map<int, CachedMove>>? _movesFuture;

  Future<List<PokemonSummary>> fetchAllSummaries() {
    return _summariesFuture ??= _loadSummaries().catchError((Object error) {
      // Allow a retry on the next call instead of caching the failure.
      _summariesFuture = null;
      throw error; // ignore: only_throw_errors
    });
  }

  Future<PokemonDetail> fetchDetail(int id) async {
    final json = await _getJson('${DexCdnConfig.cdnBase}/v2/details/$id.json');
    final moves = await _fetchMoves();
    _stripLocalPaths(json);
    return PokemonDetail.fromJson(json, moveLookup: moves);
  }

  Future<List<PokemonSummary>> _loadSummaries() async {
    final body = await _getBody('${DexCdnConfig.cdnBase}/v2/summaries.json');
    final list = jsonDecode(body) as List<dynamic>;
    return list.map((item) {
      final json = item as Map<String, dynamic>;
      _stripLocalPaths(json);
      return PokemonSummary.fromJson(json);
    }).toList(growable: false);
  }

  Future<Map<int, CachedMove>> _fetchMoves() {
    return _movesFuture ??= _loadMoves().catchError((Object error) {
      _movesFuture = null;
      throw error; // ignore: only_throw_errors
    });
  }

  Future<Map<int, CachedMove>> _loadMoves() async {
    final body = await _getBody('${DexCdnConfig.cdnBase}/v2/moves.json');
    final json = jsonDecode(body) as Map<String, dynamic>;
    final moves = <int, CachedMove>{};
    for (final entry in json.entries) {
      final id = int.tryParse(entry.key);
      if (id == null) {
        continue;
      }
      moves[id] = CachedMove.fromJson(entry.value as Map<String, dynamic>);
    }
    return moves;
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    return jsonDecode(await _getBody(url)) as Map<String, dynamic>;
  }

  Future<String> _getBody(String url) async {
    final response =
        await _client.get(Uri.parse(url)).timeout(_timeout);
    if (response.statusCode != 200) {
      throw DexCdnException('GET $url failed: HTTP ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes);
  }

  /// The CDN JSON mirrors the offline bundle, so entries carry
  /// `localSpritePath` values that only exist after a Settings download.
  /// Strip them so `displaySpritePath` falls back to the CDN sprite URL.
  void _stripLocalPaths(Object? node) {
    if (node is Map<String, dynamic>) {
      node.remove('localSpritePath');
      for (final value in node.values) {
        _stripLocalPaths(value);
      }
    } else if (node is List) {
      for (final value in node) {
        _stripLocalPaths(value);
      }
    }
  }

  // Config retained for future use (artwork URLs etc.).
  DexCdnConfig get config => _config;
}
