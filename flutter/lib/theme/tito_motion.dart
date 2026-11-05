import 'package:flutter/material.dart';

import 'motion_preferences.dart';

/// Shared lightweight motion tokens for TitoDex surfaces.
abstract final class TitoMotion {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 220);
  static const emphasized = Duration(milliseconds: 280);
  static const listReveal = Duration(milliseconds: 320);

  /// Result numbers counting up from zero (damage, stats, totals).
  static const countUp = Duration(milliseconds: 680);

  /// Odometer roll when a shown value changes.
  static const odometer = Duration(milliseconds: 420);

  /// Characters per second for short companion lines.
  static const typewriterCharsPerSecond = 28.0;

  /// Under-damped press release: settles in ~350ms with one small overshoot.
  static const pressSpring = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 18,
  );

  static const switchTravel = 8.0;
  static const listTravel = 14.0;

  static bool disabled(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      !motionPreferences.listAnimationsEnabled;

  static Duration duration(BuildContext context, Duration normal) =>
      disabled(context) ? Duration.zero : normal;
}
