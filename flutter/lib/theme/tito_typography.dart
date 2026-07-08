import 'package:flutter/material.dart';

import 'device_layout.dart';
import 'tito_colors.dart';

/// TitoDex typography — always uses bundled Nunito, never bare system font.
abstract final class TitoTypography {
  static const fontFamily = 'Nunito';

  static TextStyle style({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color color = TitoColors.ink,
    double? height,
    double? letterSpacing,
  }) {
    return _base(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle _base({
    required double fontSize,
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

  static double _sz(BuildContext context, double normal, double square) {
    return DeviceLayout.useSquareDashboard(context) ? square : normal;
  }

  /// Large titles on the blue gradient shell (Dex, Search, etc.).
  static TextStyle pageTitleOnGradient(BuildContext context) => _base(
        fontSize: _sz(context, 22, 14),
        fontWeight: FontWeight.w800,
        color: TitoColors.card,
        letterSpacing: -0.3,
      );

  static TextStyle pageSubtitleOnGradient(BuildContext context) => _base(
        fontSize: _sz(context, 14, 12),
        fontWeight: FontWeight.w600,
        color: TitoColors.card,
        height: 1.35,
      );

  static TextStyle pageNoteOnGradient(BuildContext context) => _base(
        fontSize: _sz(context, 14, 12),
        fontWeight: FontWeight.w700,
        color: TitoColors.card,
      );

  /// Cream / sky / mint sticker card content.
  static TextStyle cardTitle(BuildContext context) => _base(
        fontSize: _sz(context, 18, 13),
        fontWeight: FontWeight.w800,
      );

  static TextStyle cardSectionTitle(BuildContext context) => _base(
        fontSize: _sz(context, 16, 12),
        fontWeight: FontWeight.w900,
      );

  static TextStyle cardBody(BuildContext context) => _base(
        fontSize: _sz(context, 14, 11),
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  static TextStyle cardBodyStrong(BuildContext context) => cardBody(context).copyWith(
        fontWeight: FontWeight.w700,
      );

  static TextStyle cardBodyEmphasis(BuildContext context) => cardBody(context).copyWith(
        fontWeight: FontWeight.w800,
      );

  static TextStyle cardMuted(BuildContext context) => _base(
        fontSize: _sz(context, 12, 11),
        fontWeight: FontWeight.w600,
        color: TitoColors.mutedInk,
      );

  static TextStyle cardLabel(BuildContext context) => _base(
        fontSize: _sz(context, 14, 12),
        fontWeight: FontWeight.w600,
        color: TitoColors.mutedInk,
      );

  static TextStyle cardValue(BuildContext context) => _base(
        fontSize: _sz(context, 14, 12),
        fontWeight: FontWeight.w800,
      );

  static TextStyle cardValueLarge(BuildContext context) => _base(
        fontSize: _sz(context, 18, 13),
        fontWeight: FontWeight.w900,
      );

  /// Deep-blue sticker cards.
  static TextStyle onDeepTitle(BuildContext context) => _base(
        fontSize: _sz(context, 22, 18),
        fontWeight: FontWeight.w800,
        color: TitoColors.card,
        letterSpacing: -0.3,
      );

  static TextStyle onDeepSubtitle(BuildContext context) => _base(
        fontSize: _sz(context, 14, 12),
        fontWeight: FontWeight.w600,
        color: TitoColors.skyBlue,
      );

  static TextStyle onDeepMetaLabel(BuildContext context) => _base(
        fontSize: _sz(context, 12, 10),
        fontWeight: FontWeight.w700,
        color: TitoColors.skyBlue,
      );

  static TextStyle onDeepMetaValue(BuildContext context) => _base(
        fontSize: _sz(context, 14, 12),
        fontWeight: FontWeight.w800,
        color: TitoColors.card,
      );

  static TextStyle onDeepOverline(BuildContext context) => _base(
        fontSize: _sz(context, 12, 10),
        fontWeight: FontWeight.w700,
        color: TitoColors.skyBlue,
        letterSpacing: 0.8,
      );

  static TextStyle onDeepHeading(BuildContext context) => _base(
        fontSize: _sz(context, 20, 13),
        fontWeight: FontWeight.w800,
        color: TitoColors.card,
        letterSpacing: -0.3,
      );

  /// Small utility styles.
  static TextStyle overline(BuildContext context) => _base(
        fontSize: _sz(context, 11, 10),
        fontWeight: FontWeight.w700,
        color: TitoColors.mutedInk,
        letterSpacing: 0.8,
      );

  static TextStyle caption(BuildContext context) => _base(
        fontSize: _sz(context, 12, 10),
        fontWeight: FontWeight.w600,
        color: TitoColors.mutedInk,
      );

  static TextStyle captionStrong(BuildContext context) => caption(context).copyWith(
        fontWeight: FontWeight.w800,
      );

  static TextStyle chip(BuildContext context) => _base(
        fontSize: _sz(context, 12, 11),
        fontWeight: FontWeight.w800,
      );

  static TextStyle statusBadge(BuildContext context) => _base(
        fontSize: _sz(context, 10, 9),
        fontWeight: FontWeight.w800,
      );

  static TextStyle dexNumber(BuildContext context) => _base(
        fontSize: _sz(context, 11, 10),
        fontWeight: FontWeight.w700,
        color: TitoColors.mutedInk,
      );

  static TextStyle settingsTitle(BuildContext context) => _base(
        fontSize: _sz(context, 24, 20),
        fontWeight: FontWeight.w800,
        color: TitoColors.card,
      );

  static TextStyle accentCoral(BuildContext context) => _base(
        fontSize: _sz(context, 14, 12),
        fontWeight: FontWeight.w800,
        color: TitoColors.coral,
      );

  static TextStyle companionBubble(BuildContext context) => _base(
        fontSize: _sz(context, 13, 12),
        fontWeight: FontWeight.w700,
      );

  static TextStyle companionName(BuildContext context) => _base(
        fontSize: _sz(context, 12, 11),
        fontWeight: FontWeight.w800,
        color: TitoColors.card,
      );

  static TextStyle navLabel(BuildContext context, {required bool selected}) =>
      _base(
        fontSize: _sz(context, 10, 8),
        fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
        color: selected ? TitoColors.deepBlue : TitoColors.skyBlue,
      );

  static TextStyle quickTileLabel(BuildContext context) => _base(
        fontSize: _sz(context, 13, 9),
        fontWeight: FontWeight.w800,
        color: TitoColors.deepBlue,
      );
}

/// Shorthand: `context.tito.cardTitle`
extension TitoTextContext on BuildContext {
  TitoTextStyles get tito => TitoTextStyles(this);
}

final class TitoTextStyles {
  const TitoTextStyles(this.context);

  final BuildContext context;

  TextStyle get pageTitleOnGradient =>
      TitoTypography.pageTitleOnGradient(context);
  TextStyle get pageSubtitleOnGradient =>
      TitoTypography.pageSubtitleOnGradient(context);
  TextStyle get pageNoteOnGradient => TitoTypography.pageNoteOnGradient(context);
  TextStyle get cardTitle => TitoTypography.cardTitle(context);
  TextStyle get cardSectionTitle => TitoTypography.cardSectionTitle(context);
  TextStyle get cardBody => TitoTypography.cardBody(context);
  TextStyle get cardBodyStrong => TitoTypography.cardBodyStrong(context);
  TextStyle get cardBodyEmphasis => TitoTypography.cardBodyEmphasis(context);
  TextStyle get cardMuted => TitoTypography.cardMuted(context);
  TextStyle get cardLabel => TitoTypography.cardLabel(context);
  TextStyle get cardValue => TitoTypography.cardValue(context);
  TextStyle get cardValueLarge => TitoTypography.cardValueLarge(context);
  TextStyle get onDeepTitle => TitoTypography.onDeepTitle(context);
  TextStyle get onDeepSubtitle => TitoTypography.onDeepSubtitle(context);
  TextStyle get onDeepMetaLabel => TitoTypography.onDeepMetaLabel(context);
  TextStyle get onDeepMetaValue => TitoTypography.onDeepMetaValue(context);
  TextStyle get onDeepOverline => TitoTypography.onDeepOverline(context);
  TextStyle get onDeepHeading => TitoTypography.onDeepHeading(context);
  TextStyle get overline => TitoTypography.overline(context);
  TextStyle get caption => TitoTypography.caption(context);
  TextStyle get captionStrong => TitoTypography.captionStrong(context);
  TextStyle get chip => TitoTypography.chip(context);
  TextStyle get statusBadge => TitoTypography.statusBadge(context);
  TextStyle get dexNumber => TitoTypography.dexNumber(context);
  TextStyle get settingsTitle => TitoTypography.settingsTitle(context);
  TextStyle get accentCoral => TitoTypography.accentCoral(context);
  TextStyle get companionBubble => TitoTypography.companionBubble(context);
  TextStyle get companionName => TitoTypography.companionName(context);
  TextStyle get quickTileLabel => TitoTypography.quickTileLabel(context);
}
