import 'package:flutter/material.dart';

/// Compatibility elevation tokens for the Flat UI experiment.
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

/// The hard, unblurred depth that gives Trainer's Journal its physical
/// sticker-button press. Keep this separate from Flat UI elevation so changing
/// themes immediately restores the original motion and shadow recipe.
abstract final class TrainerJournalShadows {
  static const List<BoxShadow> sticker = [
    BoxShadow(color: Color(0x3818283B), offset: Offset(0, 5)),
  ];

  static const List<BoxShadow> stickerPressed = [
    BoxShadow(color: Color(0x3818283B), offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> stickerSmall = [
    BoxShadow(color: Color(0x2818283B), offset: Offset(0, 3)),
  ];
}

/// Softer depth for translucent Solid Plastic surfaces.
abstract final class SolidPlasticShadows {
  static const List<BoxShadow> sticker = [
    BoxShadow(
      color: Color(0x3013263D),
      blurRadius: 22,
      spreadRadius: -5,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> stickerSmall = [
    BoxShadow(
      color: Color(0x2413263D),
      blurRadius: 14,
      spreadRadius: -4,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> stickerPressed = [
    BoxShadow(
      color: Color(0x2413263D),
      blurRadius: 10,
      spreadRadius: -4,
      offset: Offset(0, 3),
    ),
  ];

  static const List<BoxShadow> glassSmall = [
    BoxShadow(
      color: Color(0x2613263D),
      blurRadius: 16,
      spreadRadius: -4,
      offset: Offset(0, 7),
    ),
  ];
}

abstract final class TitoColors {
  /// Flat UI seed and neutral surfaces for this experimental branch.
  static const flatSeed = Color(0xFF415F91);
  static const flatSurface = Color(0xFFF9F9FF);
  static const flatSurfaceContainer = Color(0xFFECEEF6);
  static const flatSurfaceContainerHigh = Color(0xFFE3E6EF);
  static const flatOnSurface = Color(0xFF1A1C20);
  static const flatOutline = Color(0xFF74777F);

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

  static const glassBackgroundTop = Color(0xFF314D70);
  static const glassBackgroundMid = Color(0xFF567B99);
  static const glassBackgroundBottom = Color(0xFF7898AA);
  static const glassCyan = Color(0xFF78D8E8);
  static const glassLavender = Color(0xFFC1A7EF);
  static const glassMint = Color(0xFF8EE0C1);
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
  static const glass = 1.1;
}
