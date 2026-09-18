import 'package:flutter/material.dart';
import '../theme/tito_motion.dart';

/// Retains forms, controllers and scroll positions while softly revealing a tab.
class BattleContentFade extends StatefulWidget {
  const BattleContentFade({
    super.key,
    required this.changeKey,
    required this.child,
  });
  final Object? changeKey;
  final Widget child;
  @override
  State<BattleContentFade> createState() => _BattleContentFadeState();
}

class _BattleContentFadeState extends State<BattleContentFade>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: TitoMotion.standard,
    value: 1,
  );
  late final curve = CurvedAnimation(
    parent: controller,
    curve: Curves.easeOutCubic,
  );
  late final opacity = Tween<double>(begin: .75, end: 1).animate(curve);
  @override
  void didUpdateWidget(covariant BattleContentFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.changeKey != widget.changeKey) {
      if (TitoMotion.disabled(context)) {
        controller.value = 1;
      } else {
        controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    curve.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: opacity, child: widget.child);
}
