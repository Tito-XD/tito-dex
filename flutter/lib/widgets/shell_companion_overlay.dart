import 'package:flutter/material.dart';

import '../navigation/tito_page_transition.dart';
import 'companion_sticker.dart';

/// M5 — companion fades and shifts when leaving Home (shell-level overlay).
class ShellCompanionOverlay extends StatefulWidget {
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
  State<ShellCompanionOverlay> createState() => _ShellCompanionOverlayState();
}

class _ShellCompanionOverlayState extends State<ShellCompanionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _mountedVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: TitoMotion.companionDuration,
    );
    if (widget.onHome) {
      _mountedVisible = true;
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant ShellCompanionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onHome && !oldWidget.onHome) {
      setState(() => _mountedVisible = true);
      _controller.forward(from: 0);
    } else if (!widget.onHome && oldWidget.onHome) {
      _controller.reverse().whenComplete(() {
        if (mounted && !widget.onHome) {
          setState(() => _mountedVisible = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_mountedVisible && !_controller.isAnimating) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = TitoMotion.companionCurve.transform(_controller.value);
        return IgnorePointer(
          ignoring: !widget.onHome,
          child: Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(8 * (1 - t), 8 * (1 - t)),
              child: child,
            ),
          ),
        );
      },
      child: FloatingCompanion(
        name: widget.companionName,
        onTap: widget.onTap,
      ),
    );
  }
}
