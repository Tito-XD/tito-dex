/// Increment when parsing semantics change so unchanged files are re-imported
/// once after an app upgrade.
const saveParserRevision = 4;

class ParsedPartyMember {
  const ParsedPartyMember({
    required this.speciesId,
    required this.speciesName,
    this.level,
    this.currentHp,
    this.maxHp,
    this.experience,
    this.abilityId,
    this.moveIds = const [],
    this.nickname,
    this.heldItemId,
    this.friendship,
    this.nature,
    this.isShiny = false,
    this.gender,
    this.status,
    this.movePp = const [],
    this.movePpUps = const [],
    this.ivs = const [],
    this.evs = const [],
    this.battleStats = const {},
    this.isEgg = false,
    this.formIndex = 0,
    this.warning,
  });

  final int speciesId;
  final String speciesName;
  final int? level;
  final int? currentHp;
  final int? maxHp;
  final int? experience;
  final int? abilityId;
  final List<int> moveIds;
  final String? nickname;
  final int? heldItemId;
  final int? friendship;
  final String? nature;
  final bool isShiny;
  final String? gender;
  final String? status;
  final List<int> movePp;
  final List<int> movePpUps;
  final List<int> ivs;
  final List<int> evs;
  final Map<String, int> battleStats;
  final bool isEgg;
  final int formIndex;
  final String? warning;
}

class ParsedSaveSummary {
  const ParsedSaveSummary({
    required this.game,
    required this.trainerName,
    required this.playTime,
    required this.badges,
    required this.maxBadges,
    required this.locationLabel,
    required this.party,
    required this.saveHash,
    required this.parsedAt,
    this.savedAt,
    this.warnings = const [],
    this.tid,
    this.secretId,
    this.money,
    this.motherMoney,
    this.trainerGender,
    this.language,
    this.starterSpeciesId,
    this.mapCoordinates = const [],
    this.adventureStartedAt,
    this.leagueChampionAt,
    this.mapHeaderId,
    this.dexCaughtIds = const {},
    this.dexSeenIds = const {},
    this.badgeProgress = const {},
  });

  final String game;
  final String trainerName;
  final String playTime;
  final int badges;
  final int maxBadges;
  final String locationLabel;
  final List<ParsedPartyMember> party;
  final String saveHash;
  final DateTime parsedAt;

  /// Best available save timestamp: embedded game timestamp when present,
  /// otherwise the source file's modified time. This is intentionally
  /// separate from [parsedAt], which only records when TitoDex imported it.
  final DateTime? savedAt;
  final List<String> warnings;
  final int? tid;
  final int? secretId;
  final int? money;
  final int? motherMoney;
  final String? trainerGender;
  final String? language;
  final int? starterSpeciesId;
  final List<int> mapCoordinates;
  final DateTime? adventureStartedAt;
  final DateTime? leagueChampionAt;
  final int? mapHeaderId;
  final Set<int> dexCaughtIds;
  final Set<int> dexSeenIds;

  /// Region-specific badge banks when the save format exposes them (HGSS has
  /// eight Johto plus eight Kanto badges). Empty for single-bank games.
  final Map<String, int> badgeProgress;
}
