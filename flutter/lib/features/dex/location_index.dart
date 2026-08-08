import '../game/game_edition.dart';
import 'dex_cdn_data_source.dart';
import 'dex_offline_service.dart';

class LocationEncounterEntry {
  const LocationEncounterEntry({
    required this.speciesId,
    this.pokemonId,
    this.formKey,
    this.teraType,
    this.isAlpha = false,
    this.isTitan = false,
    this.isTotem = false,
    this.isRaid = false,
    this.isFixedEncounter = false,
    this.formAmbiguous = false,
    this.methods = const [],
    this.conditions = const [],
    this.minLevel,
    this.maxLevel,
    this.maxChance = 0,
    this.rateKind = 'percentage',
    this.rateValue,
  });

  final int speciesId;
  final int? pokemonId;
  final String? formKey;
  final String? teraType;
  final bool isAlpha;
  final bool isTitan;
  final bool isTotem;
  final bool isRaid;
  final bool isFixedEncounter;
  final bool formAmbiguous;
  final List<String> methods;
  final List<String> conditions;
  final int? minLevel;
  final int? maxLevel;
  final int maxChance;
  final String rateKind;
  final num? rateValue;

  String get identity => [
    speciesId,
    formKey ?? '',
    methods.join(','),
    conditions.join(','),
    minLevel ?? '',
    maxLevel ?? '',
  ].join('|');

  factory LocationEncounterEntry.fromJson(Map<String, dynamic> json) {
    return LocationEncounterEntry(
      speciesId: (json['speciesId'] as num).toInt(),
      pokemonId: (json['pokemonId'] as num?)?.toInt(),
      formKey: json['formKey'] as String?,
      teraType: json['teraType'] as String?,
      isAlpha: json['isAlpha'] as bool? ?? false,
      isTitan: json['isTitan'] as bool? ?? false,
      isTotem: json['isTotem'] as bool? ?? false,
      isRaid: json['isRaid'] as bool? ?? false,
      isFixedEncounter: json['isFixedEncounter'] as bool? ?? false,
      formAmbiguous: json['formAmbiguous'] as bool? ?? false,
      methods: (json['methods'] as List<dynamic>? ?? const []).cast<String>(),
      conditions: (json['conditions'] as List<dynamic>? ?? const [])
          .cast<String>(),
      minLevel: (json['minLevel'] as num?)?.toInt(),
      maxLevel: (json['maxLevel'] as num?)?.toInt(),
      maxChance: (json['maxChance'] as num?)?.toInt() ?? 0,
      rateKind: json['rateKind'] as String? ?? 'percentage',
      rateValue: json['rateValue'] as num?,
    );
  }
}

class LocationArea {
  const LocationArea({
    required this.slug,
    required this.labelZh,
    required this.entries,
  });

  final String slug;
  final String labelZh;
  final List<LocationEncounterEntry> entries;

  int caughtCount(Set<int> caughtIds) => entries
      .map((entry) => entry.speciesId)
      .toSet()
      .intersection(caughtIds)
      .length;

  int get speciesCount =>
      entries.map((entry) => entry.speciesId).toSet().length;
}

class LocationIndex {
  const LocationIndex({required this.byVersion});

  final Map<String, List<LocationArea>> byVersion;

  factory LocationIndex.fromJson(Map<String, dynamic> json) {
    final rawVersions = json['byVersion'];
    if (json['version'] != 1 || rawVersions is! Map) {
      throw const FormatException('Unsupported location index.');
    }
    return LocationIndex(
      byVersion: {
        for (final version in rawVersions.entries)
          version.key.toString(): _decodeAreas(version.value),
      },
    );
  }

  static List<LocationArea> _decodeAreas(Object? raw) {
    if (raw is! Map) {
      return const [];
    }
    final result = <LocationArea>[];
    for (final areaEntry in raw.entries) {
      final value = areaEntry.value;
      if (value is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(value);
      result.add(
        LocationArea(
          slug: areaEntry.key.toString(),
          labelZh: (map['labelZh'] as String?)?.trim().isNotEmpty == true
              ? map['labelZh'] as String
              : areaEntry.key.toString(),
          entries: (map['entries'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (entry) => LocationEncounterEntry.fromJson(
                  Map<String, dynamic>.from(entry),
                ),
              )
              .toList(growable: false),
        ),
      );
    }
    result.sort((a, b) => a.labelZh.compareTo(b.labelZh));
    return result;
  }

  List<LocationArea> areasForEdition(GameEdition edition) {
    final keys = edition.selectedFlavor != null
        ? [edition.selectedFlavor!]
        : edition.flavorVersions.isNotEmpty
        ? edition.flavorVersions
        : [edition.dataVersionGroupKey];
    final merged = <String, _MutableLocationArea>{};
    for (final key in keys) {
      for (final area in byVersion[key] ?? const <LocationArea>[]) {
        final target = merged.putIfAbsent(
          area.slug,
          () => _MutableLocationArea(area.slug, area.labelZh),
        );
        for (final entry in area.entries) {
          target.entries.putIfAbsent(entry.identity, () => entry);
        }
      }
    }
    final result = merged.values
        .map(
          (area) => LocationArea(
            slug: area.slug,
            labelZh: area.labelZh,
            entries: area.entries.values.toList(growable: false),
          ),
        )
        .toList();
    result.sort((a, b) => a.labelZh.compareTo(b.labelZh));
    return result;
  }
}

class _MutableLocationArea {
  _MutableLocationArea(this.slug, this.labelZh);

  final String slug;
  final String labelZh;
  final Map<String, LocationEncounterEntry> entries = {};
}

class LocationIndexRepository {
  LocationIndexRepository({DexOfflineService? offline, DexCdnDataSource? cdn})
    : _offline = offline ?? dexOfflineService,
      _cdn = cdn ?? DexCdnDataSource();

  final DexOfflineService _offline;
  final DexCdnDataSource _cdn;
  Future<LocationIndex>? _cached;

  Future<LocationIndex> load() =>
      _cached ??= _load().catchError((Object error) {
        _cached = null;
        throw error;
      });

  Future<LocationIndex> _load() async {
    if (await _offline.isReady() || await _offline.shouldPreferOffline()) {
      final local = await _offline.readReferenceObject('location_index.json');
      if (local.isNotEmpty) {
        return LocationIndex.fromJson(local);
      }
    }
    try {
      return LocationIndex.fromJson(
        await _cdn.fetchReferenceObject('location_index.json'),
      );
    } catch (_) {
      final local = await _offline.readReferenceObject('location_index.json');
      if (local.isNotEmpty) {
        return LocationIndex.fromJson(local);
      }
      rethrow;
    }
  }
}

final locationIndexRepository = LocationIndexRepository();
