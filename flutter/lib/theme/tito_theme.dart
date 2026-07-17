import 'package:flutter/material.dart';

import 'tito_colors.dart';
import 'tito_typography.dart';

ThemeData buildTitoTheme() {
  const fontFamily = TitoTypography.fontFamily;

  TextStyle baseStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color color = TitoColors.ink,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Headings tighten by -0.02em so titles hold together on square screens;
  // pairs Nunito's roundness with the thick ink borders.
  TextStyle headingStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w800,
  }) => baseStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: fontSize * -0.02,
  );

  final textTheme = TextTheme(
    displayLarge: headingStyle(fontSize: 32),
    displayMedium: headingStyle(fontSize: 28),
    displaySmall: headingStyle(fontSize: 24),
    headlineLarge: headingStyle(fontSize: 24),
    headlineMedium: headingStyle(fontSize: 22),
    headlineSmall: headingStyle(fontSize: 20),
    titleLarge: headingStyle(fontSize: 20),
    titleMedium: headingStyle(fontSize: 18),
    titleSmall: headingStyle(fontSize: 16, fontWeight: FontWeight.w700),
    bodyLarge: baseStyle(fontSize: 16),
    bodyMedium: baseStyle(fontSize: 14),
    bodySmall: baseStyle(fontSize: 12, color: TitoColors.mutedInk),
    labelLarge: baseStyle(fontSize: 14, fontWeight: FontWeight.w800),
    labelMedium: baseStyle(fontSize: 12, fontWeight: FontWeight.w700),
    labelSmall: baseStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: TitoColors.mutedInk,
    ),
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: TitoColors.slateBlue,
    splashFactory: InkRipple.splashFactory,
    highlightColor: TitoColors.skyBlue.withValues(alpha: 0.2),
    textTheme: textTheme,
  );

  const androidTransitions = PageTransitionsTheme(
    builders: {
      // fallbackColor drives the transition backdrop (enter scrim + the
      // ColoredBox behind predictive-back). It defaults to
      // colorScheme.surface — cream, which flashed behind the blue-gradient
      // pages. Slate blue matches scaffoldBackgroundColor/TitoPageContainer.
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(
        fallbackColor: TitoColors.slateBlue,
      ),
    },
  );

  return base.copyWith(
    // Android's Material route transition, including predictive-back progress.
    // Other platforms keep Flutter's own platform defaults.
    pageTransitionsTheme: androidTransitions,
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TitoColors.card,
      modalBarrierColor: Color(0x73221F26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TitoRadii.lg)),
        side: BorderSide(color: TitoColors.ink, width: 2),
      ),
      dragHandleColor: TitoColors.mutedInk,
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: TitoColors.deepBlue,
      primary: TitoColors.deepBlue,
      secondary: TitoColors.coral,
      surface: TitoColors.card,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: TitoColors.card,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: TitoColors.card),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      subtitleTextStyle: textTheme.bodySmall,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(
          textTheme.labelLarge?.copyWith(fontSize: 13),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: TitoColors.card),
      backgroundColor: TitoColors.deepBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TitoRadii.md),
        side: const BorderSide(color: TitoColors.ink, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TitoColors.deepBlue,
        foregroundColor: TitoColors.card,
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TitoRadii.md),
          side: const BorderSide(
            color: TitoColors.ink,
            width: TitoBorders.card,
          ),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TitoColors.deepBlue,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        side: const BorderSide(color: TitoColors.ink, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TitoRadii.md),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TitoColors.deepBlue,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TitoColors.card,
      labelStyle: textTheme.bodySmall?.copyWith(
        color: TitoColors.mutedInk,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: TitoColors.mutedInk,
        fontWeight: FontWeight.w600,
      ),
      helperStyle: textTheme.bodySmall,
      errorStyle: textTheme.bodySmall?.copyWith(
        color: TitoColors.coral,
        fontWeight: FontWeight.w700,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TitoRadii.md),
        borderSide: const BorderSide(color: TitoColors.ink, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TitoRadii.md),
        borderSide: const BorderSide(color: TitoColors.ink, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TitoRadii.md),
        borderSide: const BorderSide(color: TitoColors.coral, width: 2),
      ),
    ),
  );
}
