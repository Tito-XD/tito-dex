import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tito_colors.dart';

ThemeData buildTitoTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.transparent,
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
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TitoColors.deepBlue,
        foregroundColor: TitoColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TitoRadii.md),
          side: const BorderSide(color: TitoColors.ink, width: 3),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TitoColors.deepBlue,
        side: const BorderSide(color: TitoColors.ink, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TitoRadii.md),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TitoColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TitoRadii.md),
        borderSide: const BorderSide(color: TitoColors.ink, width: 2),
      ),
    ),
  );
}
