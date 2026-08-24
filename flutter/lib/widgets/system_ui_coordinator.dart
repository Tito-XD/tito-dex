import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_visual_style.dart';
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
  bool? _lastUsesMaterial;

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
    final material = appVisualStyle.usesMaterial;
    if (_lastSize == size && _lastUsesMaterial == material) {
      return;
    }
    _lastSize = size;
    _lastUsesMaterial = material;
    _applySystemUi(
      size,
      material: material,
      materialSurface: Theme.of(context).colorScheme.surface,
    );
  }

  void _applySystemUi(
    Size size, {
    required bool material,
    required Color materialSurface,
  }) {
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
        statusBarIconBrightness: material ? Brightness.dark : Brightness.light,
        statusBarBrightness: material ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: material
            ? materialSurface
            : TitoColors.deepBlue,
        systemNavigationBarIconBrightness: material
            ? Brightness.dark
            : Brightness.light,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
