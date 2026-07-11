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
  Future<Map<int, CachedAbility>>? _abilitiesFuture;
  String? _activeApiPrefix;

  Future<List<PokemonSummary>> fetchAllSummaries() {
    return _summariesFuture ??= _loadSummaries().catchError((Object error) {
      _summariesFuture = null;
      throw error; // ignore: only_throw_errors
    });
  }

  Future<PokemonDetail> fetchDetail(int id) async {
    final prefix = await _resolveApiPrefix();
    final json = await _getJson(_config.detailUrl(id, prefix: prefix));
    final moves = await fetchAllMoves();
    _stripLocalPaths(json);
    return PokemonDetail.fromJson(json, moveLookup: moves);
  }

  Future<List<PokemonSummary>> _loadSummaries() async {
    final prefixes = [
      DexCdnConfig.bundleVersionPrefix,
      DexCdnConfig.legacyBundleVersionPrefix,
    ];
    Object? lastError;
    for (final prefix in prefixes) {
      try {
        final body = await _getBody(_config.summariesUrl(prefix: prefix));
        _activeApiPrefix = prefix;
        final list = jsonDecode(body) as List<dynamic>;
        return list.map((item) {
          final json = item as Map<String, dynamic>;
          _stripLocalPaths(json);
          return PokemonSummary.fromJson(json);
        }).toList(growable: false);
      } catch (error) {
        lastError = error;
      }
    }
    throw DexCdnException(
      'Failed to load summaries from CDN: $lastError',
    );
  }

  Future<Map<int, CachedMove>> fetchAllMoves() => _fetchMoves();

  Future<Map<int, CachedAbility>> fetchAllAbilities() => _fetchAbilities();

  Future<CachedAbility> fetchAbilityEncyclopedia(int id) async {
    final abilities = await fetchAllAbilities();
    final entry = abilities[id];
    if (entry == null) {
      throw DexCdnException('Ability #$id not found in CDN index');
    }
    return entry;
  }

  Future<Map<int, CachedMove>> _fetchMoves() {
    return _movesFuture ??= _loadMoves().catchError((Object error) {
      _movesFuture = null;
      throw error; // ignore: only_throw_errors
    });
  }

  Future<Map<int, CachedMove>> _loadMoves() async {
    final prefix = await _resolveApiPrefix();
    final body = await _getBody(_config.movesUrl(prefix: prefix));
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

  Future<Map<int, CachedAbility>> _fetchAbilities() {
    return _abilitiesFuture ??= _loadAbilities().catchError((Object error) {
      _abilitiesFuture = null;
      throw error; // ignore: only_throw_errors
    });
  }

  Future<Map<int, CachedAbility>> _loadAbilities() async {
    final prefixes = [
      await _resolveApiPrefix(),
      DexCdnConfig.legacyBundleVersionPrefix,
    ];
    Object? lastError;
    for (final prefix in prefixes) {
      try {
        final body = await _getBody(_config.abilitiesUrl(prefix: prefix));
        final json = jsonDecode(body) as Map<String, dynamic>;
        final abilities = <int, CachedAbility>{};
        for (final entry in json.entries) {
          final id = int.tryParse(entry.key);
          if (id == null) {
            continue;
          }
          abilities[id] = CachedAbility.fromJson(
            entry.value as Map<String, dynamic>,
            fallbackId: id,
          );
        }
        return abilities;
      } catch (error) {
        lastError = error;
      }
    }
    throw DexCdnException(
      'Failed to load abilities from CDN: $lastError',
    );
  }

  Future<String> _resolveApiPrefix() async {
    if (_activeApiPrefix != null) {
      return _activeApiPrefix!;
    }

    if (_summariesFuture != null) {
      try {
        await _summariesFuture;
      } catch (_) {
        // Ignore — prefix probing below still runs.
      }
      if (_activeApiPrefix != null) {
        return _activeApiPrefix!;
      }
    }

    for (final prefix in [
      DexCdnConfig.bundleVersionPrefix,
      DexCdnConfig.legacyBundleVersionPrefix,
    ]) {
      try {
        final response = await _client
            .head(Uri.parse(_config.summariesUrl(prefix: prefix)))
            .timeout(_timeout);
        if (response.statusCode == 200) {
          _activeApiPrefix = prefix;
          return prefix;
        }
      } catch (_) {
        // Try the next prefix.
      }
    }

    return DexCdnConfig.bundleVersionPrefix;
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

  DexCdnConfig get config => _config;
}
