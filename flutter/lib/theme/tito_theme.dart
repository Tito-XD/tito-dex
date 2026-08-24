import 'package:flutter/material.dart';

import 'app_visual_style.dart';
import 'tito_colors.dart';
import 'tito_typography.dart';

ThemeData buildTitoTheme([AppVisualStyle style = AppVisualStyle.classic]) =>
    switch (style) {
      AppVisualStyle.classic => _buildClassicTheme(),
      AppVisualStyle.solidPlastic => _buildSolidPlasticTheme(),
      AppVisualStyle.flatUi => _buildFlatUiTheme(),
    };

/// Translucent, light-reactive treatment from the Liquid Glass experiment,
/// now exposed as the built-in Solid Plastic theme.
ThemeData _buildSolidPlasticTheme() {
  const fontFamily = TitoTypography.fontFamily;
  final scheme = ColorScheme.fromSeed(
    seedColor: TitoColors.deepBlue,
    brightness: Brightness.light,
    primary: TitoColors.deepBlue,
    secondary: TitoColors.coral,
    surface: TitoColors.card,
  );

  TextStyle baseStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color color = TitoColors.ink,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

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
  final mediumShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(TitoRadii.md),
    side: BorderSide(
      color: TitoColors.deepBlue.withValues(alpha: 0.30),
      width: TitoBorders.glass,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    fontFamily: fontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: TitoColors.glassBackgroundBottom,
    splashFactory: InkRipple.splashFactory,
    highlightColor: TitoColors.skyBlue.withValues(alpha: 0.2),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(
          fallbackColor: TitoColors.glassBackgroundMid,
        ),
        TargetPlatform.iOS: ZoomPageTransitionsBuilder(
          backgroundColor: TitoColors.glassBackgroundMid,
        ),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: TitoColors.card,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: TitoColors.card),
    ),
    cardTheme: CardThemeData(
      color: TitoColors.card.withValues(alpha: 0.93),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: mediumShape,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: TitoColors.card.withValues(alpha: 0.97),
      modalBarrierColor: const Color(0x73221F26),
      showDragHandle: true,
      dragHandleColor: TitoColors.mutedInk,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(TitoRadii.xl),
        ),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.72),
          width: TitoBorders.glass,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: TitoColors.card),
      backgroundColor: TitoColors.deepBlue,
      behavior: SnackBarBehavior.floating,
      shape: mediumShape,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TitoColors.deepBlue,
        foregroundColor: TitoColors.card,
        textStyle: textTheme.labelLarge,
        shape: mediumShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TitoColors.deepBlue,
        textStyle: textTheme.labelLarge,
        side: BorderSide(
          color: TitoColors.deepBlue.withValues(alpha: 0.42),
          width: TitoBorders.glass,
        ),
        shape: mediumShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TitoColors.deepBlue,
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TitoColors.card.withValues(alpha: 0.92),
      labelStyle: textTheme.bodySmall,
      hintStyle: textTheme.bodyMedium?.copyWith(color: TitoColors.mutedInk),
      helperStyle: textTheme.bodySmall,
      errorStyle: textTheme.bodySmall?.copyWith(color: TitoColors.coral),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TitoRadii.md),
        borderSide: mediumShape.side,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TitoRadii.md),
        borderSide: mediumShape.side,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TitoRadii.md),
        borderSide: const BorderSide(color: TitoColors.coral, width: 1.6),
      ),
    ),
  );
}

/// Flat UI theme: restrained native controls with TitoDex's own surfaces.
ThemeData _buildFlatUiTheme() {
  const fontFamily = TitoTypography.fontFamily;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: TitoColors.flatSeed,
    brightness: Brightness.light,
    secondary: TitoColors.coral,
    surface: TitoColors.flatSurface,
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
        fallbackColor: TitoColors.flatSurface,
      ),
      TargetPlatform.iOS: ZoomPageTransitionsBuilder(
        backgroundColor: TitoColors.flatSurface,
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

/// The established TitoDex palette, retained as a first-class built-in theme.
/// Shared pages choose their gradient/card shell from [appVisualStyle], while
/// stock Material controls inherit this matching classic color scheme.
ThemeData _buildClassicTheme() {
  const fontFamily = TitoTypography.fontFamily;

  TextStyle baseStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color color = TitoColors.ink,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

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
  final scheme = ColorScheme.fromSeed(
    seedColor: TitoColors.deepBlue,
    primary: TitoColors.deepBlue,
    secondary: TitoColors.coral,
    surface: TitoColors.card,
  );
  final mediumShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(TitoRadii.md),
    side: const BorderSide(color: TitoColors.ink, width: 2),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    fontFamily: fontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: TitoColors.slateBlue,
    splashFactory: InkRipple.splashFactory,
    highlightColor: TitoColors.skyBlue.withValues(alpha: 0.2),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(
          fallbackColor: TitoColors.slateBlue,
        ),
        TargetPlatform.iOS: ZoomPageTransitionsBuilder(
          backgroundColor: TitoColors.slateBlue,
        ),
      },
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TitoColors.card,
      modalBarrierColor: Color(0x73221F26),
      showDragHandle: true,
      dragHandleColor: TitoColors.mutedInk,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TitoRadii.lg)),
        side: BorderSide(color: TitoColors.ink, width: 2),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: TitoColors.card,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: TitoColors.card),
    ),
    cardTheme: CardThemeData(
      color: TitoColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: mediumShape,
    ),
    snackBarTheme: SnackBarThemeData(
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: TitoColors.card),
      backgroundColor: TitoColors.deepBlue,
      behavior: SnackBarBehavior.floating,
      shape: mediumShape,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TitoColors.deepBlue,
        foregroundColor: TitoColors.card,
        textStyle: textTheme.labelLarge,
        shape: mediumShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TitoColors.deepBlue,
        textStyle: textTheme.labelLarge,
        side: const BorderSide(color: TitoColors.ink, width: 2),
        shape: mediumShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TitoColors.deepBlue,
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TitoColors.card,
      labelStyle: textTheme.bodySmall?.copyWith(
        color: TitoColors.mutedInk,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(color: TitoColors.mutedInk),
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
