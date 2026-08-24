import 'dart:convert';
import 'dart:typed_data';

const journeyPackMaxBytes = 4 * 1024 * 1024;
const journeyPackSupportedBundleVersion = 20;

final _packIdPattern = RegExp(r'^[a-z0-9][a-z0-9._-]{0,79}$');
final _packFamilyPattern = RegExp(r'^[a-z0-9][a-z0-9._-]{0,39}$');
final _packVersionPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$');
final _packContentPathPattern = RegExp(
  r'^/v1/journey-packs/objects/[a-z0-9._-]+/[A-Za-z0-9._-]+\.json$',
);
final _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');
final _catalogDateTimePattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$',
);
const _supportedGames = {
  'diamond': 4,
  'pearl': 4,
  'platinum': 4,
  'heartgold': 4,
  'soulsilver': 4,
  'black': 5,
  'white': 5,
  'black-2': 5,
  'white-2': 5,
  'x': 6,
  'y': 6,
  'omega-ruby': 6,
  'alpha-sapphire': 6,
  'sun': 7,
  'moon': 7,
  'ultra-sun': 7,
  'ultra-moon': 7,
  'sword': 8,
  'shield': 8,
  'brilliant-diamond': 8,
  'shining-pearl': 8,
  'legends-arceus': 8,
  'scarlet': 9,
  'violet': 9,
};

class JourneyPackCatalog {
  const JourneyPackCatalog({required this.generatedAt, required this.packs});

  final DateTime? generatedAt;
  final List<JourneyPackDescriptor> packs;

  factory JourneyPackCatalog.fromJson(Map<String, dynamic> json) {
    if (!_hasExactKeys(json, {'schemaVersion', 'generatedAt', 'packs'}) ||
        json['schemaVersion'] != 1 ||
        json['packs'] is! List ||
        (json['packs'] as List).length > _supportedGames.length) {
      throw const FormatException('Unsupported Journey pack catalog');
    }
    final generatedAtRaw = json['generatedAt'];
    final generatedAt = generatedAtRaw is String
        ? DateTime.tryParse(generatedAtRaw)
        : null;
    if (generatedAtRaw is! String ||
        !_catalogDateTimePattern.hasMatch(generatedAtRaw) ||
        generatedAt == null ||
        !generatedAt.isUtc) {
      throw const FormatException('Invalid Journey pack catalog date');
    }
    final packs = <JourneyPackDescriptor>[];
    for (final entry in json['packs'] as List<dynamic>) {
      if (entry is! Map) {
        throw const FormatException('Invalid Journey pack catalog entry');
      }
      packs.add(
        JourneyPackDescriptor.fromJson(Map<String, dynamic>.from(entry)),
      );
    }
    final ids = <String>{};
    final families = <String>{};
    final games = <String>{};
    for (final pack in packs) {
      if (!ids.add(pack.id) ||
          !families.add(pack.gameFamily) ||
          pack.games.any((game) => !games.add(game))) {
        throw const FormatException('Duplicate Journey pack identity');
      }
    }
    return JourneyPackCatalog(generatedAt: generatedAt, packs: packs);
  }
}

class JourneyPackDescriptor {
  const JourneyPackDescriptor({
    required this.id,
    required this.gameFamily,
    required this.games,
    required this.version,
    required this.contentPath,
    required this.sizeBytes,
    required this.sha256Hex,
    required this.entryCount,
    required this.bundleVersionRequired,
    required this.titleZh,
    this.descriptionZh,
    this.minAppVersion,
  });

  final String id;
  final String gameFamily;
  final List<String> games;
  final String version;
  final String contentPath;
  final int sizeBytes;
  final String sha256Hex;
  final int entryCount;
  final int bundleVersionRequired;
  final String titleZh;
  final String? descriptionZh;
  final String? minAppVersion;

  bool get isCompatible =>
      bundleVersionRequired <= journeyPackSupportedBundleVersion;

  bool supportsGame(String? game) => game != null && games.contains(game);

  factory JourneyPackDescriptor.fromJson(Map<String, dynamic> json) {
    const requiredKeys = {
      'id',
      'gameFamily',
      'games',
      'version',
      'contentPath',
      'sizeBytes',
      'sha256',
      'titleZh',
      'entryCount',
      'bundleVersionRequired',
    };
    if (!_hasRequiredOnlyKeys(json, requiredKeys, {
      'descriptionZh',
      'minAppVersion',
    })) {
      throw const FormatException('Invalid Journey pack descriptor fields');
    }
    final id = json['id'] is String ? json['id'] as String : '';
    final gameFamily = json['gameFamily'] is String
        ? json['gameFamily'] as String
        : '';
    final version = json['version'] is String ? json['version'] as String : '';
    final contentPath = json['contentPath'] is String
        ? json['contentPath'] as String
        : '';
    final sizeBytes = (json['sizeBytes'] as num?)?.toInt() ?? 0;
    final sha256Hex = json['sha256'] is String ? json['sha256'] as String : '';
    final entryCount = (json['entryCount'] as num?)?.toInt() ?? -1;
    final bundleVersionRequired =
        (json['bundleVersionRequired'] as num?)?.toInt() ?? 20;
    final titleZh = json['titleZh'] is String
        ? (json['titleZh'] as String).trim()
        : '';
    final games = (json['games'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    if (!_packIdPattern.hasMatch(id) ||
        id.contains('..') ||
        !_packFamilyPattern.hasMatch(gameFamily) ||
        gameFamily.contains('..') ||
        !_packVersionPattern.hasMatch(version) ||
        version.contains('..') ||
        !_packContentPathPattern.hasMatch(contentPath) ||
        contentPath != '/v1/journey-packs/objects/$id/$version.json' ||
        json['sizeBytes'] is! int ||
        sizeBytes < 2 ||
        sizeBytes > journeyPackMaxBytes ||
        !_sha256Pattern.hasMatch(sha256Hex) ||
        json['entryCount'] is! int ||
        entryCount < 1 ||
        entryCount > 1000 ||
        json['bundleVersionRequired'] is! int ||
        bundleVersionRequired < 20 ||
        titleZh.isEmpty ||
        titleZh.length > 80 ||
        games.isEmpty ||
        json['games'] is! List ||
        (json['games'] as List).length != games.length ||
        games.toSet().length != games.length ||
        games.any((game) => !_supportedGames.containsKey(game)) ||
        (json['descriptionZh'] != null &&
            (json['descriptionZh'] is! String ||
                (json['descriptionZh'] as String).isEmpty ||
                (json['descriptionZh'] as String).length > 180)) ||
        (json['minAppVersion'] != null &&
            (json['minAppVersion'] is! String ||
                !RegExp(
                  r'^\d+\.\d+\.\d+$',
                ).hasMatch(json['minAppVersion'] as String)))) {
      throw const FormatException('Invalid Journey pack descriptor');
    }
    return JourneyPackDescriptor(
      id: id,
      gameFamily: gameFamily,
      games: List.unmodifiable(games),
      version: version,
      contentPath: contentPath,
      sizeBytes: sizeBytes,
      sha256Hex: sha256Hex,
      entryCount: entryCount,
      bundleVersionRequired: bundleVersionRequired,
      titleZh: titleZh,
      descriptionZh: json['descriptionZh'] as String?,
      minAppVersion: json['minAppVersion'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'gameFamily': gameFamily,
    'games': games,
    'version': version,
    'contentPath': contentPath,
    'sizeBytes': sizeBytes,
    'sha256': sha256Hex,
    'entryCount': entryCount,
    'bundleVersionRequired': bundleVersionRequired,
    'titleZh': titleZh,
    if (descriptionZh != null) 'descriptionZh': descriptionZh,
    if (minAppVersion != null) 'minAppVersion': minAppVersion,
  };

  JourneyPackReference toRequestReference() => JourneyPackReference._(
    id: id,
    gameFamily: gameFamily,
    version: version,
    sha256Hex: sha256Hex,
  );
}

class JourneyPackDocument {
  const JourneyPackDocument({
    required this.id,
    required this.gameFamily,
    required this.version,
    required this.entries,
    this.sourceAsOf,
  });

  final String id;
  final String gameFamily;
  final String version;
  final String? sourceAsOf;
  final List<Map<String, dynamic>> entries;

  factory JourneyPackDocument.fromBytes(
    Uint8List bytes, {
    required JourneyPackDescriptor descriptor,
  }) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('Journey pack must be an object');
    }
    final json = Map<String, dynamic>.from(decoded);
    if (!_hasRequiredOnlyKeys(
          json,
          {'schemaVersion', 'id', 'gameFamily', 'games', 'version', 'entries'},
          {'sourceAsOf'},
        ) ||
        json['schemaVersion'] != 1 ||
        json['entries'] is! List ||
        (json['sourceAsOf'] != null && !_isIsoDate(json['sourceAsOf']))) {
      throw const FormatException('Unsupported Journey pack');
    }
    final entries = (json['entries'] as List<dynamic>)
        .map((entry) {
          if (entry is! Map) {
            throw const FormatException('Journey pack entry must be an object');
          }
          return Map<String, dynamic>.from(entry);
        })
        .toList(growable: false);
    final id = json['id'] is String ? json['id'] as String : '';
    final gameFamily = json['gameFamily'] is String
        ? json['gameFamily'] as String
        : '';
    final version = json['version'] is String ? json['version'] as String : '';
    final games = (json['games'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    if (id != descriptor.id ||
        gameFamily != descriptor.gameFamily ||
        version != descriptor.version ||
        json['games'] is! List ||
        (json['games'] as List).length != games.length ||
        games.length != descriptor.games.length ||
        !_sameStrings(games, descriptor.games) ||
        entries.length != descriptor.entryCount) {
      throw const FormatException('Journey pack does not match catalog');
    }
    final entryIds = <String>{};
    for (final entry in entries) {
      _validateProgressionHint(entry, descriptor);
      if (!entryIds.add(entry['id'] as String)) {
        throw const FormatException('Duplicate Journey hint id');
      }
    }
    return JourneyPackDocument(
      id: id,
      gameFamily: gameFamily,
      version: version,
      sourceAsOf: json['sourceAsOf'] as String?,
      entries: List.unmodifiable(entries),
    );
  }
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

void _validateProgressionHint(
  Map<String, dynamic> entry,
  JourneyPackDescriptor descriptor,
) {
  const keys = {
    'id',
    'games',
    'generation',
    'locations',
    'locationAliases',
    'destinationAliases',
    'subject',
    'requirements',
    'steps',
    'overviewZh',
    'sources',
  };
  if (!_hasExactKeys(entry, keys) ||
      !_validId(entry['id']) ||
      entry['games'] is! List ||
      entry['generation'] is! int ||
      !_stringList(entry['locations'], unique: true) ||
      !_stringList(entry['locationAliases']) ||
      !_stringList(entry['destinationAliases']) ||
      !_boundedString(entry['overviewZh'], 1, 180)) {
    throw const FormatException('Invalid Journey progression hint');
  }
  final games = (entry['games'] as List).whereType<String>().toList();
  if (games.isEmpty ||
      games.length != (entry['games'] as List).length ||
      games.toSet().length != games.length ||
      games.any(
        (game) =>
            !descriptor.games.contains(game) ||
            _supportedGames[game] != entry['generation'],
      )) {
    throw const FormatException('Journey hint game mismatch');
  }

  final subjectValue = entry['subject'];
  if (subjectValue is! Map) {
    throw const FormatException('Invalid Journey hint subject');
  }
  final subject = Map<String, dynamic>.from(subjectValue);
  if (!_hasExactKeys(subject, {'type', 'id', 'labelZh', 'aliases'}) ||
      !const {
        'overworld_blocker',
        'story_blocker',
        'reference_topic',
      }.contains(subject['type']) ||
      !_validId(subject['id']) ||
      !_boundedString(subject['labelZh'], 1, 80) ||
      !_stringList(subject['aliases'], minItems: 1)) {
    throw const FormatException('Invalid Journey hint subject');
  }

  final requirements = entry['requirements'];
  if (requirements is! List) {
    throw const FormatException('Invalid Journey hint requirements');
  }
  for (final value in requirements) {
    if (value is! Map) {
      throw const FormatException('Invalid Journey hint requirement');
    }
    final requirement = Map<String, dynamic>.from(value);
    if (!_hasRequiredOnlyKeys(
          requirement,
          {'type', 'id', 'labelZh', 'reliability'},
          {'itemId'},
        ) ||
        !const {
          'badge',
          'key_item',
          'milestone',
        }.contains(requirement['type']) ||
        !_validId(requirement['id']) ||
        !_boundedString(requirement['labelZh'], 1, 80) ||
        !const {
          'save_verified',
          'not_currently_parsed',
        }.contains(requirement['reliability']) ||
        (requirement['itemId'] != null &&
            (requirement['itemId'] is! int ||
                (requirement['itemId'] as int) < 1))) {
      throw const FormatException('Invalid Journey hint requirement');
    }
  }

  final steps = entry['steps'];
  if (steps is! List || steps.isEmpty) {
    throw const FormatException('Invalid Journey hint steps');
  }
  for (final value in steps) {
    if (value is! Map) {
      throw const FormatException('Invalid Journey hint step');
    }
    final step = Map<String, dynamic>.from(value);
    if (!_hasExactKeys(step, {
          'order',
          'action',
          'targetId',
          'locationId',
          'instructionZh',
        }) ||
        step['order'] is! int ||
        (step['order'] as int) < 1 ||
        step['action'] is! String ||
        !RegExp(r'^[a-z0-9_]+$').hasMatch(step['action'] as String) ||
        !_validId(step['targetId']) ||
        !_boundedString(step['locationId'], 1, 120) ||
        !_boundedString(step['instructionZh'], 1, 120)) {
      throw const FormatException('Invalid Journey hint step');
    }
  }

  final sources = entry['sources'];
  if (sources is! List || sources.isEmpty) {
    throw const FormatException('Invalid Journey hint sources');
  }
  for (final value in sources) {
    if (value is! Map) {
      throw const FormatException('Invalid Journey hint source');
    }
    final source = Map<String, dynamic>.from(value);
    final uri = Uri.tryParse(source['url'] as String? ?? '');
    if (!_hasExactKeys(source, {'title', 'url', 'accessedAt'}) ||
        !_boundedString(source['title'], 1, 180) ||
        !_boundedString(source['url'], 1, 600) ||
        uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        !_isIsoDate(source['accessedAt'])) {
      throw const FormatException('Invalid Journey hint source');
    }
  }
}

bool _hasExactKeys(Map<String, dynamic> value, Set<String> expected) =>
    value.length == expected.length && value.keys.toSet().containsAll(expected);

bool _hasRequiredOnlyKeys(
  Map<String, dynamic> value,
  Set<String> required,
  Set<String> optional,
) =>
    value.keys.toSet().containsAll(required) &&
    value.keys.every((key) => required.contains(key) || optional.contains(key));

bool _boundedString(Object? value, int minimum, int maximum) =>
    value is String && value.length >= minimum && value.length <= maximum;

bool _validId(Object? value) =>
    value is String && RegExp(r'^[a-z0-9_-]+$').hasMatch(value);

bool _stringList(Object? value, {int minItems = 0, bool unique = false}) {
  if (value is! List || value.length < minItems) return false;
  final strings = value.whereType<String>().toList();
  return strings.length == value.length &&
      (!unique || strings.toSet().length == strings.length) &&
      strings.every((item) => item.isNotEmpty && item.length <= 80);
}

bool _isIsoDate(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return false;
  }
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  return parsed != null && parsed.toIso8601String().startsWith(value);
}

class InstalledJourneyPack {
  const InstalledJourneyPack({
    required this.descriptor,
    required this.installedAt,
    required this.objectPath,
    required this.document,
  });

  final JourneyPackDescriptor descriptor;
  final DateTime installedAt;
  final String objectPath;
  final JourneyPackDocument document;

  JourneyPackReference toRequestReference() => descriptor.toRequestReference();
}

/// A bounded Worker reference created from a validated catalog descriptor.
/// Pack entries and local paths never enter the ask contract.
class JourneyPackReference {
  const JourneyPackReference._({
    required this.id,
    required this.gameFamily,
    required this.version,
    required this.sha256Hex,
  });

  final String id;
  final String gameFamily;
  final String version;
  final String sha256Hex;

  Map<String, String> toJson() => {
    'id': id,
    'gameFamily': gameFamily,
    'version': version,
    'sha256': sha256Hex,
  };
}

enum JourneyPackAvailability {
  notInstalled,
  installed,
  updateAvailable,
  incompatible,
  corrupt,
}
