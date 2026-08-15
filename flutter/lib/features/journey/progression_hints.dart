import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/journey.dart';
import '../../models/parsed_save.dart';
import '../extensions/journey_assistant_extension.dart';
import '../game/game_edition.dart';

enum AskTitoDexStatus { answered, needsClarification, noMatch, failed }

enum AskTitoDexAnswerMode {
  localAudited('local_audited'),
  auditedOnline('audited_online'),
  aiSearchAudited('ai_search_audited'),
  curatedSourcesDeterministic('curated_sources_deterministic'),
  curatedSourcesQwen('curated_sources_qwen'),
  deepseekNativeSearch('deepseek_native_search'),
  multiSourceQwen('multi_source_qwen'),
  noMatch('no_match');

  const AskTitoDexAnswerMode(this.wireValue);

  final String wireValue;

  static AskTitoDexAnswerMode fromWire(
    Object? value, {
    required bool onlineComposed,
    required List<String> matchedHintIds,
  }) {
    for (final mode in values) {
      if (mode.wireValue == value) return mode;
    }
    if (!onlineComposed) return AskTitoDexAnswerMode.localAudited;
    return matchedHintIds.isEmpty
        ? AskTitoDexAnswerMode.curatedSourcesQwen
        : AskTitoDexAnswerMode.auditedOnline;
  }
}

bool isAskTitoDexSupported(CurrentJourney journey, GameEdition edition) {
  final context = AskTitoDexContext.fromJourney(journey, edition);
  return context.generation == 4 &&
      (context.game == 'heartgold' || context.game == 'soulsilver');
}

class AskTitoDexContext {
  const AskTitoDexContext({
    required this.game,
    required this.generation,
    required this.locationLabel,
    required this.locationId,
    required this.badgeIds,
    required this.milestoneIds,
    required this.parserRevision,
    this.badgeCount,
    this.gameReliability = 'save_verified',
    this.locationReliability = 'save_verified',
    this.badgesReliability = 'save_verified',
    this.milestonesReliability = 'unsupported',
    this.includeLocation = true,
    this.includeBadges = true,
    this.locale = 'zh-Hans',
  });

  final String? game;
  final int generation;
  final String? locationLabel;
  final String? locationId;
  final List<String> badgeIds;
  final List<String> milestoneIds;
  final int parserRevision;
  final int? badgeCount;
  final String gameReliability;
  final String locationReliability;
  final String badgesReliability;
  final String milestonesReliability;
  final bool includeLocation;
  final bool includeBadges;
  final String locale;

  bool get hasVerifiedLocationContext =>
      includeLocation &&
      locationReliability == 'save_verified' &&
      locationLabel != null &&
      locationId != null;

  bool get hasVerifiedBadgeContext =>
      includeBadges &&
      ((badgesReliability == 'save_verified' && badgeIds.isNotEmpty) ||
          (badgesReliability == 'count_only' && badgeCount != null));

  factory AskTitoDexContext.fromJourney(
    CurrentJourney journey,
    GameEdition edition, {
    String? locationId,
  }) {
    final saveEdition = gameEditionForSaveGame(journey.game);
    final hasLinkedSave =
        journey.saveDexHash != null &&
        saveEdition != null &&
        isSaveEditionCompatible(selected: edition, save: saveEdition);
    final saveGame = hasLinkedSave ? saveEdition.assistantGameKey : null;
    final exactGame = saveGame ?? edition.assistantGameKey;
    final gameWasVerifiedBySave = hasLinkedSave && saveGame != null;
    final exactHgss =
        hasLinkedSave &&
        (exactGame == 'heartgold' || exactGame == 'soulsilver');
    final hasVerifiedBadgeCount =
        hasLinkedSave &&
        const {
          'rgb',
          'yellow',
          'gs',
          'crystal',
          'dp',
          'pt',
        }.contains(saveEdition.slug);
    final badgeIds = exactHgss
        ? List<String>.unmodifiable(journey.verifiedBadgeIds)
        : const <String>[];
    final badgeCount = hasVerifiedBadgeCount ? journey.badges : null;
    return AskTitoDexContext(
      game: exactGame,
      generation: edition.generation,
      locationLabel: exactHgss ? journey.location : null,
      locationId: exactHgss ? locationId : null,
      badgeIds: badgeIds,
      badgeCount: badgeCount,
      milestoneIds: const [],
      parserRevision: hasLinkedSave ? saveParserRevision : 0,
      gameReliability: gameWasVerifiedBySave
          ? 'save_verified'
          : 'user_selected',
      locationReliability: exactHgss ? 'save_verified' : 'unknown',
      badgesReliability: exactHgss
          ? 'save_verified'
          : hasVerifiedBadgeCount
          ? 'count_only'
          : 'unknown',
      includeLocation: exactHgss,
      includeBadges: exactHgss || hasVerifiedBadgeCount,
    );
  }

  AskTitoDexContext copyWith({
    bool? includeLocation,
    bool? includeBadges,
    String? locationId,
  }) => AskTitoDexContext(
    game: game,
    generation: generation,
    locationLabel: locationLabel,
    locationId: locationId ?? this.locationId,
    badgeIds: badgeIds,
    badgeCount: badgeCount,
    milestoneIds: milestoneIds,
    parserRevision: parserRevision,
    gameReliability: gameReliability,
    locationReliability: locationReliability,
    badgesReliability: badgesReliability,
    milestonesReliability: milestonesReliability,
    includeLocation: includeLocation ?? this.includeLocation,
    includeBadges: includeBadges ?? this.includeBadges,
    locale: locale,
  );

  Map<String, dynamic> toRequestJson() {
    final sendsLocation = includeLocation && locationId != null;
    final effectiveBadgeReliability = includeBadges
        ? badgesReliability
        : 'unknown';
    final sendsBadgeCount =
        effectiveBadgeReliability == 'count_only' && badgeCount != null;
    final sendsBadgeIds = effectiveBadgeReliability == 'save_verified';
    final sendsMilestones = milestonesReliability == 'save_verified';
    return {
      'game': game,
      'generation': generation,
      if (sendsLocation) 'locationId': locationId,
      'badgeIds': sendsBadgeIds ? badgeIds : const <String>[],
      if (sendsBadgeCount) 'badgeCount': badgeCount,
      'milestoneIds': sendsMilestones ? milestoneIds : const <String>[],
      'locale': locale,
      'parserRevision': parserRevision,
      'contextReliability': {
        'game': gameReliability,
        'location': sendsLocation && locationReliability == 'save_verified'
            ? 'save_verified'
            : 'unknown',
        'badges': sendsBadgeIds || sendsBadgeCount
            ? effectiveBadgeReliability
            : 'unknown',
        'milestones': sendsMilestones ? 'save_verified' : 'unsupported',
      },
    };
  }

  /// Context for the separately installed extension. Reliability is explicit:
  /// recognizing a save format does not imply every progression field was
  /// decoded. Raw save bytes and personal trainer/party fields are never sent.
  Map<String, dynamic> toExtensionJson(CurrentJourney _) {
    final sendsLocation =
        includeLocation &&
        locationId != null &&
        locationReliability == 'save_verified';
    final sendsBadgeIds = includeBadges && badgesReliability == 'save_verified';
    final sendsBadgeCount =
        includeBadges &&
        badgesReliability == 'count_only' &&
        badgeCount != null;
    final sendsMilestones = milestonesReliability == 'save_verified';
    return {
      'protocolVersion': 1,
      'game': {'value': game, 'reliability': gameReliability},
      'location': {
        'id': sendsLocation ? locationId : null,
        'label': sendsLocation ? locationLabel : null,
        'reliability': sendsLocation ? 'save_verified' : 'unknown',
      },
      'badges': {
        'ids': sendsBadgeIds ? badgeIds : const <String>[],
        'count': sendsBadgeCount ? badgeCount : null,
        'reliability': sendsBadgeIds || sendsBadgeCount
            ? badgesReliability
            : 'unknown',
      },
      'milestones': {
        'ids': sendsMilestones ? milestoneIds : const <String>[],
        'reliability': sendsMilestones ? 'save_verified' : 'unsupported',
      },
      'locale': locale,
      'parserRevision': parserRevision,
    };
  }
}

class AskTitoDexResult {
  const AskTitoDexResult({
    required this.status,
    this.answer,
    this.contextUsed = const {},
    this.matchedHintIds = const [],
    this.verifiedFacts = const [],
    this.unknowns = const [],
    this.confidence = 'low',
    this.sources = const [],
    this.followUp,
    this.errorCode,
    this.onlineComposed = false,
    this.answerMode = AskTitoDexAnswerMode.localAudited,
    this.modelUsed = false,
    this.aiSearchUsed = false,
    this.sourceKinds = const [],
    this.onlineAttempted = false,
  });

  final AskTitoDexStatus status;
  final String? answer;
  final Map<String, dynamic> contextUsed;
  final List<String> matchedHintIds;
  final List<String> verifiedFacts;
  final List<String> unknowns;
  final String confidence;
  final List<ProgressionSource> sources;
  final String? followUp;
  final String? errorCode;
  final bool onlineComposed;
  final AskTitoDexAnswerMode answerMode;
  final bool modelUsed;
  final bool aiSearchUsed;
  final List<String> sourceKinds;
  final bool onlineAttempted;

  AskTitoDexResult withRuntimeTrace({
    bool? onlineAttempted,
    String? errorCode,
  }) => AskTitoDexResult(
    status: status,
    answer: answer,
    contextUsed: contextUsed,
    matchedHintIds: matchedHintIds,
    verifiedFacts: verifiedFacts,
    unknowns: unknowns,
    confidence: confidence,
    sources: sources,
    followUp: followUp,
    errorCode: errorCode ?? this.errorCode,
    onlineComposed: onlineComposed,
    answerMode: answerMode,
    modelUsed: modelUsed,
    aiSearchUsed: aiSearchUsed,
    sourceKinds: sourceKinds,
    onlineAttempted: onlineAttempted ?? this.onlineAttempted,
  );

  factory AskTitoDexResult.fromJson(Map<String, dynamic> json) {
    final status = switch (json['status']) {
      'answered' => AskTitoDexStatus.answered,
      'needs_clarification' => AskTitoDexStatus.needsClarification,
      'no_match' => AskTitoDexStatus.noMatch,
      _ => AskTitoDexStatus.failed,
    };
    final matchedHintIds = _strings(json['matchedHintIds']);
    final onlineComposed = json['onlineComposed'] as bool? ?? true;
    return AskTitoDexResult(
      status: status,
      answer: json['answer'] as String?,
      contextUsed: Map<String, dynamic>.from(
        json['contextUsed'] as Map? ?? const {},
      ),
      matchedHintIds: matchedHintIds,
      verifiedFacts: _strings(json['verifiedFacts']),
      unknowns: _strings(json['unknowns']),
      confidence: json['confidence'] as String? ?? 'low',
      sources: (json['sources'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (source) =>
                ProgressionSource.fromJson(Map<String, dynamic>.from(source)),
          )
          .toList(growable: false),
      followUp: json['followUp'] as String?,
      errorCode: json['errorCode'] as String?,
      onlineComposed: onlineComposed,
      answerMode: AskTitoDexAnswerMode.fromWire(
        json['answerMode'],
        onlineComposed: onlineComposed,
        matchedHintIds: matchedHintIds,
      ),
      modelUsed: json['modelUsed'] as bool? ?? onlineComposed,
      aiSearchUsed: json['aiSearchUsed'] as bool? ?? false,
      sourceKinds: _strings(json['sourceKinds']),
      onlineAttempted: json['onlineAttempted'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': switch (status) {
      AskTitoDexStatus.answered => 'answered',
      AskTitoDexStatus.needsClarification => 'needs_clarification',
      AskTitoDexStatus.noMatch => 'no_match',
      AskTitoDexStatus.failed => 'failed',
    },
    'answer': answer,
    'contextUsed': contextUsed,
    'matchedHintIds': matchedHintIds,
    'verifiedFacts': verifiedFacts,
    'unknowns': unknowns,
    'confidence': confidence,
    'sources': sources.map((source) => source.toJson()).toList(),
    'followUp': followUp,
    'errorCode': errorCode,
    'onlineComposed': onlineComposed,
    'answerMode': answerMode.wireValue,
    'modelUsed': modelUsed,
    'aiSearchUsed': aiSearchUsed,
    'sourceKinds': sourceKinds,
    'onlineAttempted': onlineAttempted,
  };

  static List<String> _strings(Object? value) =>
      (value as List<dynamic>? ?? const []).whereType<String>().toList();
}

class ProgressionSource {
  const ProgressionSource({
    required this.title,
    required this.url,
    required this.accessedAt,
  });

  final String title;
  final String url;
  final String accessedAt;

  factory ProgressionSource.fromJson(Map<String, dynamic> json) =>
      ProgressionSource(
        title: json['title'] as String,
        url: json['url'] as String,
        accessedAt: json['accessedAt'] as String,
      );

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'accessedAt': accessedAt,
  };
}

class ProgressionRequirement {
  const ProgressionRequirement({
    required this.type,
    required this.id,
    required this.labelZh,
    required this.reliability,
  });

  final String type;
  final String id;
  final String labelZh;
  final String reliability;

  factory ProgressionRequirement.fromJson(Map<String, dynamic> json) =>
      ProgressionRequirement(
        type: json['type'] as String,
        id: json['id'] as String,
        labelZh: json['labelZh'] as String,
        reliability: json['reliability'] as String,
      );
}

class ProgressionHint {
  const ProgressionHint({
    required this.id,
    required this.games,
    required this.locations,
    required this.locationAliases,
    required this.destinationAliases,
    required this.subjectId,
    required this.subjectAliases,
    required this.requirements,
    required this.instructions,
    required this.overviewZh,
    required this.sources,
  });

  final String id;
  final List<String> games;
  final List<String> locations;
  final List<String> locationAliases;
  final List<String> destinationAliases;
  final String subjectId;
  final List<String> subjectAliases;
  final List<ProgressionRequirement> requirements;
  final List<String> instructions;
  final String overviewZh;
  final List<ProgressionSource> sources;

  factory ProgressionHint.fromJson(Map<String, dynamic> json) {
    final subject = Map<String, dynamic>.from(json['subject'] as Map);
    return ProgressionHint(
      id: json['id'] as String,
      games: _stringList(json['games']),
      locations: _stringList(json['locations']),
      locationAliases: _stringList(json['locationAliases']),
      destinationAliases: _stringList(json['destinationAliases']),
      subjectId: subject['id'] as String,
      subjectAliases: _stringList(subject['aliases']),
      requirements: (json['requirements'] as List<dynamic>)
          .map(
            (item) => ProgressionRequirement.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      instructions: (json['steps'] as List<dynamic>)
          .map((item) => (item as Map)['instructionZh'] as String)
          .toList(growable: false),
      overviewZh: json['overviewZh'] as String,
      sources: (json['sources'] as List<dynamic>)
          .map(
            (item) => ProgressionSource.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  static List<String> _stringList(Object? value) =>
      (value as List<dynamic>).cast<String>();
}

abstract class ProgressionHintDataSource {
  Future<String?> loadJson();
}

class InstalledExtensionProgressionHintDataSource
    implements ProgressionHintDataSource {
  const InstalledExtensionProgressionHintDataSource(this.extension);

  final JourneyAssistantExtensionController extension;

  @override
  Future<String?> loadJson() =>
      extension.readTextFile('progression_hints.json');
}

class BundledProgressionHintDataSource implements ProgressionHintDataSource {
  const BundledProgressionHintDataSource();

  static const assetPath = 'assets/data/journey/progression_hints.json';

  @override
  Future<String?> loadJson() => rootBundle.loadString(assetPath);
}

class ProgressionHintRepository {
  ProgressionHintRepository({
    ProgressionHintDataSource? extensionDataSource,
    ProgressionHintDataSource? bundledDataSource,
  }) : _extensionDataSource =
           extensionDataSource ??
           InstalledExtensionProgressionHintDataSource(
             journeyAssistantExtension,
           ),
       _bundledDataSource =
           bundledDataSource ?? const BundledProgressionHintDataSource();

  final ProgressionHintDataSource _extensionDataSource;
  final ProgressionHintDataSource _bundledDataSource;
  List<ProgressionHint>? _cached;

  Future<List<ProgressionHint>> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    // Keep already-installed content APKs compatible, but the assistant no
    // longer depends on Android package discovery. The reviewed HGSS seed is
    // always available from the host APK when no extension data can be read.
    final source =
        await _extensionDataSource.loadJson() ??
        await _bundledDataSource.loadJson();
    if (source == null) return const [];
    final json = jsonDecode(source) as Map<String, dynamic>;
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported progression hints schema.');
    }
    final loaded = (json['entries'] as List<dynamic>)
        .map(
          (item) =>
              ProgressionHint.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
    _cached = loaded;
    return loaded;
  }

  Future<String?> resolveLocationId(String? label) async {
    final normalized = _normalize(label ?? '');
    if (normalized.isEmpty) return null;
    for (final hint in await load()) {
      if (hint.locationAliases.any(
        (alias) => _normalize(alias) == normalized,
      )) {
        return hint.locations.first;
      }
    }
    return null;
  }

  Future<AskTitoDexResult> answer(
    String question,
    AskTitoDexContext context,
  ) async {
    final game = context.game;
    if (game == null || game.isEmpty) {
      return const AskTitoDexResult(
        status: AskTitoDexStatus.needsClarification,
        followUp: '请先确认你正在玩心金还是魂银。',
      );
    }
    final candidates =
        (await load())
            .where((hint) => hint.games.contains(game))
            .map((hint) => (hint: hint, score: _score(hint, question, context)))
            .where((candidate) => candidate.score > 0)
            .toList()
          ..sort((left, right) => right.score.compareTo(left.score));
    if (candidates.isEmpty) {
      return const AskTitoDexResult(
        status: AskTitoDexStatus.noMatch,
        followUp: '目前只收录少量 HGSS 主线阻塞点。请补充地点、挡路角色或所需道具。',
      );
    }
    if (candidates.length > 1 && candidates[0].score == candidates[1].score) {
      return const AskTitoDexResult(
        status: AskTitoDexStatus.needsClarification,
        followUp: '我找到多个可能的阻塞点。请补充你所在地点或挡路的角色／物体。',
      );
    }
    return _deterministicAnswer(candidates.first.hint, context);
  }

  int _score(ProgressionHint hint, String question, AskTitoDexContext context) {
    final normalized = _normalize(question);
    var score = 0;
    if (hint.subjectAliases.any(
      (alias) => normalized.contains(_normalize(alias)),
    )) {
      score += 5;
    }
    if (hint.locationAliases.any(
      (alias) => normalized.contains(_normalize(alias)),
    )) {
      score += 3;
    }
    if (hint.destinationAliases.any(
      (alias) => normalized.contains(_normalize(alias)),
    )) {
      score += 2;
    }
    // A verified save location may disambiguate a textual match, but must not
    // turn an unrelated question into a local blocker answer by itself.
    if (score == 0) return 0;
    if (context.includeLocation &&
        context.locationId != null &&
        hint.locations.contains(context.locationId)) {
      score += 4;
    } else if (context.includeLocation && context.locationLabel != null) {
      final current = _normalize(context.locationLabel!);
      if (hint.locationAliases.any(
        (alias) => current.contains(_normalize(alias)),
      )) {
        score += 4;
      }
    }
    return score;
  }

  AskTitoDexResult _deterministicAnswer(
    ProgressionHint hint,
    AskTitoDexContext context,
  ) {
    final verifiedFacts = <String>[hint.overviewZh];
    final unknowns = <String>[];
    final progressNotes = <String>[];
    for (final requirement in hint.requirements) {
      if (requirement.type == 'badge' &&
          context.includeBadges &&
          context.badgesReliability == 'save_verified') {
        if (context.badgeIds.contains(requirement.id)) {
          progressNotes.add('你的存档可以确认已取得${requirement.labelZh}。');
          verifiedFacts.add('存档已确认${requirement.labelZh}');
        } else if (context.parserRevision > 0) {
          progressNotes.add('你的存档尚未显示${requirement.labelZh}。');
        } else {
          unknowns.add('当前没有可可靠确认的${requirement.labelZh}状态');
        }
      }
      if (requirement.reliability == 'not_currently_parsed') {
        unknowns.add('当前解析器无法确认是否已完成／取得${requirement.labelZh}');
      }
    }
    final answer = [
      hint.overviewZh,
      hint.instructions.join('\n'),
      if (progressNotes.isNotEmpty) progressNotes.join(''),
      if (unknowns.isNotEmpty) '注意：${unknowns.join('；')}。',
    ].join('\n\n');
    return AskTitoDexResult(
      status: AskTitoDexStatus.answered,
      answer: answer,
      contextUsed: {
        'game': context.game,
        if (context.includeLocation && context.locationId != null)
          'locationId': context.locationId,
        if (context.includeBadges) 'badgeIds': context.badgeIds,
      },
      matchedHintIds: [hint.id],
      verifiedFacts: verifiedFacts,
      unknowns: unknowns,
      confidence: 'high',
      sources: hint.sources,
    );
  }
}

String _normalize(String value) => value.trim().toLowerCase().replaceAll(
  RegExp(r'[\s·・,，.。!?！？()（）\-_/]'),
  '',
);

final progressionHintRepository = ProgressionHintRepository();
