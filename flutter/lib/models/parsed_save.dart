class ParsedPartyMember {
  const ParsedPartyMember({
    required this.speciesId,
    required this.speciesName,
    this.level,
    this.currentHp,
    this.maxHp,
    this.experience,
    this.warning,
  });

  final int speciesId;
  final String speciesName;
  final int? level;
  final int? currentHp;
  final int? maxHp;
  final int? experience;
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
    this.warnings = const [],
    this.tid,
    this.mapHeaderId,
    this.dexCaughtIds = const {},
    this.dexSeenIds = const {},
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
  final List<String> warnings;
  final int? tid;
  final int? mapHeaderId;
  final Set<int> dexCaughtIds;
  final Set<int> dexSeenIds;
}
