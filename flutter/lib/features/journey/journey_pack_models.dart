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
const _supportedGames = {
  'diamond',
  'pearl',
  'platinum',
  'heartgold',
  'soulsilver',
  'black',
  'white',
  'black-2',
  'white-2',
  'x',
  'y',
  'omega-ruby',
  'alpha-sapphire',
  'sun',
  'moon',
  'ultra-sun',
  'ultra-moon',
  'sword',
  'shield',
  'brilliant-diamond',
  'shining-pearl',
  'legends-arceus',
  'scarlet',
  'violet',
};

class JourneyPackCatalog {
  const JourneyPackCatalog({required this.generatedAt, required this.packs});

  final DateTime? generatedAt;
  final List<JourneyPackDescriptor> packs;

  factory JourneyPackCatalog.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 || json['packs'] is! List) {
      throw const FormatException('Unsupported Journey pack catalog');
    }
    final generatedAt = DateTime.tryParse(json['generatedAt'] as String? ?? '');
    if (generatedAt == null) {
      throw const FormatException('Invalid Journey pack catalog date');
    }
    final packs = (json['packs'] as List<dynamic>)
        .whereType<Map>()
        .map(
          (entry) =>
              JourneyPackDescriptor.fromJson(Map<String, dynamic>.from(entry)),
        )
        .toList(growable: false);
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
    final id = json['id'] as String? ?? '';
    final gameFamily = json['gameFamily'] as String? ?? '';
    final version = json['version']?.toString() ?? '';
    final contentPath = json['contentPath'] as String? ?? '';
    final sizeBytes = (json['sizeBytes'] as num?)?.toInt() ?? 0;
    final sha256Hex = (json['sha256'] as String? ?? '').trim().toLowerCase();
    final entryCount = (json['entryCount'] as num?)?.toInt() ?? -1;
    final bundleVersionRequired =
        (json['bundleVersionRequired'] as num?)?.toInt() ?? 20;
    final titleZh = (json['titleZh'] as String? ?? '').trim();
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
        sizeBytes < 2 ||
        sizeBytes > journeyPackMaxBytes ||
        !_sha256Pattern.hasMatch(sha256Hex) ||
        entryCount < 1 ||
        entryCount > 1000 ||
        bundleVersionRequired < 20 ||
        titleZh.isEmpty ||
        titleZh.length > 80 ||
        games.isEmpty ||
        games.toSet().length != games.length ||
        games.any((game) => !_supportedGames.contains(game)) ||
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
    if (json['schemaVersion'] != 1 || json['entries'] is! List) {
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
    final id = json['id'] as String? ?? '';
    final gameFamily = json['gameFamily'] as String? ?? '';
    final version = json['version']?.toString() ?? '';
    final games = (json['games'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    if (id != descriptor.id ||
        gameFamily != descriptor.gameFamily ||
        version != descriptor.version ||
        games.length != descriptor.games.length ||
        !_sameStrings(games, descriptor.games) ||
        entries.length != descriptor.entryCount) {
      throw const FormatException('Journey pack does not match catalog');
    }
    for (final entry in entries) {
      final entryType = entry['entryType'];
      final legacyProgressionHint =
          entryType == null && _looksLikeProgressionHint(entry);
      if (!legacyProgressionHint &&
          entryType != 'progression_hint' &&
          entryType != 'fact') {
        throw const FormatException('Unsupported Journey pack entry');
      }
      if (legacyProgressionHint || entryType == 'progression_hint') {
        final games = entry['games'];
        if (games is! List ||
            games.isEmpty ||
            games.any(
              (game) => game is! String || !descriptor.games.contains(game),
            )) {
          throw const FormatException('Journey hint game mismatch');
        }
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

bool _looksLikeProgressionHint(Map<String, dynamic> entry) =>
    entry['id'] is String &&
    entry['games'] is List &&
    entry['generation'] is num &&
    entry['locations'] is List &&
    entry['locationAliases'] is List &&
    entry['destinationAliases'] is List &&
    entry['subject'] is Map &&
    entry['requirements'] is List &&
    entry['steps'] is List &&
    entry['overviewZh'] is String &&
    entry['sources'] is List;

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
