import 'dart:math';

/// In-app shiny odds for the home party strip (per species, per session).
const int shinyPartyOdds = 64;

/// Deterministic per-(session, species) shiny roll so the whole session
/// agrees on which party member sparkles.
bool shinyRoll(int sessionSeed, int speciesId, {int odds = shinyPartyOdds}) {
  return Random(sessionSeed ^ (speciesId * 0x9E3779B9)).nextInt(odds) == 0;
}
