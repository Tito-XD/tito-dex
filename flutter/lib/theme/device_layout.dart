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
    return useSquareDashboard(context) ? 42 : 56;
  }
  static TextScaler clampedTextScaler(BuildContext context) {
    final maxScale = useSquareDashboard(context) ? 1.0 : 1.12;
    return MediaQuery.textScalerOf(context).clamp(maxScaleFactor: maxScale);
  }
}
