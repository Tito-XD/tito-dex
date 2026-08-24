import 'package:flutter/material.dart';

import '../theme/motion_preferences.dart';
import '../theme/tito_motion.dart';

/// A restrained fade-through for keyed page sections.
///
/// Numeric keys also communicate direction: moving to a larger value enters
/// from the right, while moving back enters from the left. The surrounding
/// height follows the incoming child instead of snapping between layouts.
class TitoAnimatedSizeSwitcher extends StatefulWidget {
  const TitoAnimatedSizeSwitcher({
    super.key,
    required this.switchKey,
    required this.child,
    this.alignment = Alignment.topCenter,
    this.duration = TitoMotion.standard,
    this.movement = TitoMotion.switchTravel,
  });

  final Key switchKey;
  final Widget child;
  final Alignment alignment;
  final Duration duration;
  final double movement;

  @override
  State<TitoAnimatedSizeSwitcher> createState() =>
      _TitoAnimatedSizeSwitcherState();
}

class _TitoAnimatedSizeSwitcherState extends State<TitoAnimatedSizeSwitcher> {
  double _direction = 1;

  @override
  void initState() {
    super.initState();
    motionPreferences.addListener(_handleMotionPreferenceChanged);
  }

  void _handleMotionPreferenceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(TitoAnimatedSizeSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = _numericKeyValue(oldWidget.switchKey);
    final next = _numericKeyValue(widget.switchKey);
    if (previous != null && next != null && previous != next) {
      _direction = next > previous ? 1 : -1;
    }
  }

  static double? _numericKeyValue(Key key) {
    if (key is ValueKey<int>) {
      return key.value.toDouble();
    }
    if (key is ValueKey<double>) {
      return key.value;
    }
    if (key is ValueKey<num>) {
      return key.value.toDouble();
    }
    return null;
  }

  @override
  void dispose() {
    motionPreferences.removeListener(_handleMotionPreferenceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (TitoMotion.disabled(context) || widget.duration == Duration.zero) {
      return KeyedSubtree(key: widget.switchKey, child: widget.child);
    }

    final outgoingDuration = Duration(
      milliseconds: (widget.duration.inMilliseconds * 0.72).round(),
    );

    return AnimatedSize(
      duration: TitoMotion.emphasized,
      curve: Curves.easeOutCubic,
      alignment: widget.alignment,
      clipBehavior: Clip.hardEdge,
      child: AnimatedSwitcher(
        duration: widget.duration,
        reverseDuration: outgoingDuration,
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
        layoutBuilder: (currentChild, previousChildren) {
          if (currentChild == null) {
            return const SizedBox.shrink();
          }
          return Stack(
            alignment: widget.alignment,
            clipBehavior: Clip.hardEdge,
            children: [
              for (final previous in previousChildren)
                ExcludeSemantics(child: IgnorePointer(child: previous)),
              currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final incoming = child.key == widget.switchKey;
          final opacity = CurvedAnimation(
            parent: animation,
            curve: incoming
                ? const Interval(0.14, 1, curve: Curves.easeOutCubic)
                : Curves.easeInCubic,
          );
          return AnimatedBuilder(
            animation: opacity,
            child: child,
            builder: (context, child) {
              final travel =
                  widget.movement *
                  _direction *
                  (incoming ? 1 : -1) *
                  (1 - opacity.value);
              return Opacity(
                opacity: opacity.value.clamp(0, 1),
                child: Transform.translate(
                  key: ValueKey<Key?>(child?.key),
                  offset: Offset(travel, 0),
                  child: child,
                ),
              );
            },
          );
        },
        child: KeyedSubtree(key: widget.switchKey, child: widget.child),
      ),
    );
  }
}
