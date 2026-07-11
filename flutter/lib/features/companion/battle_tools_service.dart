import '../dex/dex_cache_store.dart';
import '../dex/pokeapi_client.dart';
import '../dex/type_chart.dart';

/// Loads type relations for companion battle tools (offline cache → PokeAPI).
class BattleToolsService {
  BattleToolsService({
    PokeApiClient? client,
    DexCacheStore? store,
  })  : _client = client ?? PokeApiClient(),
        _store = store ?? DexCacheStore();

  final PokeApiClient _client;
  final DexCacheStore _store;
  Map<String, TypeDamageRelations>? _cached;

  Future<Map<String, TypeDamageRelations>> loadTypeRelations() async {
    if (_cached != null) {
      return _cached!;
    }

    final offline = await _store.readTypeRelations();
    if (offline.isNotEmpty) {
      _cached = offline;
      return offline;
    }

    final live = await _client.loadAllTypeRelations();
    _cached = live;
    return live;
  }
}

final battleToolsService = BattleToolsService();
