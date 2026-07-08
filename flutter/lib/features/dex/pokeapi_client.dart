import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dex_models.dart';
import 'type_chart.dart';

class PokeApiClient {
  PokeApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const baseUrl = 'https://pokeapi.co/api/v2';

  final Map<String, TypeDamageRelations> _typeRelationsCache = {};

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _client.get(Uri.parse('$baseUrl$path'));
    if (response.statusCode != 200) {
      throw PokeApiException(path, response.statusCode);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, TypeDamageRelations>> loadAllTypeRelations() async {
    if (_typeRelationsCache.isNotEmpty) {
      return _typeRelationsCache;
    }

    final index = await _getJson('/type?limit=100');
    final results = index['results'] as List<dynamic>;

    for (final result in results) {
      final name = (result as Map<String, dynamic>)['name'] as String;
      if (!typeNamesZh.containsKey(name)) {
        continue;
      }
      final detail = await _getJson('/type/$name');
      final damage = detail['damage_relations'] as Map<String, dynamic>;
      _typeRelationsCache[name] = parseTypeDamageRelations(damage);
    }

    return _typeRelationsCache;
  }

  Future<PokemonSummary> fetchSummary(int id) async {
    final pokemon = await _getJson('/pokemon/$id');
    final species = await _getJson('/pokemon-species/$id');

    return PokemonSummary(
      id: pokemon['id'] as int,
      nameEn: _capitalize(pokemon['name'] as String),
      nameZh: _localizedName(
        species['names'] as List<dynamic>,
        fallback: pokemon['name'] as String,
      ),
      types: _extractTypes(pokemon['types'] as List<dynamic>),
      spriteUrl: _spriteUrl(pokemon['sprites'] as Map<String, dynamic>),
    );
  }

  Future<PokemonDetail> fetchDetail(int id) async {
    final pokemon = await _getJson('/pokemon/$id');
    final species = await _getJson('/pokemon-species/$id');
    final relations = await loadAllTypeRelations();

    final summary = PokemonSummary(
      id: pokemon['id'] as int,
      nameEn: _capitalize(pokemon['name'] as String),
      nameZh: _localizedName(
        species['names'] as List<dynamic>,
        fallback: pokemon['name'] as String,
      ),
      types: _extractTypes(pokemon['types'] as List<dynamic>),
      spriteUrl: _spriteUrl(pokemon['sprites'] as Map<String, dynamic>),
    );

    final profile = computeDefensiveProfile(summary.types, relations);
    final stab = computeStabSuperEffective(summary.types, relations);

    final evolutionUrl = species['evolution_chain']?['url'] as String?;
    EvolutionNode? evolution;
    if (evolutionUrl != null) {
      evolution = await _fetchEvolutionChain(evolutionUrl);
    }

    return PokemonDetail(
      summary: summary,
      genusZh: _genusZh(species['genera'] as List<dynamic>),
      heightDm: pokemon['height'] as int? ?? 0,
      weightHg: pokemon['weight'] as int? ?? 0,
      weaknesses: profile.weaknesses,
      resistances: profile.resistances,
      immunities: profile.immunities,
      stabSuperEffective: stab,
      evolutionChain: evolution,
    );
  }

  Future<int?> resolveSpeciesId(String speciesName) async {
    try {
      final pokemon = await _getJson('/pokemon/${speciesName.toLowerCase()}');
      return pokemon['id'] as int;
    } on PokeApiException {
      return null;
    }
  }

  Future<EvolutionNode> _fetchEvolutionChain(String url) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw PokeApiException(url, response.statusCode);
    }
    final chain = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseEvolutionNode(chain['chain'] as Map<String, dynamic>);
  }

  Future<EvolutionNode> _parseEvolutionNode(Map<String, dynamic> node) async {
    final species = node['species'] as Map<String, dynamic>;
    final speciesUrl = species['url'] as String;
    final speciesId = _idFromUrl(speciesUrl);
    final speciesDetail = await _getJson('/pokemon-species/$speciesId');
    final pokemon = await _getJson('/pokemon/$speciesId');

    String? triggerZh;
    final details = node['evolution_details'] as List<dynamic>?;
    if (details != null && details.isNotEmpty) {
      triggerZh = _evolutionTriggerZh(details.first as Map<String, dynamic>);
    }

    final children = <EvolutionNode>[];
    for (final child in node['evolves_to'] as List<dynamic>) {
      children.add(await _parseEvolutionNode(child as Map<String, dynamic>));
    }

    return EvolutionNode(
      id: speciesId,
      nameEn: _capitalize(species['name'] as String),
      nameZh: _localizedName(
        speciesDetail['names'] as List<dynamic>,
        fallback: species['name'] as String,
      ),
      spriteUrl: _spriteUrl(pokemon['sprites'] as Map<String, dynamic>),
      evolvesFrom: triggerZh,
      triggerZh: triggerZh,
      children: children,
    );
  }

  List<String> _extractTypes(List<dynamic> types) {
    final sorted = List<Map<String, dynamic>>.from(types)
      ..sort(
        (a, b) => ((a['slot'] as int)).compareTo(b['slot'] as int),
      );
    return sorted
        .map(
          (entry) =>
              (entry['type'] as Map<String, dynamic>)['name'] as String,
        )
        .toList();
  }

  String? _spriteUrl(Map<String, dynamic> sprites) {
    final other = sprites['other'] as Map<String, dynamic>?;
    final artwork = other?['official-artwork'] as Map<String, dynamic>?;
    return artwork?['front_default'] as String? ??
        sprites['front_default'] as String?;
  }

  String _localizedName(List<dynamic> names, {required String fallback}) {
    for (final entry in names) {
      final map = entry as Map<String, dynamic>;
      final language = map['language'] as Map<String, dynamic>;
      final code = language['name'] as String;
      if (code == 'zh-Hans' || code == 'zh-hans') {
        return map['name'] as String;
      }
    }
    for (final entry in names) {
      final map = entry as Map<String, dynamic>;
      final language = map['language'] as Map<String, dynamic>;
      if (language['name'] == 'zh-Hant') {
        return map['name'] as String;
      }
    }
    return _capitalize(fallback);
  }

  String _genusZh(List<dynamic> genera) {
    for (final entry in genera) {
      final map = entry as Map<String, dynamic>;
      final language = map['language'] as Map<String, dynamic>;
      final code = language['name'] as String;
      if (code == 'zh-Hans' || code == 'zh-hans') {
        return map['genus'] as String;
      }
    }
    if (genera.isNotEmpty) {
      return (genera.first as Map<String, dynamic>)['genus'] as String;
    }
    return '';
  }

  String? _evolutionTriggerZh(Map<String, dynamic> detail) {
    final minLevel = detail['min_level'] as int?;
    if (minLevel != null && minLevel > 0) {
      return 'Lv.$minLevel';
    }

    final item = detail['item'] as Map<String, dynamic>?;
    if (item != null) {
      return '道具：${_capitalize(item['name'] as String)}';
    }

    final trigger = detail['trigger'] as Map<String, dynamic>?;
    final triggerName = trigger?['name'] as String?;
    return switch (triggerName) {
      'level-up' => '升级',
      'use-item' => '使用道具',
      'trade' => '交换',
      'shed' => '蜕壳',
      'spin' => '旋转',
      'tower-of-darkness' => '恶之塔',
      'tower-of-waters' => '水之塔',
      'three-critical-hits' => '三次要害',
      'take-damage' => '受到伤害',
      'other' => '特殊条件',
      _ => triggerName != null ? _capitalize(triggerName) : null,
    };
  }

  int _idFromUrl(String url) {
    final segments = Uri.parse(url).pathSegments;
    return int.parse(segments.last);
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }
}

class PokeApiException implements Exception {
  PokeApiException(this.path, this.statusCode);

  final String path;
  final int statusCode;

  @override
  String toString() => 'PokeAPI $statusCode for $path';
}
