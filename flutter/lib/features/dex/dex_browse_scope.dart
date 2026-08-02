import 'dex_game_scope.dart';
import 'dex_models.dart';
import 'dex_scope.dart';

enum DexBrowseKind { region, generation }

class DexBrowseScope {
  const DexBrowseScope.region(this.region) : generation = null;

  const DexBrowseScope.generation(this.generation) : region = null;

  final DexRegionalPokedex? region;
  final int? generation;

  DexBrowseKind get kind =>
      generation == null ? DexBrowseKind.region : DexBrowseKind.generation;

  bool matches(PokemonSummary summary) {
    final value = generation;
    if (value != null) return summary.generation == value;
    return summaryMatchesRegionalPokedex(
      summary,
      region ?? DexRegionalPokedex.national,
    );
  }

  String get titleZh {
    final value = generation;
    if (value != null) return 'G$value · ${generationLabelZh(value)}';
    final selected = region ?? DexRegionalPokedex.national;
    return '${selected.labelZh}图鉴';
  }

  String get storageValue => generation == null
      ? 'region:${(region ?? DexRegionalPokedex.national).name}'
      : 'generation:$generation';

  static DexBrowseScope? fromStorageValue(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    if (parts.first == 'generation') {
      final generation = int.tryParse(parts.last);
      if (generation != null && generation >= 1 && generation <= 9) {
        return DexBrowseScope.generation(generation);
      }
      return null;
    }
    if (parts.first == 'region') {
      final region = DexRegionalPokedex.fromStorageKey(parts.last);
      return region == null ? null : DexBrowseScope.region(region);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is DexBrowseScope &&
      other.region == region &&
      other.generation == generation;

  @override
  int get hashCode => Object.hash(region, generation);
}

String generationLabelZh(int generation) => switch (generation) {
  1 => '第一世代',
  2 => '第二世代',
  3 => '第三世代',
  4 => '第四世代',
  5 => '第五世代',
  6 => '第六世代',
  7 => '第七世代',
  8 => '第八世代',
  9 => '第九世代',
  _ => '未知世代',
};
