import 'game_edition.dart';
import 'game_edition_repository.dart';

/// How the app treats journey / save / home chrome for a [GameEdition].
enum JourneyCapability {
  /// Local `.sav` sync, journey card, and save settings.
  saveLinked,

  /// Dex + manual team; no save read, no journey card.
  manual,
}

/// TitoDex parses the pre-Switch main-series formats represented in the
/// catalog. Switch saves require console-specific extraction and are kept in
/// manual mode.
JourneyCapability journeyCapabilityFor(GameEdition edition) {
  if (const {
    'rgb',
    'yellow',
    'gs',
    'crystal',
    'rs',
    'emerald',
    'frlg',
    'dp',
    'pt',
    'hgss',
    'bw',
    'bw2',
    'xy',
    'oras',
    'sm',
    'usum',
  }.contains(edition.slug)) {
    return JourneyCapability.saveLinked;
  }
  return JourneyCapability.manual;
}

extension GameEditionJourney on GameEdition {
  JourneyCapability get journeyCapability => journeyCapabilityFor(this);

  bool get isSaveLinked => journeyCapability == JourneyCapability.saveLinked;
}

JourneyCapability currentJourneyCapability() =>
    journeyCapabilityFor(gameEditionRepository.edition);
