import 'package:flutter/material.dart';

/// Soft Material elevation — **Flat UI only**.
///
/// Trainer's Journal must use [TrainerJournalShadows] and Solid Plastic must
/// use [SolidPlasticShadows]; shared widgets pick the recipe by branching on
/// `appVisualStyle`. The historical sticker token names are kept so feature
/// code can switch recipes without a rename. Journal-only colour, stroke and
/// type helpers live in `trainer_journal.dart`.
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

/// Thin paper-edge depth for Trainer's Journal. Keep this separate from Flat
/// UI elevation and Solid Plastic blur so theme switches restore the recipe.
///
/// Cream cards use a short paper lip plus a faint outline. Deep cards use a
/// single muted offset. Small chips, sprites and ordinary labels stay flat.
abstract final class TrainerJournalShadows {
  static const List<BoxShadow> sticker = [
    BoxShadow(color: Color(0xFFE4DFD3), offset: Offset(0, 2)),
    BoxShadow(color: Color(0x2B566A77), offset: Offset(0, 3)),
  ];

  static const List<BoxShadow> stickerPressed = [
    BoxShadow(color: Color(0x24566A77), offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> stickerSmall = [];

  static const List<BoxShadow> deep = [
    BoxShadow(color: Color(0x3321394C), offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> control = [
    BoxShadow(color: Color(0x2B4D6775), offset: Offset(0, 2)),
  ];
}

/// Concentrated moulded depth for Solid Plastic surfaces.
abstract final class SolidPlasticShadows {
  static const List<BoxShadow> sticker = [
    BoxShadow(
      color: Color(0x3313263D),
      blurRadius: 16,
      spreadRadius: -3,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x1813263D),
      blurRadius: 3,
      spreadRadius: -1,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> stickerSmall = [
    BoxShadow(
      color: Color(0x2A13263D),
      blurRadius: 11,
      spreadRadius: -3,
      offset: Offset(0, 5),
    ),
  ];

  static const List<BoxShadow> stickerPressed = [
    BoxShadow(
      color: Color(0x2413263D),
      blurRadius: 7,
      spreadRadius: -3,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> glassSmall = [
    BoxShadow(
      color: Color(0x2A13263D),
      blurRadius: 10,
      spreadRadius: -3,
      offset: Offset(0, 4),
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

  // Solid Plastic keeps a cool hardware shell underneath the optical layers.
  // The accents are deliberately milky instead of neon so translucent edges
  // read as moulded plastic rather than a fully transparent glass sheet.
  static const glassBackgroundTop = Color(0xFF344D6B);
  static const glassBackgroundMid = Color(0xFF58768F);
  static const glassBackgroundBottom = Color(0xFF758FA2);
  static const glassCyan = Color(0xFFB9DFE7);
  static const glassLavender = Color(0xFFD7CDEA);
  static const glassMint = Color(0xFFBFE2D4);
}

abstract final class TitoRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 28.0;
}

/// Outline widths. Never write literal widths in widgets — pick the token
/// that matches the surface size. [card] and [element] stay at the historical
/// 2.0 / 1.5 values used by Flat UI fallbacks; Trainer's Journal reads the
/// `journal*` tokens instead so the other themes do not get thinner strokes.
abstract final class TitoBorders {
  /// Cards, buttons, text fields, sheets, dialogs (Flat UI / historical).
  static const card = 2.0;

  /// Chips, badges, small controls, knobs, checkbox/radio rings (historical).
  static const element = 1.5;

  /// Solid Plastic hairline used by `LiquidGlassSurface` and glass outlines.
  static const glass = 1.1;

  /// Trainer's Journal main cards, buttons, fields, sheets, dialogs.
  static const journalCard = 1.25;

  /// Trainer's Journal chips, badges, small controls, knobs.
  static const journalElement = 0.85;

  /// Trainer's Journal hairlines and empty-slot dashes.
  static const journalHairline = 0.75;
}
