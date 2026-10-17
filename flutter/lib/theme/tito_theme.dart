import 'package:flutter/material.dart';

import 'app_visual_style.dart';
import 'tito_colors.dart';
import 'tito_skin.dart';
import 'tito_typography.dart';

ThemeData buildTitoTheme([AppVisualStyle style = AppVisualStyle.classic]) =>
    switch (style) {
      AppVisualStyle.classic => _buildClassicTheme(),
      AppVisualStyle.solidPlastic => _buildSolidPlasticTheme(),
      AppVisualStyle.flatUi => _buildFlatUiTheme(),
    };

/// Matches [TitoTypography]'s fallback chain so Material widgets that only
/// inherit the theme font still render Chinese with a real CJK face.
const _fontFamilyFallback = ['Noto Sans CJK SC', 'Noto Sans SC', 'sans-serif'];

TextTheme _textTheme({
  required Color ink,
  required Color muted,
  required double tracking,
  FontWeight body = FontWeight.w600,
  FontWeight heading = FontWeight.w800,
  double displayTracking = -0.02,
}) {
  TextStyle base(
    double size, {
    FontWeight? weight,
    Color? color,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: TitoTypography.fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    fontSize: size,
    fontWeight: weight ?? body,
    color: color ?? ink,
    letterSpacing: letterSpacing,
  );

  TextStyle head(double size, {FontWeight? weight, double? factor}) => base(
    size,
    weight: weight ?? heading,
    letterSpacing: size * (factor ?? tracking),
  );

  return TextTheme(
    displayLarge: head(32, factor: displayTracking),
    displayMedium: head(28, factor: displayTracking),
    displaySmall: head(24, factor: displayTracking),
    headlineLarge: head(24),
    headlineMedium: head(22),
    headlineSmall: head(20),
    titleLarge: head(20),
    titleMedium: head(18),
    titleSmall: head(16, weight: FontWeight.w700),
    bodyLarge: base(16),
    bodyMedium: base(14),
    bodySmall: base(12, color: muted),
    labelLarge: base(14, weight: FontWeight.w800),
    labelMedium: base(12, weight: FontWeight.w700),
    labelSmall: base(11, weight: FontWeight.w700, color: muted),
  );
}

/// Shared chip theme so stock FilterChip / ChoiceChip match [TitoChip].
ChipThemeData _chipTheme(TitoSkin skin, TextTheme text) => ChipThemeData(
  backgroundColor: skin.chipFill,
  selectedColor: skin.chipSelectedFill,
  disabledColor: skin.chipFill.withValues(alpha: 0.5),
  checkmarkColor: skin.onChipSelected,
  labelStyle: text.labelMedium?.copyWith(color: skin.ink),
  secondaryLabelStyle: text.labelMedium?.copyWith(color: skin.onChipSelected),
  side: skin.outline == null
      ? BorderSide.none
      : BorderSide(color: skin.outline!, width: 1.25),
  shape: const StadiumBorder(),
  elevation: 0,
  pressElevation: 0,
  showCheckmark: false,
  padding: const EdgeInsets.symmetric(horizontal: 6),
);

SnackBarThemeData _snackBarTheme(TextTheme text, double radius) =>
    SnackBarThemeData(
      contentTextStyle: text.bodyMedium?.copyWith(color: TitoColors.card),
      backgroundColor: const Color(0xFF22324A),
      actionTextColor: TitoColors.softYellow,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );

/// Translucent, light-reactive treatment from the Liquid Glass experiment,
/// now exposed as the built-in Solid Plastic theme.
ThemeData _buildSolidPlasticTheme() {
  const skin = TitoSkin.plastic;
  final scheme = ColorScheme.fromSeed(
    seedColor: TitoColors.deepBlue,
    brightness: Brightness.light,
    primary: TitoColors.deepBlue,
    secondary: const Color(0xFF3D7F93),
    tertiary: TitoColors.coral,
    surface: skin.sheetFill,
  );
  final textTheme = _textTheme(
    ink: skin.ink,
    muted: skin.mutedInk,
    tracking: skin.headingTracking,
  );
  final rim = BorderSide(
    color: Colors.white.withValues(alpha: 0.78),
    width: TitoBorders.glass,
  );
  final mediumShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(skin.radiusMd),
    side: BorderSide(
      color: TitoColors.deepBlue.withValues(alpha: 0.30),
      width: TitoBorders.glass,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    fontFamily: TitoTypography.fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    textTheme: textTheme,
    extensions: const [skin],
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
      foregroundColor: skin.pageInk,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: skin.pageInk),
    ),
    cardTheme: CardThemeData(
      color: TitoColors.card.withValues(alpha: 0.93),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: mediumShape,
    ),
    // Opaque milky shell: sheets never sample the page behind them.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: skin.sheetFill,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: const Color(0x6108101C),
      showDragHandle: true,
      dragHandleColor: TitoColors.plasticInk.withValues(alpha: 0.3),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(skin.radiusHero),
        ),
        side: rim,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: skin.sheetFill,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shadowColor: const Color(0xFF13263D),
      titleTextStyle: textTheme.titleMedium,
      contentTextStyle: textTheme.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(skin.radiusHero),
        side: rim,
      ),
    ),
    chipTheme: _chipTheme(
      skin,
      textTheme,
    ).copyWith(side: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
    snackBarTheme: _snackBarTheme(textTheme, skin.radiusMd),
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
      fillColor: Colors.white.withValues(alpha: 0.78),
      labelStyle: textTheme.bodySmall,
      hintStyle: textTheme.bodyMedium?.copyWith(color: skin.mutedInk),
      helperStyle: textTheme.bodySmall,
      errorStyle: textTheme.bodySmall?.copyWith(color: TitoColors.coral),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(skin.radiusMd),
        borderSide: mediumShape.side,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(skin.radiusMd),
        borderSide: mediumShape.side,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(skin.radiusMd),
        borderSide: BorderSide(color: skin.accentInkOnLight, width: 1.6),
      ),
    ),
  );
}

/// Flat UI: bold colour blocks, big tight numerals, no shadows or outlines.
/// Coral is the primary action, deep blue the selected/inverse block and
/// soft yellow the identity accent.
ThemeData _buildFlatUiTheme() {
  const skin = TitoSkin.flat;
  const ink = TitoColors.flatOnSurface;
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: TitoColors.flatSeed,
        brightness: Brightness.light,
      ).copyWith(
        primary: TitoColors.deepBlue,
        onPrimary: TitoColors.card,
        primaryContainer: TitoColors.skyBlue,
        onPrimaryContainer: ink,
        secondary: TitoColors.coral,
        onSecondary: ink,
        secondaryContainer: const Color(0xFFFFD9CB),
        onSecondaryContainer: ink,
        tertiary: const Color(0xFFB08A1E),
        onTertiary: TitoColors.card,
        tertiaryContainer: TitoColors.softYellow,
        onTertiaryContainer: ink,
        surface: TitoColors.flatSurface,
        onSurface: ink,
        onSurfaceVariant: skin.mutedInk,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF2F3FA),
        surfaceContainer: TitoColors.flatSurfaceContainer,
        surfaceContainerHigh: TitoColors.flatSurfaceContainerHigh,
        surfaceContainerHighest: const Color(0xFFDADFEA),
        surfaceTint: Colors.transparent,
        outline: ink,
        outlineVariant: const Color(0xFFC9CFDB),
        inverseSurface: TitoColors.deepBlue,
        onInverseSurface: TitoColors.card,
        inversePrimary: TitoColors.softYellow,
      );

  final textTheme = _textTheme(
    ink: ink,
    muted: skin.mutedInk,
    tracking: skin.headingTracking,
    displayTracking: skin.displayTracking,
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
    borderRadius: BorderRadius.circular(skin.radiusMd),
  );
  final largeShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(skin.radiusLg),
  );
  const stadium = StadiumBorder();

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    fontFamily: TitoTypography.fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    textTheme: textTheme,
    extensions: const [skin],
    scaffoldBackgroundColor: colorScheme.surface,
    canvasColor: colorScheme.surface,
    splashFactory: InkRipple.splashFactory,
    highlightColor: ink.withValues(alpha: 0.06),
    pageTransitionsTheme: pageTransitions,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: skin.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: largeShape,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: skin.sheetFill,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      modalBarrierColor: TitoColors.deepBlue.withValues(alpha: 0.42),
      showDragHandle: true,
      dragHandleColor: ink.withValues(alpha: 0.28),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(skin.radiusHero + 6),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: skin.sheetFill,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(skin.radiusHero + 6),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: ink,
      textColor: ink,
      titleTextStyle: textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w700,
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
        side: const WidgetStatePropertyAll(BorderSide.none),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? TitoColors.deepBlue
              : TitoColors.flatSurfaceContainerHigh,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? TitoColors.card : ink,
        ),
        shape: const WidgetStatePropertyAll(stadium),
      ),
    ),
    chipTheme: _chipTheme(skin, textTheme),
    snackBarTheme: _snackBarTheme(
      textTheme,
      999,
    ).copyWith(backgroundColor: TitoColors.deepBlue, shape: stadium),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TitoColors.coral,
        foregroundColor: ink,
        disabledBackgroundColor: TitoColors.flatSurfaceContainerHigh,
        disabledForegroundColor: ink.withValues(alpha: 0.38),
        elevation: 0,
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: stadium,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TitoColors.deepBlue,
        foregroundColor: TitoColors.card,
        elevation: 0,
        textStyle: textTheme.labelLarge,
        shape: stadium,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        textStyle: textTheme.labelLarge,
        side: const BorderSide(color: ink, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: stadium,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TitoColors.deepBlue,
        textStyle: textTheme.labelLarge,
        shape: stadium,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: ink,
        highlightColor: ink.withValues(alpha: 0.08),
        shape: const CircleBorder(),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? TitoColors.card
            : ink.withValues(alpha: 0.55),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? TitoColors.deepBlue
            : TitoColors.flatSurfaceContainerHigh,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: TitoColors.coral,
      linearTrackColor: TitoColors.flatSurfaceContainerHigh,
      circularTrackColor: TitoColors.flatSurfaceContainerHigh,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TitoColors.flatSurfaceContainer,
      labelStyle: textTheme.bodySmall?.copyWith(
        color: skin.mutedInk,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(color: skin.mutedInk),
      helperStyle: textTheme.bodySmall,
      errorStyle: textTheme.bodySmall?.copyWith(
        color: colorScheme.error,
        fontWeight: FontWeight.w700,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(skin.radiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(skin.radiusMd),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(skin.radiusMd),
        borderSide: const BorderSide(color: ink, width: 2.5),
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
/// Paper surfaces use the thin slate pencil outline; the hard sticker drop
/// and press physics live in [StickerCard] / [StickerPressable].
ThemeData _buildClassicTheme() {
  const skin = TitoSkin.journal;
  final textTheme = _textTheme(
    ink: TitoColors.ink,
    muted: TitoColors.mutedInk,
    tracking: skin.headingTracking,
  );
  final scheme = ColorScheme.fromSeed(
    seedColor: TitoColors.deepBlue,
    primary: TitoColors.deepBlue,
    secondary: TitoColors.coral,
    surface: skin.paper,
  );
  final pencil = BorderSide(color: skin.outline!, width: skin.outlineWidth);
  final mediumShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(skin.radiusMd),
    side: pencil,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    fontFamily: TitoTypography.fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    textTheme: textTheme,
    extensions: const [skin],
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
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: skin.sheetFill,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: const Color(0x6108101C),
      showDragHandle: true,
      dragHandleColor: TitoColors.deepBlue.withValues(alpha: 0.3),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(skin.radiusHero + 6),
        ),
        side: pencil,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: skin.sheetFill,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: textTheme.titleMedium?.copyWith(color: skin.ink),
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: skin.ink),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(skin.radiusHero + 4),
        side: pencil,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: skin.pageInk,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: skin.pageInk),
    ),
    cardTheme: CardThemeData(
      color: skin.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: mediumShape,
    ),
    chipTheme: _chipTheme(skin, textTheme),
    snackBarTheme: _snackBarTheme(textTheme, skin.radiusMd + 3),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TitoColors.deepBlue,
        foregroundColor: TitoColors.card,
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(skin.radiusMd),
          side: const BorderSide(color: Color(0xFF22324A), width: 1.4),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TitoColors.deepBlue,
        backgroundColor: skin.paper,
        textStyle: textTheme.labelLarge,
        side: pencil,
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
      fillColor: const Color(0xFFFFFDF7),
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
        borderRadius: BorderRadius.circular(skin.radiusMd),
        borderSide: pencil,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(skin.radiusMd),
        borderSide: pencil,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(skin.radiusMd),
        borderSide: const BorderSide(color: TitoColors.coral, width: 2),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: skin.outline!.withValues(alpha: 0.35),
      thickness: 1,
      space: 1,
    ),
  );
}
