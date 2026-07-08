import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Layout helpers for real Android/Linux handhelds vs web preview frame.
abstract final class DeviceLayout {
  static bool get isNativeTarget =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// True on RG-like screens: short height or narrow width.
  static bool isCompact(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.height < 680 || size.shortestSide < 520;
  }

  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    if (isCompact(context)) {
      return const EdgeInsets.fromLTRB(10, 6, 10, 4);
    }
    return const EdgeInsets.fromLTRB(16, 12, 16, 8);
  }

  static double gridMaxExtent(BuildContext context) {
    if (isCompact(context)) {
      return isLandscape(context) ? 120 : 140;
    }
    return 160;
  }
}
