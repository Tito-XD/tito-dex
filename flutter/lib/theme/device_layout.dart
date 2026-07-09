import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Layout helpers for real Android/Linux handhelds vs web preview frame.
abstract final class DeviceLayout {
  static bool get isNativeTarget =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.linux);

  static Size sizeOf(BuildContext context) => MediaQuery.sizeOf(context);

  static bool isLandscape(BuildContext context) {
    final size = sizeOf(context);
    return size.width > size.height;
  }

  /// Handheld dashboard: 1:1, 4:3 landscape, or 3:4 portrait — one screen, no scroll.
  static bool useSquareDashboard(BuildContext context) {
    final size = sizeOf(context);
    if (size.shortestSide < 360) {
      return false;
    }
    return isHandheldAspectRatio(size.width / size.height);
  }

  /// True for ~1:1, ~4:3 (landscape), and ~3:4 (portrait) panels.
  static bool isHandheldAspectRatio(double ratio) {
    return _nearAspect(ratio, 1.0, 0.18) ||
        _nearAspect(ratio, 4 / 3, 0.1) ||
        _nearAspect(ratio, 3 / 4, 0.1);
  }

  static bool _nearAspect(double ratio, double target, double tolerance) {
    return (ratio - target).abs() <= tolerance;
  }

  /// ~Square screen by aspect ratio (alias for dashboard detection).
  static bool isSquareScreen(BuildContext context) {
    return useSquareDashboard(context);
  }

  /// RG Rotate native square handheld.
  static bool isSquareHandheld(BuildContext context) {
    return isNativeTarget && isSquareScreen(context);
  }

  /// Short landscape screens (e.g. RG35XX 640×480).
  static bool isShortScreen(BuildContext context) {
    return sizeOf(context).height < 560;
  }

  /// True on RG-like screens: handheld aspect, short height, or narrow width.
  static bool isCompact(BuildContext context) {
    final size = sizeOf(context);
    return useSquareDashboard(context) ||
        isShortScreen(context) ||
        size.shortestSide < 520;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    if (useSquareDashboard(context)) {
      return const EdgeInsets.fromLTRB(8, 2, 8, 0);
    }
    if (isCompact(context)) {
      return const EdgeInsets.fromLTRB(10, 6, 10, 4);
    }
    return const EdgeInsets.fromLTRB(16, 12, 16, 8);
  }

  static double sectionSpacing(BuildContext context) {
    if (useSquareDashboard(context)) {
      return 6;
    }
    if (isCompact(context)) {
      return 10;
    }
    return 14;
  }

  static EdgeInsets cardPadding(BuildContext context) {
    if (useSquareDashboard(context)) {
      return const EdgeInsets.all(8);
    }
    if (isCompact(context)) {
      return const EdgeInsets.all(12);
    }
    return const EdgeInsets.all(16);
  }

  static double gridMaxExtent(BuildContext context) {
    if (useSquareDashboard(context)) {
      return 120;
    }
    if (isCompact(context)) {
      return isLandscape(context) ? 112 : 128;
    }
    return 160;
  }

  /// App bar title on the home header.
  static double? appTitleSize(BuildContext context) {
    if (useSquareDashboard(context)) {
      return 14;
    }
    if (isCompact(context)) {
      return 20;
    }
    return null;
  }

  static double appTitleIconSize(BuildContext context) {
    if (useSquareDashboard(context)) {
      return 20;
    }
    if (isCompact(context)) {
      return 24;
    }
    return 32;
  }

  /// Prominent card headings (location, species name, etc.).
  static double cardHeadingSize(BuildContext context) {
    if (useSquareDashboard(context)) {
      return 13;
    }
    if (isCompact(context)) {
      return 18;
    }
    return 22;
  }

  static double bodyTextSize(BuildContext context) {
    if (useSquareDashboard(context)) {
      return 11;
    }
    if (isCompact(context)) {
      return 13;
    }
    return 14;
  }

  static double captionTextSize(BuildContext context) {
    if (useSquareDashboard(context)) {
      return 10;
    }
    if (isCompact(context)) {
      return 11;
    }
    return 12;
  }

  static double squareQuickTileHeight(BuildContext context) {
    final width = sizeOf(context).width;
    final gap = sectionSpacing(context);
    return useSquareDashboard(context) ? (width - gap * 3) / 4 : 56;
  }

  /// Native handheld UI ignores system font/display scaling — fixed logical layout.
  static TextScaler clampedTextScaler(BuildContext context) {
    if (isNativeTarget) {
      return TextScaler.noScaling;
    }
    return MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.12);
  }

  static double headerIconSize(BuildContext context) {
    if (useSquareDashboard(context)) {
      return 36;
    }
    if (isCompact(context)) {
      return 34;
    }
    return 40;
  }

  static double headerTitleSize(BuildContext context) {
    if (useSquareDashboard(context)) {
      return 22;
    }
    if (isCompact(context)) {
      return 20;
    }
    return 26;
  }

  static double dexBackControlSize(BuildContext context) {
    if (useSquareDashboard(context)) {
      return 16;
    }
    if (isCompact(context)) {
      return 15;
    }
    return 16;
  }

  static int dexGridColumns(BuildContext context) {
    final size = sizeOf(context);
    if (useSquareDashboard(context)) {
      return size.width >= 560 ? 4 : 3;
    }
    if (size.width >= 680 || (size.width > size.height && size.width >= 520)) {
      return 4;
    }
    if (size.width >= 390) {
      return 3;
    }
    return 2;
  }

  static double dexCardAspectRatio(BuildContext context) {
    final columns = dexGridColumns(context);
    if (columns >= 4) {
      return 0.88;
    }
    if (columns == 3) {
      return 0.92;
    }
    return 1.0;
  }

  static double companionOverlayBottom(BuildContext context) {
    if (useSquareDashboard(context)) {
      return squareQuickTileHeight(context) + sectionSpacing(context) + 4;
    }
    if (isCompact(context)) {
      return 12;
    }
    return 16;
  }
}
