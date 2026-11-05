import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/motion_preferences.dart';

/// A decorative ribbon that scrolls [children] sideways in an endless loop,
/// such as the data-source strip in Settings → About. Never put actions or
/// the only copy of information in it.
///
/// When everything already fits, or motion is reduced, the items sit still
/// in a wrapping row so nothing is hidden. Screen readers get one copy.
class TitoMarquee extends StatefulWidget {
  const TitoMarquee({
    super.key,
    required this.children,
    this.gap = 8,
    this.pixelsPerSecond = 26,
    this.semanticsLabel,
  });

  final List<Widget> children;
  final double gap;
  final double pixelsPerSecond;
  final String? semanticsLabel;

  @override
  State<TitoMarquee> createState() => _TitoMarqueeState();
}

class _TitoMarqueeState extends State<TitoMarquee>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  double _offset = 0;
  double? _measuredFor;
  bool _fits = false;

  bool get _canAnimate =>
      !MediaQuery.disableAnimationsOf(context) &&
      motionPreferences.listAnimationsEnabled;

  @override
  void initState() {
    super.initState();
    motionPreferences.addListener(_motionChanged);
  }

  void _motionChanged() {
    if (!mounted) return;
    // Re-measure on the next build so the ticker follows the new setting.
    setState(() => _measuredFor = null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measuredFor = null;
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    // Content is two identical copies separated by one gap.
    final copy =
        (position.maxScrollExtent + position.viewportDimension + widget.gap) /
        2;
    if (copy <= 0) return;
    _offset = (_offset + widget.pixelsPerSecond * dt) % copy;
    _scroll.jumpTo(_offset.clamp(0.0, position.maxScrollExtent));
  }

  void _measure(double width) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      final copy =
          (position.maxScrollExtent + position.viewportDimension - widget.gap) /
          2;
      final fits = copy <= position.viewportDimension;
      if (fits != _fits) setState(() => _fits = fits);
      _syncTicker();
    });
  }

  void _syncTicker() {
    final run = _canAnimate && !_fits;
    if (run && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    motionPreferences.removeListener(_motionChanged);
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Widget _row() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < widget.children.length; i++) ...[
        if (i > 0) SizedBox(width: widget.gap),
        widget.children[i],
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final label = widget.semanticsLabel;
    Widget content;
    if (!_canAnimate) {
      if (_ticker.isActive) _ticker.stop();
      content = Wrap(
        spacing: widget.gap,
        runSpacing: widget.gap,
        children: widget.children,
      );
    } else {
      content = LayoutBuilder(
        builder: (context, constraints) {
          if (_measuredFor != constraints.maxWidth) {
            _measuredFor = constraints.maxWidth;
            _fits = false;
            _measure(constraints.maxWidth);
          }
          if (_fits) {
            return Wrap(
              spacing: widget.gap,
              runSpacing: widget.gap,
              children: widget.children,
            );
          }
          return ShaderMask(
            // Soft edges so items slide in and out rather than being cut.
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0, 0.06, 0.94, 1],
            ).createShader(bounds),
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _row(),
                  SizedBox(width: widget.gap),
                  ExcludeSemantics(child: _row()),
                ],
              ),
            ),
          );
        },
      );
    }
    return label == null
        ? content
        : Semantics(container: true, label: label, child: content);
  }
}
