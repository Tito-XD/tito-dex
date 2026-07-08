class PartyMember {
  const PartyMember({
    required this.species,
    this.level,
    this.nickname,
  });

  final String species;
  final int? level;
  final String? nickname;

  Map<String, dynamic> toJson() => {
        'species': species,
        if (level != null) 'level': level,
        if (nickname != null) 'nickname': nickname,
      };

  factory PartyMember.fromJson(Map<String, dynamic> json) => PartyMember(
        species: json['species'] as String,
        level: json['level'] as int?,
        nickname: json['nickname'] as String?,
      );
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
          PartyMember(species: 'Quilava', level: 24, nickname: 'Quilava'),
          PartyMember(species: 'Riolu', level: 18, nickname: 'Riolu'),
          PartyMember(species: 'Flaaffy', level: 21),
          PartyMember(species: 'Togepi', level: 15),
        ],
        timeline: [
          JourneyTimelineEntry(
            id: 't1',
            text: '抵达满金市',
            at: '第 4 天',
          ),
          JourneyTimelineEntry(id: 't2', text: '获得蜂巢徽章', at: '第 3 天'),
          JourneyTimelineEntry(
            id: 't3',
            text: '火球鼠一直跟在身旁',
            at: '第 2 天',
          ),
        ],
      );
}
