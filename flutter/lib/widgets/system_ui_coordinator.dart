import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';

/// Applies immersive UI on RG-like aspect ratios; regular status/nav bars elsewhere.
class SystemUiCoordinator extends StatefulWidget {
  const SystemUiCoordinator({super.key, required this.child});

  final Widget child;

  @override
  State<SystemUiCoordinator> createState() => _SystemUiCoordinatorState();
}

class _SystemUiCoordinatorState extends State<SystemUiCoordinator> {
  Size? _lastSize;

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
    if (_lastSize == size) {
      return;
    }
    _lastSize = size;
    _applySystemUi(size);
  }

  void _applySystemUi(Size size) {
    if (!DeviceLayout.isNativeTarget) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      return;
    }

    if (DeviceLayout.isHandheldPanelSize(size)) {
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
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: TitoColors.deepBlue,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
