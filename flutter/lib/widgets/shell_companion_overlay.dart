import 'package:flutter/material.dart';

import 'companion_sticker.dart';

/// The companion is present only on Home; route motion is provided by Android.
class ShellCompanionOverlay extends StatelessWidget {
  const ShellCompanionOverlay({
    super.key,
    required this.onHome,
    required this.companionName,
    this.onTap,
  });

  final bool onHome;
  final String companionName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (!onHome) {
      return const SizedBox.shrink();
    }
    return FloatingCompanion(name: companionName, onTap: onTap);
  }
}
