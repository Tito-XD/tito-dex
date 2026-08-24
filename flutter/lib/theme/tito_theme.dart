import 'package:flutter/material.dart';

import 'tito_colors.dart';
import 'tito_typography.dart';

/// Material 3 theme used by the native-Material experiment branch.
///
/// Product pages keep their compact RG-aware layout, while controls, shape,
/// elevation, state layers and neutral surfaces come from Material 3.
ThemeData buildTitoTheme() {
  const fontFamily = TitoTypography.fontFamily;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: TitoColors.materialSeed,
    brightness: Brightness.light,
    secondary: TitoColors.coral,
    surface: TitoColors.materialSurface,
  );

  TextStyle baseStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? colorScheme.onSurface,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  TextStyle headingStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
  }) => baseStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: fontSize * -0.01,
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
    titleSmall: headingStyle(fontSize: 16, fontWeight: FontWeight.w600),
    bodyLarge: baseStyle(fontSize: 16),
    bodyMedium: baseStyle(fontSize: 14),
    bodySmall: baseStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
    labelLarge: baseStyle(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: baseStyle(fontSize: 12, fontWeight: FontWeight.w600),
    labelSmall: baseStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurfaceVariant,
    ),
  );

  const pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(
        fallbackColor: TitoColors.materialSurface,
      ),
      TargetPlatform.iOS: ZoomPageTransitionsBuilder(
        backgroundColor: TitoColors.materialSurface,
      ),
    },
  );

  final mediumShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(TitoRadii.md),
  );
  final largeShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(TitoRadii.lg),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    fontFamily: fontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: colorScheme.surface,
    canvasColor: colorScheme.surface,
    splashFactory: InkRipple.splashFactory,
    highlightColor: colorScheme.primary.withValues(alpha: 0.08),
    pageTransitionsTheme: pageTransitions,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerLow,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 1,
      shadowColor: colorScheme.shadow,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: largeShape,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      surfaceTintColor: colorScheme.surfaceTint,
      modalBarrierColor: colorScheme.scrim.withValues(alpha: 0.42),
      showDragHandle: true,
      dragHandleColor: colorScheme.onSurfaceVariant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TitoRadii.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surfaceContainerHigh,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TitoRadii.xl),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.primary,
      textColor: colorScheme.onSurface,
      titleTextStyle: textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      subtitleTextStyle: textTheme.bodySmall,
      shape: mediumShape,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(
          textTheme.labelLarge?.copyWith(fontSize: 13),
        ),
        shape: WidgetStatePropertyAll(mediumShape),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      backgroundColor: colorScheme.inverseSurface,
      actionTextColor: colorScheme.inversePrimary,
      behavior: SnackBarBehavior.floating,
      shape: mediumShape,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        disabledBackgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: mediumShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        textStyle: textTheme.labelLarge,
        side: BorderSide(color: colorScheme.outline),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: mediumShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        textStyle: textTheme.labelLarge,
        shape: mediumShape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: colorScheme.onSurfaceVariant,
        highlightColor: colorScheme.primary.withValues(alpha: 0.08),
        shape: const CircleBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      labelStyle: textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      helperStyle: textTheme.bodySmall,
      errorStyle: textTheme.bodySmall?.copyWith(
        color: colorScheme.error,
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TitoRadii.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TitoRadii.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TitoRadii.md),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
  );
}
