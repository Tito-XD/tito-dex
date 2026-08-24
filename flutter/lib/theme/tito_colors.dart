import 'package:flutter/material.dart';

/// Compatibility elevation tokens for the Material 3 experiment.
///
/// Existing widgets still reference the historical sticker token names, but
/// the branch maps them to soft Material elevation so feature code does not
/// need a visual-only rewrite.
abstract final class TitoShadows {
  static const List<BoxShadow> sticker = [
    BoxShadow(
      color: Color(0x261A1C20),
      blurRadius: 8,
      spreadRadius: -2,
      offset: Offset(0, 2),
    ),
  ];

  /// Material controls flatten slightly while pressed.
  static const List<BoxShadow> stickerPressed = [
    BoxShadow(
      color: Color(0x1F1A1C20),
      blurRadius: 3,
      spreadRadius: -1,
      offset: Offset(0, 1),
    ),
  ];

  /// Small Material elevation for chips, sprites, and bubbles.
  static const List<BoxShadow> stickerSmall = [
    BoxShadow(
      color: Color(0x1F1A1C20),
      blurRadius: 4,
      spreadRadius: -1,
      offset: Offset(0, 1),
    ),
  ];
}

abstract final class TitoColors {
  /// Material 3 seed and neutral surfaces for this experimental branch.
  static const materialSeed = Color(0xFF415F91);
  static const materialSurface = Color(0xFFF9F9FF);
  static const materialSurfaceContainer = Color(0xFFECEEF6);
  static const materialSurfaceContainerHigh = Color(0xFFE3E6EF);
  static const materialOnSurface = Color(0xFF1A1C20);
  static const materialOutline = Color(0xFF74777F);

  static const deepBlue = Color(0xFF2F4361);
  static const slateBlue = Color(0xFF7B91A6);
  static const skyBlue = Color(0xFFAFC7DA);
  static const cream = Color(0xFFF3E4B3);
  static const coral = Color(0xFFFF8F6A);
  static const ink = Color(0xFF221F26);
  static const softYellow = Color(0xFFF7D977);
  static const card = Color(0xFFFFF7E6);
  static const cardWarm = Color(0xFFFDF5E6);
  static const mutedInk = Color(0xFF536273);
  static const mint = Color(0xFF7EC8A8);
  static const hpGreen = Color(0xFF6BC4A6);
  static const expGold = Color(0xFFF7D977);
}

abstract final class TitoRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 28.0;
}

/// Compatibility outline widths mapped to Material's restrained separators.
abstract final class TitoBorders {
  static const card = 1.0;
  static const element = 1.0;
}
