import 'dart:async';

import 'package:flutter/widgets.dart';

/// Fast reads never flash a loader. Ready content is never held artificially.
/// The owner removes this widget as soon as the real content is ready.
class TitoDelayedLoading extends StatefulWidget {
  const TitoDelayedLoading({
    super.key,
    required this.child,
    this.placeholder = const SizedBox.shrink(),
    this.delay = const Duration(milliseconds: 160),
  });

  final Widget child;
  final Widget placeholder;
  final Duration delay;

  @override
  State<TitoDelayedLoading> createState() => _TitoDelayedLoadingState();
}

class _TitoDelayedLoadingState extends State<TitoDelayedLoading> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _visible ? widget.child : widget.placeholder;
}
