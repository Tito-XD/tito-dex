class PartyMember {
  const PartyMember({
    required this.species,
    this.speciesId,
    this.level,
    this.nickname,
    this.currentHp,
    this.maxHp,
    this.experience,
    this.types = const [],
    this.abilitySlug,
    this.userEdited = false,
  });

  final String species;
  final int? speciesId;
  final int? level;
  final String? nickname;
  final int? currentHp;
  final int? maxHp;
  final int? experience;
  final List<String> types;
  final String? abilitySlug;
  final bool userEdited;

  Map<String, dynamic> toJson() => {
        'species': species,
        if (speciesId != null) 'speciesId': speciesId,
        if (level != null) 'level': level,
        if (nickname != null) 'nickname': nickname,
        if (currentHp != null) 'currentHp': currentHp,
        if (maxHp != null) 'maxHp': maxHp,
        if (experience != null) 'experience': experience,
        if (types.isNotEmpty) 'types': types,
        if (abilitySlug != null) 'abilitySlug': abilitySlug,
        if (userEdited) 'userEdited': true,
      };

  factory PartyMember.fromJson(Map<String, dynamic> json) => PartyMember(
        species: json['species'] as String,
        speciesId: json['speciesId'] as int?,
        level: json['level'] as int?,
        nickname: json['nickname'] as String?,
        currentHp: json['currentHp'] as int?,
        maxHp: json['maxHp'] as int?,
        experience: json['experience'] as int?,
        types: (json['types'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        abilitySlug: json['abilitySlug'] as String?,
        userEdited: json['userEdited'] as bool? ?? false,
      );

  PartyMember copyWith({
    String? species,
    int? speciesId,
    int? level,
    String? nickname,
    int? currentHp,
    int? maxHp,
    int? experience,
    List<String>? types,
    String? abilitySlug,
    bool? userEdited,
    bool clearNickname = false,
    bool clearAbilitySlug = false,
  }) {
    return PartyMember(
      species: species ?? this.species,
      speciesId: speciesId ?? this.speciesId,
      level: level ?? this.level,
      nickname: clearNickname ? null : (nickname ?? this.nickname),
      currentHp: currentHp ?? this.currentHp,
      maxHp: maxHp ?? this.maxHp,
      experience: experience ?? this.experience,
      types: types ?? this.types,
      abilitySlug:
          clearAbilitySlug ? null : (abilitySlug ?? this.abilitySlug),
      userEdited: userEdited ?? this.userEdited,
    );
  }
}

class JourneyTimelineEntry {
  const JourneyTimelineEntry({
    required this.id,
    required this.text,
    this.at,
  });

  final String id;
  final String text;
  final String? at;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        if (at != null) 'at': at,
      };

  factory JourneyTimelineEntry.fromJson(Map<String, dynamic> json) =>
      JourneyTimelineEntry(
        id: json['id'] as String,
        text: json['text'] as String,
        at: json['at'] as String?,
      );
}

class CurrentJourney {
  const CurrentJourney({
    required this.game,
    required this.trainerName,
    required this.location,
    required this.badges,
    required this.maxBadges,
    required this.playTime,
    required this.party,
    required this.timeline,
    required this.companion,
    this.nextReminder,
    this.saveTrainerName,
    this.trainerNameCustomized = false,
    this.trainerAvatarPath,
    this.trainerAvatarCustomized = false,
    this.saveDexCaughtIds = const [],
    this.saveDexSeenIds = const [],
    this.saveDexHash,
    this.manualDexSeenIds = const [],
    this.manualDexCaughtIds = const [],
    this.saveSyncedParty = const [],
    this.partyUserOverride = false,
  });

  final String game;
  final String trainerName;
  final String location;
  final int badges;
  final int maxBadges;
  final String playTime;
  final List<PartyMember> party;
  final List<JourneyTimelineEntry> timeline;
  final String companion;
  final String? nextReminder;
  final String? saveTrainerName;
  final bool trainerNameCustomized;
  final String? trainerAvatarPath;
  final bool trainerAvatarCustomized;
  final List<int> saveDexCaughtIds;
  final List<int> saveDexSeenIds;
  final String? saveDexHash;
  final List<int> manualDexSeenIds;
  final List<int> manualDexCaughtIds;
  /// Last party parsed from save (for diff banner).
  final List<PartyMember> saveSyncedParty;
  final bool partyUserOverride;

  bool get partyDiffersFromSave {
    if (!partyUserOverride || saveSyncedParty.isEmpty) {
      return false;
    }
    return !_partyListsEqual(party, saveSyncedParty);
  }

  static bool _partyListsEqual(List<PartyMember> a, List<PartyMember> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.speciesId != right.speciesId ||
          left.species != right.species ||
          left.level != right.level) {
        return false;
      }
    }
    return true;
  }

  CurrentJourney copyWith({
    String? game,
    String? trainerName,
    String? location,
    int? badges,
    int? maxBadges,
    String? playTime,
    List<PartyMember>? party,
    List<JourneyTimelineEntry>? timeline,
    String? companion,
    String? nextReminder,
    String? saveTrainerName,
    bool? trainerNameCustomized,
    String? trainerAvatarPath,
    bool? trainerAvatarCustomized,
    List<int>? saveDexCaughtIds,
    List<int>? saveDexSeenIds,
    String? saveDexHash,
    List<int>? manualDexSeenIds,
    List<int>? manualDexCaughtIds,
    List<PartyMember>? saveSyncedParty,
    bool? partyUserOverride,
  }) {
    return CurrentJourney(
      game: game ?? this.game,
      trainerName: trainerName ?? this.trainerName,
      location: location ?? this.location,
      badges: badges ?? this.badges,
      maxBadges: maxBadges ?? this.maxBadges,
      playTime: playTime ?? this.playTime,
      party: party ?? this.party,
      timeline: timeline ?? this.timeline,
      companion: companion ?? this.companion,
      nextReminder: nextReminder ?? this.nextReminder,
      saveTrainerName: saveTrainerName ?? this.saveTrainerName,
      trainerNameCustomized:
          trainerNameCustomized ?? this.trainerNameCustomized,
      trainerAvatarPath: trainerAvatarPath ?? this.trainerAvatarPath,
      trainerAvatarCustomized:
          trainerAvatarCustomized ?? this.trainerAvatarCustomized,
      saveDexCaughtIds: saveDexCaughtIds ?? this.saveDexCaughtIds,
      saveDexSeenIds: saveDexSeenIds ?? this.saveDexSeenIds,
      saveDexHash: saveDexHash ?? this.saveDexHash,
      manualDexSeenIds: manualDexSeenIds ?? this.manualDexSeenIds,
      manualDexCaughtIds: manualDexCaughtIds ?? this.manualDexCaughtIds,
      saveSyncedParty: saveSyncedParty ?? this.saveSyncedParty,
      partyUserOverride: partyUserOverride ?? this.partyUserOverride,
    );
  }

  Map<String, dynamic> toJson() => {
        'game': game,
        'trainerName': trainerName,
        'location': location,
        'badges': badges,
        'maxBadges': maxBadges,
        'playTime': playTime,
        'party': party.map((member) => member.toJson()).toList(),
        'timeline': timeline.map((entry) => entry.toJson()).toList(),
        'companion': companion,
        if (nextReminder != null) 'nextReminder': nextReminder,
        if (saveTrainerName != null) 'saveTrainerName': saveTrainerName,
        if (trainerNameCustomized) 'trainerNameCustomized': true,
        if (trainerAvatarPath != null) 'trainerAvatarPath': trainerAvatarPath,
        if (trainerAvatarCustomized) 'trainerAvatarCustomized': true,
        if (saveDexCaughtIds.isNotEmpty)
          'saveDexCaughtIds': saveDexCaughtIds,
        if (saveDexSeenIds.isNotEmpty) 'saveDexSeenIds': saveDexSeenIds,
        if (saveDexHash != null) 'saveDexHash': saveDexHash,
        if (manualDexSeenIds.isNotEmpty) 'manualDexSeenIds': manualDexSeenIds,
        if (manualDexCaughtIds.isNotEmpty)
          'manualDexCaughtIds': manualDexCaughtIds,
        if (saveSyncedParty.isNotEmpty)
          'saveSyncedParty':
              saveSyncedParty.map((m) => m.toJson()).toList(growable: false),
        if (partyUserOverride) 'partyUserOverride': true,
      };

  factory CurrentJourney.fromJson(Map<String, dynamic> json) => CurrentJourney(
        game: json['game'] as String,
        trainerName: json['trainerName'] as String,
        location: json['location'] as String,
        badges: json['badges'] as int,
        maxBadges: json['maxBadges'] as int,
        playTime: json['playTime'] as String,
        party: (json['party'] as List<dynamic>)
            .map((item) => PartyMember.fromJson(item as Map<String, dynamic>))
            .toList(),
        timeline: (json['timeline'] as List<dynamic>)
            .map(
              (item) =>
                  JourneyTimelineEntry.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        companion: json['companion'] as String,
        nextReminder: json['nextReminder'] as String?,
        saveTrainerName: json['saveTrainerName'] as String?,
        trainerNameCustomized: json['trainerNameCustomized'] as bool? ?? false,
        trainerAvatarPath: json['trainerAvatarPath'] as String?,
        trainerAvatarCustomized:
            json['trainerAvatarCustomized'] as bool? ?? false,
        saveDexCaughtIds: (json['saveDexCaughtIds'] as List<dynamic>? ?? const [])
            .map((value) => (value as num).toInt())
            .toList(),
        saveDexSeenIds: (json['saveDexSeenIds'] as List<dynamic>? ?? const [])
            .map((value) => (value as num).toInt())
            .toList(),
        saveDexHash: json['saveDexHash'] as String?,
        manualDexSeenIds:
            (json['manualDexSeenIds'] as List<dynamic>? ?? const [])
                .map((value) => (value as num).toInt())
                .toList(),
        manualDexCaughtIds:
            (json['manualDexCaughtIds'] as List<dynamic>? ?? const [])
                .map((value) => (value as num).toInt())
                .toList(),
        saveSyncedParty: (json['saveSyncedParty'] as List<dynamic>? ?? const [])
            .map((item) => PartyMember.fromJson(item as Map<String, dynamic>))
            .toList(),
        partyUserOverride: json['partyUserOverride'] as bool? ?? false,
      );

  static CurrentJourney mock() => const CurrentJourney(
        game: 'SoulSilver',
        trainerName: 'Tito',
        location: '满金市',
        badges: 3,
        maxBadges: 8,
        playTime: '18:42',
        companion: 'Cyndaquil',
        nextReminder: '准备好就去广播塔看看',
        party: [
          PartyMember(
            species: 'Quilava',
            speciesId: 156,
            level: 24,
            nickname: 'Quilava',
            currentHp: 68,
            maxHp: 72,
            experience: 13824,
          ),
          PartyMember(
            species: 'Riolu',
            speciesId: 447,
            level: 18,
            nickname: 'Riolu',
            currentHp: 42,
            maxHp: 48,
            experience: 5832,
          ),
          PartyMember(
            species: 'Flaaffy',
            speciesId: 180,
            level: 21,
            currentHp: 55,
            maxHp: 60,
            experience: 9261,
          ),
          PartyMember(
            species: 'Togepi',
            speciesId: 175,
            level: 15,
            currentHp: 38,
            maxHp: 42,
            experience: 3375,
          ),
        ],
        timeline: [
          JourneyTimelineEntry(
            id: 't1',
            text: '抵达满金市',
            at: '2026-04-15 14:22',
          ),
          JourneyTimelineEntry(
            id: 't2',
            text: '获得蜂巢徽章',
            at: '2026-04-14 09:05',
          ),
          JourneyTimelineEntry(
            id: 't3',
            text: '火球鼠一直跟在身旁',
            at: '2026-04-13 18:40',
          ),
        ],
      );
}
