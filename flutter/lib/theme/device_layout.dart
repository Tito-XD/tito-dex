import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'tito_colors.dart';
import 'tito_font_scale.dart';

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

  /// Unified handheld UI scale relative to original 1× baseline (v0.2.18 used 2.0).
  static const double handheldUiScale = 1.5;

  /// Extra boost for home subtitles / quick-action labels (on top of [handheldUiScale]).
  static const double homeDetailBoost = 1.5;

  static double homeDetailMultiplier(BuildContext context) {
    if (isNativeTarget || useSquareDashboard(context)) {
      return handheldUiScale * homeDetailBoost;
    }
    return 1.0;
  }

  static double uiScale(BuildContext context) {
    final scope = TitoFontScale.maybeOf(context);
    if (scope != null) {
      return scope.multiplier;
    }
    if (isNativeTarget || useSquareDashboard(context)) {
      return handheldUiScale;
    }
    return 1.0;
  }

  static double fontMultiplier(BuildContext context) => uiScale(context);

  /// Scale layout values that were sized for v0.2.18's 2× handheld chrome.
  static double dim(BuildContext context, double at2xHandheld) {
    if (isNativeTarget || useSquareDashboard(context) || isCompact(context)) {
      return at2xHandheld * (uiScale(context) / 2.0);
    }
    return at2xHandheld;
  }

  static double radius(BuildContext context, double base) {
    if (isNativeTarget || useSquareDashboard(context)) {
      return base * 0.5;
    }
    return base;
  }

  static double rSm(BuildContext context) => radius(context, TitoRadii.sm);
  static double rMd(BuildContext context) => radius(context, TitoRadii.md);
  static double rLg(BuildContext context) => radius(context, TitoRadii.lg);

  static double headerIconSize(BuildContext context) {
    final raw = useSquareDashboard(context)
        ? 72.0
        : (isCompact(context) ? 68.0 : 80.0);
    return dim(context, raw);
  }

  static double headerTitleSize(BuildContext context) {
    final raw = useSquareDashboard(context)
        ? 44.0
        : (isCompact(context) ? 40.0 : 52.0);
    return dim(context, raw);
  }

  static double headerBarHeight(BuildContext context) {
    final raw = useSquareDashboard(context)
        ? 80.0
        : (isCompact(context) ? 72.0 : 80.0);
    return dim(context, raw);
  }

  static double dexBackControlSize(BuildContext context) {
    final raw = useSquareDashboard(context)
        ? 56.0
        : (isCompact(context) ? 48.0 : 40.0);
    return dim(context, raw);
  }

  static double dexBackIconSize(BuildContext context) {
    final raw = useSquareDashboard(context)
        ? 72.0
        : (isCompact(context) ? 64.0 : 56.0);
    return dim(context, raw);
  }

  /// Back arrow — larger touch target, independent of title font size.
  static double backIconSize(BuildContext context) => dexBackIconSize(context);

  static double trainerMicroCardHeight(BuildContext context) =>
      dim(context, 116.0);

  static double trainerMicroAvatarSize(BuildContext context) =>
      dim(context, 56.0);

  static double trainerDenseAvatarSize(BuildContext context) =>
      dim(context, 44.0);

  static double quickTileIconSize(BuildContext context, {bool square = false}) {
    final raw = square ? 30.0 : 18.0;
    return dim(context, raw) *
        (square && (isNativeTarget || useSquareDashboard(context))
            ? homeDetailBoost
            : 1.0);
  }

  static double statusIconSize(BuildContext context, {bool compact = false}) =>
      dim(context, compact ? 18.0 : 16.0);

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
      return 0.82;
    }
    if (columns == 3) {
      return 0.86;
    }
    return 0.78;
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
