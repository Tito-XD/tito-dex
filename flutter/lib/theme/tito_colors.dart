import 'package:flutter/material.dart';

/// Signature sticker shadows — solid offset drops with no blur, the
/// "physical key" look. Applied globally when Retro style is on.
abstract final class TitoShadows {
  static const List<BoxShadow> sticker = [
    BoxShadow(color: Color(0x3818283B), offset: Offset(0, 5)),
  ];

  /// Squashed variant while a pressable sticker is held down.
  static const List<BoxShadow> stickerPressed = [
    BoxShadow(color: Color(0x3818283B), offset: Offset(0, 1)),
  ];

  /// Smaller drop for chips, sprites, and bubbles.
  static const List<BoxShadow> stickerSmall = [
    BoxShadow(color: Color(0x2818283B), offset: Offset(0, 3)),
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
  static const card = 2.5;
  static const element = 2.0;
}
