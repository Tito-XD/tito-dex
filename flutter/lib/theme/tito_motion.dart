import 'package:flutter/material.dart';

import 'motion_preferences.dart';

/// Shared lightweight motion tokens for TitoDex surfaces.
abstract final class TitoMotion {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 220);
  static const emphasized = Duration(milliseconds: 280);
  static const listReveal = Duration(milliseconds: 260);

  static const switchTravel = 8.0;
  static const listTravel = 6.0;

  static bool disabled(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      !motionPreferences.listAnimationsEnabled;

  static Duration duration(BuildContext context, Duration normal) =>
      disabled(context) ? Duration.zero : normal;
}
