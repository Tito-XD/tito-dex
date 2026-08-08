import 'dart:convert';

import 'package:flutter/services.dart';

import '../game/game_edition.dart';

enum ItemGameAvailability { available, unavailable, unknown }

class ItemGameView {
  const ItemGameView({
    required this.availability,
    required this.versionGroup,
    this.buy,
    this.sell,
    this.currency = 'poke-dollar',
  });

  final ItemGameAvailability availability;
  final String versionGroup;
  final Object? buy;
  final Object? sell;
  final String currency;
}

class ItemGameDataRepository {
  Future<Map<String, dynamic>>? _future;
  Set<String> _knownVersionGroups = const {};

  Future<Map<String, dynamic>> load() => _future ??= _load();

  Future<Map<String, dynamic>> _load() async {
    final source = await rootBundle.loadString(
      'assets/data/item_version_matrix.json',
    );
    final payload = jsonDecode(source) as Map<String, dynamic>;
    final items = payload['items'] as Map<String, dynamic>? ?? const {};
    _knownVersionGroups = {
      for (final value in items.values)
        if (value is Map<String, dynamic>)
          for (final group
              in value['versionGroups'] as List<dynamic>? ?? const [])
            if (group is String) group,
    };
    return items;
  }

  Future<ItemGameView> viewFor(
    Map<String, dynamic> entry,
    GameEdition edition,
  ) async {
    final matrix = await load();
    final id = entry['id']?.toString();
    final raw = id == null ? null : matrix[id];
    final versionGroup = itemReferenceVersionGroup(edition);
    if (!_knownVersionGroups.contains(versionGroup)) {
      return ItemGameView(
        availability: ItemGameAvailability.unknown,
        versionGroup: versionGroup,
      );
    }
    if (raw is! Map<String, dynamic>) {
      return ItemGameView(
        availability: ItemGameAvailability.unknown,
        versionGroup: versionGroup,
      );
    }
    final groups = (raw['versionGroups'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toSet();
    final generations = (raw['generations'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((value) => value.toInt())
        .toSet();
    final versions = (raw['versions'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toSet();
    final prices = raw['prices'] as Map<String, dynamic>? ?? const {};
    final price = prices[versionGroup];
    final selectedFlavor = edition.selectedFlavor;
    final groupVersions = edition.flavorVersions.toSet();
    final hasExactDataForGroup = versions.any(groupVersions.contains);
    final exactAvailable =
        groups.contains(versionGroup) &&
        (selectedFlavor == null ||
            !hasExactDataForGroup ||
            versions.contains(selectedFlavor));
    final definitelyUnavailable = groups.isNotEmpty
        ? !exactAvailable
        : generations.isNotEmpty && !generations.contains(edition.generation);
    final priceMap = price is Map<String, dynamic>
        ? price
        : const <String, dynamic>{};
    return ItemGameView(
      availability: exactAvailable
          ? ItemGameAvailability.available
          : definitelyUnavailable
          ? ItemGameAvailability.unavailable
          : ItemGameAvailability.unknown,
      versionGroup: versionGroup,
      buy: priceMap['buy'],
      sell: priceMap['sell'],
      currency: priceMap['currency'] as String? ?? 'poke-dollar',
    );
  }

  Map<String, dynamic> applyView(
    Map<String, dynamic> entry,
    ItemGameView view,
    GameEdition edition,
  ) {
    final result = Map<String, dynamic>.from(entry)
      ..remove('cost')
      ..['_gameAvailability'] = view.availability.name
      ..['_gameVersionGroup'] = view.versionGroup
      ..['_gameLabelZh'] = edition.labelZh
      ..['_priceCurrency'] = view.currency;
    if (view.buy != null) result['_priceBuy'] = view.buy;
    if (view.sell != null) result['_priceSell'] = view.sell;
    return result;
  }
}

String itemReferenceVersionGroup(GameEdition edition) => switch (edition.slug) {
  // 52poke/PokeAPI CSV use the canonical group identifier with the extra z.
  'lza' => 'legends-z-a',
  'champions' => 'champions',
  _ => edition.dataVersionGroupKey,
};

String itemCurrencyLabelZh(String currency) => switch (currency) {
  'poke-dollar' => '₽',
  'coin' => '游戏币',
  'volcanic-ash' => '火山灰',
  'poke-coupon' => '宝可梦优惠券',
  'berry-powder' => '树果粉',
  'battle-point' => 'BP',
  'sphere' => '玉',
  'castle-point' => 'CP',
  'watt' => 'W',
  'athlete-point' => 'AP',
  'dream-point' => '梦点',
  'dream-world-berry' => '梦境树果',
  'poke-mile' => '宝可里程',
  'festival-coin' => '圆庆币',
  'poke-bean' => '宝可豆',
  'home-point' => 'HOME点数',
  'merit-point' => 'FP',
  'league-point' => 'LP',
  'blueberry-point' => 'BP',
  _ => currency,
};

final itemGameDataRepository = ItemGameDataRepository();
