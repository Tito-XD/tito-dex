import 'package:flutter/material.dart';

import 'tito_colors.dart';
import 'tito_typography.dart';

/// Fixed logical-pixel typography for secondary routes (Team, Journey, Dex, …).
///
/// ## Dex Typography Spec (secondary pages)
///
/// Reference: Pokédex list/detail (v0.2.23+). Use with [TitoFontScale] `multiplier: 1.0`
/// on every secondary route except the home dashboard (Team, Journey, Dex, Search,
/// Settings, companion battle tools, …).
///
/// | Tier | px | Token | Use |
/// |------|-----|-------|-----|
/// | Page title | 22.5 | `onGradient.title` | App bar «← 图鉴» |
/// | Section | 15 | `h15` | Card headings, tab context |
/// | Body / meta | 14 | `body14` / `meta14` | Descriptions, values, tab labels |
/// | Small / team | 12 | `small12` / `team12` | Hints, HP row, bottom tabs |
///
/// **Home dashboard** intentionally uses a separate scale (1.5×–2.25×) — do not apply
/// this spec there. See `docs/TYPOGRAPHY.md`.
///
/// Sizes are not scaled by [DeviceLayout.handheldUiScale] when using these tokens directly.
abstract final class SecondaryTypography {
  static const onGradient = _SecondaryOnGradient();
  static const onCard = _SecondaryOnCard();

  /// Handheld secondary-page size remap: 10→12, 11→14, 12→14, 13→15.
  static TextStyle remap(TextStyle style) {
    final size = style.fontSize;
    if (size == null) {
      return style;
    }
    final mapped = switch (size.round()) {
      10 => 12.0,
      11 => 14.0,
      12 => 14.0,
      13 => 15.0,
      _ => size,
    };
    if (mapped == size) {
      return style;
    }
    return style.copyWith(fontSize: mapped);
  }
}

/// Text on the blue gradient shell (cream / white ink).
final class _SecondaryOnGradient {
  const _SecondaryOnGradient();

  /// Page header title — 22.5px white on gradient.
  TextStyle get title => TitoTypography.style(
        fontSize: 22.5,
        fontWeight: FontWeight.w800,
        color: TitoColors.card,
        letterSpacing: -0.3,
      );

  TextStyle get h15 => TitoTypography.style(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: TitoColors.card,
        letterSpacing: 15 * -0.02,
      );

  TextStyle get body14 => TitoTypography.style(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: TitoColors.card,
        height: 1.4,
      );

  TextStyle get small12 => TitoTypography.style(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: TitoColors.card,
      );

  TextStyle get meta14 => TitoTypography.style(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: TitoColors.card,
      );

  TextStyle get team12 => TitoTypography.style(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: TitoColors.card,
      );
}

/// Text on cream / sky / mint sticker cards (ink).
final class _SecondaryOnCard {
  const _SecondaryOnCard();

  TextStyle get h15 => TitoTypography.style(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 15 * -0.02,
      );

  TextStyle get body14 => TitoTypography.style(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  TextStyle get small12 => TitoTypography.style(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      );

  TextStyle get meta14 => TitoTypography.style(
        fontSize: 14,
        fontWeight: FontWeight.w800,
      );

  /// Team row name / level / slot / HP.
  TextStyle get team12 => TitoTypography.style(
        fontSize: 12,
        fontWeight: FontWeight.w800,
      );
}

extension SecondaryTextContext on BuildContext {
  SecondaryTextStyles get secondary => const SecondaryTextStyles();
}

final class SecondaryTextStyles {
  const SecondaryTextStyles();

  TextStyle get h15 => SecondaryTypography.onCard.h15;

  TextStyle get small12 => SecondaryTypography.onCard.small12;

  TextStyle get small12Strong =>
      SecondaryTypography.onCard.small12.copyWith(fontWeight: FontWeight.w800);

  TextStyle get body14Strong =>
      SecondaryTypography.onCard.body14.copyWith(fontWeight: FontWeight.w700);

  TextStyle get team12 => SecondaryTypography.onCard.team12;

  TextStyle get team12Strong => SecondaryTypography.onCard.team12;

  TextStyle body14({
    Color? color,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
  }) =>
      SecondaryTypography.onCard.body14.copyWith(
        color: color,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
      );

  TextStyle meta14({Color? color, FontWeight? fontWeight}) =>
      SecondaryTypography.onCard.meta14.copyWith(
        color: color,
        fontWeight: fontWeight,
      );

  TextStyle remap(TextStyle style) => SecondaryTypography.remap(style);
}
