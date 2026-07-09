import 'dart:async';

import 'package:flutter/material.dart';

import '../navigation/tito_page_transition.dart';

/// M4 loading gate: delay skeleton 120ms, keep at least 200ms before swap.
class TitoSkeletonGate extends StatefulWidget {
  const TitoSkeletonGate({
    super.key,
    required this.loading,
    required this.skeleton,
    required this.child,
    this.placeholder = const SizedBox.shrink(),
  });

  final bool loading;
  final Widget skeleton;
  final Widget child;
  final Widget placeholder;

  @override
  State<TitoSkeletonGate> createState() => _TitoSkeletonGateState();
}

class _TitoSkeletonGateState extends State<TitoSkeletonGate> {
  bool _showSkeleton = false;
  Timer? _delayTimer;
  DateTime? _skeletonShownAt;

  @override
  void initState() {
    super.initState();
    _sync(widget.loading);
  }

  @override
  void didUpdateWidget(covariant TitoSkeletonGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading != widget.loading) {
      _sync(widget.loading);
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  void _sync(bool loading) {
    _delayTimer?.cancel();
    if (loading) {
      _delayTimer = Timer(TitoMotion.skeletonDelay, () {
        if (!mounted || !widget.loading) {
          return;
        }
        setState(() {
          _showSkeleton = true;
          _skeletonShownAt = DateTime.now();
        });
      });
      return;
    }

    if (!_showSkeleton) {
      setState(() => _showSkeleton = false);
      return;
    }

    final shownAt = _skeletonShownAt ?? DateTime.now();
    final remaining =
        TitoMotion.skeletonMinVisible - DateTime.now().difference(shownAt);
    if (remaining <= Duration.zero) {
      setState(() {
        _showSkeleton = false;
        _skeletonShownAt = null;
      });
      return;
    }

    _delayTimer = Timer(remaining, () {
      if (!mounted || widget.loading) {
        return;
      }
      setState(() {
        _showSkeleton = false;
        _skeletonShownAt = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.loading) {
      return widget.child;
    }
    if (_showSkeleton) {
      return widget.skeleton;
    }
    return widget.placeholder;
  }
}
