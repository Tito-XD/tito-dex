import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_surface_tokens.dart';

/// One vertical scroll surface. The small overlay never changes input geometry.
/// Its result boundary is measured, so long teams and scaled text work alike.
class BattleResultScroll extends StatefulWidget {
  const BattleResultScroll({
    super.key,
    required this.result,
    required this.summary,
    required this.children,
    required this.storageId,
    this.leading,
  });
  final Widget result;
  final Widget summary;
  final Widget? leading;
  final List<Widget> children;
  final String storageId;

  @override
  State<BattleResultScroll> createState() => _BattleResultScrollState();
}

class _BattleResultScrollState extends State<BattleResultScroll>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  final _viewportKey = GlobalKey();
  final _resultKey = GlobalKey();
  final _summaryKey = GlobalKey();
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final _curve = CurvedAnimation(
    parent: _animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  bool _visible = false;
  bool _queued = false;
  bool _returning = false;
  double? _resultEnd;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_scheduleMeasure);
  }

  @override
  void didUpdateWidget(covariant BattleResultScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted || !_scroll.hasClients) return;
      final result = _resultKey.currentContext?.findRenderObject();
      final viewport = _viewportKey.currentContext?.findRenderObject();
      if (result is RenderBox &&
          viewport is RenderBox &&
          result.hasSize &&
          viewport.hasSize) {
        _resultEnd =
            _scroll.offset +
            result
                .localToGlobal(
                  Offset(0, result.size.height),
                  ancestor: viewport,
                )
                .dy;
      }
      final end = _resultEnd;
      if (end == null || _returning) return;
      // Hysteresis avoids a flicker at the boundary during slow touch scrolling.
      _setVisible(_scroll.offset >= end - (_visible ? 48 : 0));
    });
  }

  void _setVisible(bool value) {
    if (_visible == value) return;
    setState(() => _visible = value);
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = value ? 1 : 0;
    } else if (value) {
      _animation.forward();
    } else {
      _animation.reverse();
    }
  }

  Future<void> _expand() async {
    if (!_scroll.hasClients || _returning) return;
    _returning = true;
    FocusScope.of(context).unfocus();
    _setVisible(false);
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(0);
    } else {
      await _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    }
    if (!mounted) return;
    _returning = false;
    _scheduleMeasure();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _curve.dispose();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    final padding = DeviceLayout.pagePadding(context);
    final surface = TitoSurfaceTokens.of(context).surface(TitoSurfaceRole.card);
    return SizedBox.expand(
      key: _viewportKey,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _curve,
            builder: (context, child) => ClipRect(
              clipper: _SummaryClearance(_curve.value, _summaryKey),
              child: child,
            ),
            child: NotificationListener<SizeChangedLayoutNotification>(
              onNotification: (_) {
                _scheduleMeasure();
                return false;
              },
              child: ListView(
                key: PageStorageKey('battle-inputs-${widget.storageId}'),
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  padding.left,
                  8,
                  padding.right,
                  96,
                ),
                children: [
                  if (widget.leading != null) ...[
                    widget.leading!,
                    const SizedBox(height: 10),
                  ],
                  SizeChangedLayoutNotifier(
                    child: Padding(
                      key: _resultKey,
                      padding: const EdgeInsets.only(bottom: 12),
                      child: KeyedSubtree(
                        key: const ValueKey('battle-result'),
                        child: widget.result,
                      ),
                    ),
                  ),
                  ...widget.children,
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: padding.left,
            right: padding.right,
            child: IgnorePointer(
              ignoring: !_visible,
              child: ExcludeSemantics(
                excluding: !_visible,
                child: SizeTransition(
                  sizeFactor: _curve,
                  alignment: Alignment.topCenter,
                  child: FadeTransition(
                    opacity: _curve,
                    child: Padding(
                      key: _summaryKey,
                      padding: const EdgeInsets.only(top: 4, bottom: 6),
                      child: Material(
                        color: surface.fill,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(TitoRadii.lg),
                          side: surface.outline,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: const ValueKey('battle-result-summary'),
                          onTap: _expand,
                          child: Semantics(
                            button: true,
                            label: AppZh.battleExpandResult,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: AnimatedBuilder(
                                        animation: _animation,
                                        builder: (context, _) =>
                                            _animation.isDismissed
                                            ? const SizedBox.shrink()
                                            : DefaultTextStyle(
                                                style: SecondaryTypography
                                                    .onCard
                                                    .small12
                                                    .copyWith(
                                                      color: surface.foreground,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                child: widget.summary,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.expand_more_rounded,
                                      color: surface.foreground,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Clip the moving list behind the header instead of shifting its layout.
/// This also excludes the covered controls from hit testing.
class _SummaryClearance extends CustomClipper<Rect> {
  const _SummaryClearance(this.progress, this.summaryKey);
  final double progress;
  final GlobalKey summaryKey;

  @override
  Rect getClip(Size size) {
    final box = summaryKey.currentContext?.findRenderObject();
    final height = box is RenderBox && box.hasSize ? box.size.height : 54.0;
    final top = (height * progress).clamp(0.0, size.height);
    return Rect.fromLTWH(0, top, size.width, size.height - top);
  }

  @override
  bool shouldReclip(_SummaryClearance oldClipper) =>
      progress != oldClipper.progress || summaryKey != oldClipper.summaryKey;
}
