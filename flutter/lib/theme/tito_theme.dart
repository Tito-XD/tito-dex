import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tito_colors.dart';

ThemeData buildTitoTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: TitoColors.deepBlue,
    splashFactory: InkRipple.splashFactory,
    highlightColor: TitoColors.skyBlue.withValues(alpha: 0.2),
  );

  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: TitoColors.deepBlue,
      primary: TitoColors.deepBlue,
      secondary: TitoColors.coral,
      surface: TitoColors.card,
    ),
    textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).apply(
      bodyColor: TitoColors.ink,
      displayColor: TitoColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: TitoColors.card,
      elevation: 0,
    ),
  );
}
