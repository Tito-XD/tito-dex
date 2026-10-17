import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_visual_style.dart';
import '../theme/device_layout.dart';
import '../theme/tito_skin.dart';

/// Applies immersive UI on RG-like aspect ratios; regular status/nav bars elsewhere.
class SystemUiCoordinator extends StatefulWidget {
  const SystemUiCoordinator({super.key, required this.child});

  final Widget child;

  @override
  State<SystemUiCoordinator> createState() => _SystemUiCoordinatorState();
}

class _SystemUiCoordinatorState extends State<SystemUiCoordinator> {
  Size? _lastSize;
  AppVisualStyle? _lastStyle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyForContext(context);
  }

  @override
  void didUpdateWidget(SystemUiCoordinator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyForContext(context);
  }

  void _applyForContext(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final style = appVisualStyle.style;
    if (_lastSize == size && _lastStyle == style) {
      return;
    }
    _lastSize = size;
    _lastStyle = style;
    _applySystemUi(size, skin: TitoSkin.forStyle(style));
  }

  void _applySystemUi(Size size, {required TitoSkin skin}) {
    if (!DeviceLayout.isNativeTarget) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      return;
    }

    if (DeviceLayout.isHandheldPlatform &&
        DeviceLayout.isHandheldPanelSize(size)) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: const [],
      );
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: skin.pageIsDark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: skin.pageIsDark
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: skin.systemBarColor,
        systemNavigationBarIconBrightness: skin.pageIsDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
