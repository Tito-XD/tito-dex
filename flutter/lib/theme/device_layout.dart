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

  /// RG Rotate and similar ~square handheld screens (e.g. 720×720).
  static bool isSquareHandheld(BuildContext context) {
    if (!isNativeTarget) {
      return false;
    }
    final size = sizeOf(context);
    if (size.shortestSide < 520) {
      return false;
    }
    final ratio = size.width / size.height;
    return ratio > 0.82 && ratio < 1.22;
  }

  /// Short landscape screens (e.g. RG35XX 640×480).
  static bool isShortScreen(BuildContext context) {
    return sizeOf(context).height < 560;
  }

  /// True on RG-like screens: square handheld, short height, or narrow width.
  static bool isCompact(BuildContext context) {
    final size = sizeOf(context);
    return isSquareHandheld(context) ||
        isShortScreen(context) ||
        size.shortestSide < 520;
  }

  /// Dashboard home for square RG screens — not a scaled phone column.
  static bool useSquareDashboard(BuildContext context) {
    return isSquareHandheld(context);
  }

  static EdgeInsets pagePadding(BuildContext context) {
    if (useSquareDashboard(context)) {
      return const EdgeInsets.fromLTRB(10, 4, 10, 2);
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
      return const EdgeInsets.all(10);
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
      return 16;
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
      return 15;
    }
    if (isCompact(context)) {
      return 18;
    }
    return 22;
  }

  static double bodyTextSize(BuildContext context) {
    if (useSquareDashboard(context)) {
      return 12;
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

  /// Clamp Android system font scaling so dense handheld layouts do not overflow.
  static TextScaler clampedTextScaler(BuildContext context) {
    final maxScale = useSquareDashboard(context) ? 1.0 : 1.12;
    return MediaQuery.textScalerOf(context).clamp(maxScaleFactor: maxScale);
  }
}
