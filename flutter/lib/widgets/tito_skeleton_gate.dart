import 'dart:async';

import 'package:flutter/material.dart';

/// Loading gate: delay skeleton 120ms, keep it visible for at least 200ms.
///
/// This controls when static placeholders appear; it does not animate them.
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
  static const _skeletonDelay = Duration(milliseconds: 120);
  static const _skeletonMinVisible = Duration(milliseconds: 200);

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
      _delayTimer = Timer(_skeletonDelay, () {
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
    final remaining = _skeletonMinVisible - DateTime.now().difference(shownAt);
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
