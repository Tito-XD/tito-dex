import 'game_edition.dart';
import 'game_edition_repository.dart';

/// How the app treats journey / save / home chrome for a [GameEdition].
enum JourneyCapability {
  /// Local `.sav` sync, journey card, save settings (HGSS today).
  saveLinked,

  /// Dex + manual team; no save read, no journey card.
  manual,
}

/// Only editions with a working parser are save-linked.
JourneyCapability journeyCapabilityFor(GameEdition edition) {
  if (edition.slug == GameEdition.hgss.slug) {
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
