/// Gen 4 medium-fast growth: total experience to reach [level] is level³.
int gen4MediumFastExpForLevel(int level) {
  if (level <= 1) {
    return 0;
  }
  return level * level * level;
}

/// Returns 0..1 progress toward the next level.
double gen4MediumFastExpProgress(int experience, int level) {
  if (level < 1) {
    return 0;
  }
  if (level >= 100) {
    return 1;
  }
  final currentFloor = gen4MediumFastExpForLevel(level);
  final nextFloor = gen4MediumFastExpForLevel(level + 1);
  final span = nextFloor - currentFloor;
  if (span <= 0) {
    return 0;
  }
  return ((experience - currentFloor) / span).clamp(0.0, 1.0);
}
