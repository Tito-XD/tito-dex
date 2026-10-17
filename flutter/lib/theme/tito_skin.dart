import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_visual_style.dart';
import 'retro_style.dart';
import 'tito_colors.dart';
import 'tito_typography.dart';

/// How much personality a surface may carry.
///
/// * [normal] — ordinary cards and panels.
/// * [hero] — at most a few per screen (trainer card, a primary shelf, the
///   journey block). Journal adds tape / tilt / dashed frames, Solid Plastic
///   uses a per-role tint, Flat UI uses a bold colour block.
/// * [dense] — lists, grids, detail tables. Always opaque, never rotated,
///   never taped, with the smallest shadow the theme allows.
enum TitoSurfaceLevel { normal, hero, dense }

/// Semantic role of a hero surface. Each theme maps a role to its own tint.
enum TitoHeroRole {
  /// Identity surfaces: Trainer Card, profile headers.
  trainer,

  /// Containers that hold tiles or rows (party strip, quick actions).
  shelf,

  /// Deep status block (journey card, save summary).
  journey,

  /// The one primary call-to-action surface on a screen.
  action,
}

/// Fill / ink pair for a hero role.
@immutable
class TitoHeroTint {
  const TitoHeroTint({
    required this.top,
    required this.bottom,
    required this.ink,
    required this.mutedInk,
  });

  /// Top of the fill. Equal to [bottom] for flat colour blocks.
  final Color top;
  final Color bottom;
  final Color ink;
  final Color mutedInk;

  bool get isDark => Color.lerp(top, bottom, 0.5)!.computeLuminance() < 0.35;
}

/// Theme skin tokens shared by every TitoDex surface.
///
/// Registered as a [ThemeExtension] on all three built-in [ThemeData]s by
/// [buildTitoTheme]. Read it with `TitoSkin.of(context)`; never branch on
/// colours directly when a token exists here.
///
/// Shadows depend on the separate `Retro 贴纸手感` preference ([retroStyle]):
/// widgets that call [cardShadow] must rebuild when [retroStyle] notifies
/// (wrap them in `ListenableBuilder(listenable: retroStyle, …)`).
@immutable
class TitoSkin extends ThemeExtension<TitoSkin> {
  const TitoSkin({
    required this.family,
    required this.pageInk,
    required this.pageMutedInk,
    required this.paper,
    required this.paperDense,
    required this.ink,
    required this.mutedInk,
    required this.outline,
    required this.outlineWidth,
    required this.accentInkOnLight,
    required this.accentInkOnDark,
    required this.primaryFill,
    required this.onPrimaryFill,
    required this.chipFill,
    required this.chipSelectedFill,
    required this.onChipSelected,
    required this.sheetFill,
    required this.ruleColor,
    required this.tapeColor,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusHero,
    required this.heroTiltDegrees,
    required this.headingTracking,
    required this.displayTracking,
  });

  final TitoThemeFamily family;

  /// Text and icons drawn directly on the page background (titles, back
  /// arrows, page subtitles).
  final Color pageInk;
  final Color pageMutedInk;

  /// Default fill of a normal light card.
  final Color paper;

  /// Fully opaque fill for dense lists/grids.
  final Color paperDense;

  /// Text on [paper].
  final Color ink;
  final Color mutedInk;

  /// Card outline; `null` means the theme draws no outline (Flat UI).
  final Color? outline;
  final double outlineWidth;

  /// Accent ink for emphasised numerals/labels (clock minutes, counters).
  /// Use [accentInkOn] to pick the variant readable on a given background.
  final Color accentInkOnLight;
  final Color accentInkOnDark;

  /// Primary action fill (filled buttons, the one CTA per screen).
  final Color primaryFill;
  final Color onPrimaryFill;

  final Color chipFill;
  final Color chipSelectedFill;
  final Color onChipSelected;

  /// Bottom-sheet / dialog paper.
  final Color sheetFill;

  /// Horizontal rule colour for ruled-paper sheets (Journal only paints it).
  final Color ruleColor;

  /// Washi tape strip colour (Journal only paints it).
  final Color tapeColor;

  /// Logical radii. Unlike `DeviceLayout.rLg` these are not halved on RG
  /// panels: the values were tuned on the 480×480 handheld canvas.
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusHero;

  /// Rotation applied to taped hero cards (Journal: -1.4°, others: 0).
  final double heroTiltDegrees;

  /// Letter-spacing factor (× font size) for headings and display numerals.
  final double headingTracking;
  final double displayTracking;

  bool get isJournal => family == TitoThemeFamily.trainerJournal;
  bool get isPlastic => family == TitoThemeFamily.solidPlastic;
  bool get isFlat => family == TitoThemeFamily.flatUi;

  double get heroTiltRadians => heroTiltDegrees * math.pi / 180;

  /// Solid colour under the page backdrop (Scaffold background, route
  /// transition fallback).
  Color get pageBase => switch (family) {
    TitoThemeFamily.trainerJournal => TitoColors.slateBlue,
    TitoThemeFamily.solidPlastic => TitoColors.glassBackgroundBottom,
    TitoThemeFamily.flatUi => TitoColors.flatSurface,
  };

  /// Android navigation-bar colour that continues the page edge.
  Color get systemBarColor => switch (family) {
    TitoThemeFamily.trainerJournal => TitoColors.deepBlue,
    TitoThemeFamily.solidPlastic => TitoColors.glassBackgroundTop,
    TitoThemeFamily.flatUi => TitoColors.flatSurface,
  };

  /// Whether system status/navigation icons should be light.
  bool get pageIsDark => !isFlat;

  static const journal = TitoSkin(
    family: TitoThemeFamily.trainerJournal,
    pageInk: TitoColors.card,
    pageMutedInk: Color(0xFFF1ECE0),
    paper: TitoColors.journalPaper,
    paperDense: TitoColors.journalPaper,
    ink: TitoColors.journalInk,
    mutedInk: Color(0xFF66768A),
    outline: TitoColors.journalOutline,
    outlineWidth: 1.4,
    accentInkOnLight: Color(0xFFB0745A),
    accentInkOnDark: Color(0xFFF2C9A8),
    primaryFill: TitoColors.deepBlue,
    onPrimaryFill: TitoColors.card,
    chipFill: TitoColors.journalPaper,
    chipSelectedFill: TitoColors.deepBlue,
    onChipSelected: TitoColors.card,
    sheetFill: TitoColors.journalPaper,
    ruleColor: Color(0x2E859CAF),
    tapeColor: Color(0xB8D8D5B1),
    radiusSm: 8,
    radiusMd: 11,
    radiusLg: 14,
    radiusHero: 16,
    heroTiltDegrees: -1.4,
    headingTracking: -0.02,
    displayTracking: -0.03,
  );

  static const plastic = TitoSkin(
    family: TitoThemeFamily.solidPlastic,
    pageInk: TitoColors.card,
    pageMutedInk: Color(0xFFE6EEF4),
    paper: Color(0xFFF7FAFC),
    paperDense: Color(0xFFEEF3F6),
    ink: TitoColors.plasticInk,
    mutedInk: Color(0xFF55687D),
    outline: Color(0xC7FFFFFF),
    outlineWidth: 1.1,
    accentInkOnLight: Color(0xFF3D7F93),
    accentInkOnDark: TitoColors.glassCyan,
    primaryFill: TitoColors.deepBlue,
    onPrimaryFill: TitoColors.card,
    chipFill: Color(0xB8FFFFFF),
    chipSelectedFill: Color(0xFF3D7F93),
    onChipSelected: Colors.white,
    sheetFill: Color(0xFFEEF4F7),
    ruleColor: Color(0x00000000),
    tapeColor: Color(0x00000000),
    radiusSm: 10,
    radiusMd: 14,
    radiusLg: 20,
    radiusHero: 26,
    heroTiltDegrees: 0,
    headingTracking: -0.02,
    displayTracking: -0.03,
  );

  static const flat = TitoSkin(
    family: TitoThemeFamily.flatUi,
    pageInk: TitoColors.flatOnSurface,
    pageMutedInk: Color(0xFF4A505C),
    paper: TitoColors.flatSurfaceContainer,
    paperDense: TitoColors.flatSurfaceContainer,
    ink: TitoColors.flatOnSurface,
    mutedInk: Color(0xFF4A505C),
    outline: null,
    outlineWidth: 0,
    accentInkOnLight: TitoColors.coral,
    accentInkOnDark: TitoColors.coral,
    primaryFill: TitoColors.coral,
    onPrimaryFill: TitoColors.flatOnSurface,
    chipFill: TitoColors.flatSurfaceContainerHigh,
    chipSelectedFill: TitoColors.deepBlue,
    onChipSelected: TitoColors.card,
    sheetFill: TitoColors.flatSurface,
    ruleColor: Color(0x00000000),
    tapeColor: Color(0x00000000),
    radiusSm: 10,
    radiusMd: 14,
    radiusLg: 18,
    radiusHero: 22,
    heroTiltDegrees: 0,
    headingTracking: -0.035,
    displayTracking: -0.05,
  );

  static TitoSkin forStyle(AppVisualStyle style) => forFamily(style.family);

  static TitoSkin forFamily(TitoThemeFamily family) => switch (family) {
    TitoThemeFamily.trainerJournal => journal,
    TitoThemeFamily.solidPlastic => plastic,
    TitoThemeFamily.flatUi => flat,
  };

  /// The skin registered on the ambient [Theme]; falls back to the persisted
  /// [appVisualStyle] for subtrees built without a TitoDex theme (tests,
  /// `ThemeData.dark()` overrides).
  static TitoSkin of(BuildContext context) =>
      Theme.of(context).extension<TitoSkin>() ?? forStyle(appVisualStyle.style);

  /// Accent ink readable on [background] (light vs dark wallpaper rule from
  /// the launcher's `accentInk()`).
  Color accentInkOn(Color background) =>
      background.computeLuminance() < 0.4 ? accentInkOnDark : accentInkOnLight;

  /// Accent ink for text placed directly on the page background.
  Color get pageAccentInk =>
      pageInk.computeLuminance() > 0.5 ? accentInkOnDark : accentInkOnLight;

  TitoHeroTint heroTint(TitoHeroRole role) => switch ((family, role)) {
    (TitoThemeFamily.trainerJournal, TitoHeroRole.journey) =>
      const TitoHeroTint(
        top: TitoColors.deepBlue,
        bottom: TitoColors.deepBlue,
        ink: TitoColors.card,
        mutedInk: TitoColors.skyBlue,
      ),
    (TitoThemeFamily.trainerJournal, TitoHeroRole.action) => const TitoHeroTint(
      top: Color(0xFFF9E7A6),
      bottom: Color(0xFFF9E7A6),
      ink: TitoColors.journalInk,
      mutedInk: Color(0xFF7A6A3E),
    ),
    (TitoThemeFamily.trainerJournal, _) => const TitoHeroTint(
      top: TitoColors.journalPaper,
      bottom: TitoColors.journalPaper,
      ink: TitoColors.journalInk,
      mutedInk: Color(0xFF66768A),
    ),
    (TitoThemeFamily.solidPlastic, TitoHeroRole.trainer) => const TitoHeroTint(
      top: Color(0xFFF6F2FF),
      bottom: TitoColors.glassLavender,
      ink: TitoColors.plasticInk,
      mutedInk: Color(0xFF5B5480),
    ),
    (TitoThemeFamily.solidPlastic, TitoHeroRole.shelf) => const TitoHeroTint(
      top: Color(0xFFECFAFC),
      bottom: TitoColors.glassCyan,
      ink: TitoColors.plasticInk,
      mutedInk: Color(0xFF47697A),
    ),
    (TitoThemeFamily.solidPlastic, TitoHeroRole.journey) => const TitoHeroTint(
      top: Color(0xFF4A6587),
      bottom: Color(0xFF243650),
      ink: TitoColors.card,
      mutedInk: TitoColors.glassCyan,
    ),
    (TitoThemeFamily.solidPlastic, TitoHeroRole.action) => const TitoHeroTint(
      top: Color(0xFFFFF3EC),
      bottom: Color(0xFFFFCDB9),
      ink: TitoColors.plasticInk,
      mutedInk: Color(0xFF7C5546),
    ),
    (TitoThemeFamily.flatUi, TitoHeroRole.trainer) => const TitoHeroTint(
      top: TitoColors.softYellow,
      bottom: TitoColors.softYellow,
      ink: TitoColors.flatOnSurface,
      mutedInk: Color(0xFF5A4A1C),
    ),
    (TitoThemeFamily.flatUi, TitoHeroRole.shelf) => const TitoHeroTint(
      top: TitoColors.flatSurfaceContainerHigh,
      bottom: TitoColors.flatSurfaceContainerHigh,
      ink: TitoColors.flatOnSurface,
      mutedInk: Color(0xFF4A505C),
    ),
    (TitoThemeFamily.flatUi, TitoHeroRole.journey) => const TitoHeroTint(
      top: TitoColors.deepBlue,
      bottom: TitoColors.deepBlue,
      ink: TitoColors.card,
      mutedInk: TitoColors.skyBlue,
    ),
    (TitoThemeFamily.flatUi, TitoHeroRole.action) => const TitoHeroTint(
      top: TitoColors.coral,
      bottom: TitoColors.coral,
      ink: TitoColors.flatOnSurface,
      mutedInk: Color(0xFF5C2A18),
    ),
  };

  /// Resting card shadow, honouring the `Retro 贴纸手感` toggle.
  ///
  /// Journal keeps the signature hard 0/5 sticker drop; [paperEdge] adds the
  /// 2px paper-thickness line for light paper fills.
  List<BoxShadow>? cardShadow({
    bool small = false,
    bool pressed = false,
    bool paperEdge = false,
  }) {
    if (!retroStyle.enabled) {
      return null;
    }
    return switch (family) {
      TitoThemeFamily.trainerJournal => [
        ...(pressed
            ? TrainerJournalShadows.stickerPressed
            : small
            ? TrainerJournalShadows.stickerSmall
            : TrainerJournalShadows.sticker),
        if (paperEdge && !pressed) TrainerJournalShadows.paperEdge,
      ],
      TitoThemeFamily.solidPlastic =>
        pressed
            ? SolidPlasticShadows.stickerPressed
            : small
            ? SolidPlasticShadows.stickerSmall
            : SolidPlasticShadows.sticker,
      TitoThemeFamily.flatUi => null,
    };
  }

  /// Small resting drop for chips, pills and form controls (not gated on the
  /// retro toggle, matching the historical form-control behaviour).
  List<BoxShadow>? get chipShadow => switch (family) {
    TitoThemeFamily.trainerJournal => const [
      BoxShadow(color: Color(0x26566A77), offset: Offset(0, 2)),
    ],
    TitoThemeFamily.solidPlastic => const [
      BoxShadow(
        color: Color(0x4D0A1422),
        blurRadius: 8,
        spreadRadius: -3,
        offset: Offset(0, 4),
      ),
    ],
    TitoThemeFamily.flatUi => null,
  };

  /// Outline for small controls; `BorderSide.none` in Flat UI.
  BorderSide get controlSide => switch (family) {
    TitoThemeFamily.trainerJournal => BorderSide(color: outline!, width: 1.25),
    TitoThemeFamily.solidPlastic => const BorderSide(
      color: Color(0xCCFFFFFF),
      width: 1.1,
    ),
    TitoThemeFamily.flatUi => BorderSide.none,
  };

  /// Gamepad / D-pad focus ring painted outside [radius].
  ///
  /// Journal: soft-yellow highlighter double ring. Solid Plastic: white rim
  /// with a cyan glow. Flat UI: thick ink outline with a small gap.
  BoxDecoration focusRing(BorderRadius radius) => BoxDecoration(
    borderRadius: radius,
    boxShadow: switch (family) {
      TitoThemeFamily.trainerJournal => const [
        BoxShadow(color: Color(0xFFAE9562), spreadRadius: 4.5),
        BoxShadow(color: TitoColors.softYellow, spreadRadius: 3),
      ],
      TitoThemeFamily.solidPlastic => const [
        BoxShadow(color: Color(0xF2B9DFE7), blurRadius: 14, spreadRadius: 4),
        BoxShadow(color: Color(0xF2FFFFFF), spreadRadius: 2),
      ],
      TitoThemeFamily.flatUi => const [
        BoxShadow(color: TitoColors.flatOnSurface, spreadRadius: 5),
        BoxShadow(color: TitoColors.flatSurface, spreadRadius: 1.5),
      ],
    },
  );

  /// Optional highlighter wash painted over the focused control (Journal).
  Color? get focusWash => isJournal ? const Color(0x24F7D977) : null;

  /// Display numerals / big headings with the theme's tracking. Flat UI
  /// uses heavier, tighter numerals.
  ///
  /// A null [color] inherits the ambient [DefaultTextStyle] — inside a
  /// [StickerCard] hero that is the role tint's ink, so the same call works
  /// on light and dark heroes. Pass [pageInk] for text sitting on the page.
  TextStyle display(double fontSize, {Color? color, FontWeight? weight}) =>
      _skinText(
        fontSize: fontSize,
        fontWeight: weight ?? (isJournal ? FontWeight.w700 : FontWeight.w800),
        color: color,
        height: 0.95,
        letterSpacing: fontSize * displayTracking,
      );

  /// Section / card heading with the theme's tracking. A null [color]
  /// inherits the ambient [DefaultTextStyle] like [display].
  TextStyle heading(double fontSize, {Color? color}) => _skinText(
    fontSize: fontSize,
    fontWeight: FontWeight.w800,
    color: color,
    letterSpacing: fontSize * headingTracking,
  );

  static TextStyle _skinText({
    required double fontSize,
    required FontWeight fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: TitoTypography.fontFamily,
    fontFamilyFallback: const [
      'Noto Sans CJK SC',
      'Noto Sans SC',
      'sans-serif',
    ],
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  @override
  TitoSkin copyWith({
    Color? pageInk,
    Color? pageMutedInk,
    Color? paper,
    Color? paperDense,
    Color? ink,
    Color? mutedInk,
    Color? accentInkOnLight,
    Color? accentInkOnDark,
    Color? primaryFill,
    Color? onPrimaryFill,
  }) => TitoSkin(
    family: family,
    pageInk: pageInk ?? this.pageInk,
    pageMutedInk: pageMutedInk ?? this.pageMutedInk,
    paper: paper ?? this.paper,
    paperDense: paperDense ?? this.paperDense,
    ink: ink ?? this.ink,
    mutedInk: mutedInk ?? this.mutedInk,
    outline: outline,
    outlineWidth: outlineWidth,
    accentInkOnLight: accentInkOnLight ?? this.accentInkOnLight,
    accentInkOnDark: accentInkOnDark ?? this.accentInkOnDark,
    primaryFill: primaryFill ?? this.primaryFill,
    onPrimaryFill: onPrimaryFill ?? this.onPrimaryFill,
    chipFill: chipFill,
    chipSelectedFill: chipSelectedFill,
    onChipSelected: onChipSelected,
    sheetFill: sheetFill,
    ruleColor: ruleColor,
    tapeColor: tapeColor,
    radiusSm: radiusSm,
    radiusMd: radiusMd,
    radiusLg: radiusLg,
    radiusHero: radiusHero,
    heroTiltDegrees: heroTiltDegrees,
    headingTracking: headingTracking,
    displayTracking: displayTracking,
  );

  // Skins are discrete materials: snap at the midpoint of a theme animation
  // instead of blending paper into plastic.
  @override
  TitoSkin lerp(covariant TitoSkin? other, double t) =>
      other == null || t < 0.5 ? this : other;
}
