import 'package:flutter/material.dart';

/// Depth tokens used by the experimental glass surfaces. The existing Retro
/// style preference still controls whether cards float and press down, but the
/// hard sticker drop is softened into a light-through-glass shadow.
abstract final class TitoShadows {
  static const List<BoxShadow> sticker = [
    BoxShadow(
      color: Color(0x3013263D),
      blurRadius: 22,
      spreadRadius: -5,
      offset: Offset(0, 10),
    ),
  ];

  /// Squashed variant while a pressable sticker is held down.
  static const List<BoxShadow> stickerPressed = [
    BoxShadow(
      color: Color(0x2413263D),
      blurRadius: 10,
      spreadRadius: -4,
      offset: Offset(0, 3),
    ),
  ];

  /// Smaller drop for chips, sprites, and bubbles.
  static const List<BoxShadow> stickerSmall = [
    BoxShadow(
      color: Color(0x2413263D),
      blurRadius: 14,
      spreadRadius: -4,
      offset: Offset(0, 6),
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

  // Experimental Liquid Glass light field. Content colours above stay intact
  // so gameplay semantics and contrast inside tinted surfaces remain stable.
  static const glassBackgroundTop = Color(0xFF314D70);
  static const glassBackgroundMid = Color(0xFF567B99);
  static const glassBackgroundBottom = Color(0xFF7898AA);
  static const glassCyan = Color(0xFF78D8E8);
  static const glassLavender = Color(0xFFC1A7EF);
  static const glassMint = Color(0xFF8EE0C1);
}

abstract final class TitoRadii {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Ink outline widths for the sticker look. The original 3.0 read slightly
/// chunky on phone density — cards/buttons use [card], small circular
/// elements (avatars, companion sticker) use [element].
abstract final class TitoBorders {
  static const card = 1.35;
  static const element = 1.2;
  static const glass = 1.1;
}
