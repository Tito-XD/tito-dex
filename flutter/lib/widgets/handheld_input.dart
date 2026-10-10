import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../navigation/back_navigation.dart';
import '../theme/app_visual_style.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_motion.dart';
import 'handheld_focus_geometry.dart';
import 'handheld_focus_traversal.dart';

/// D-pad / gamepad focus traversal and A·B actions for RG handhelds.
class HandheldInputShell extends StatefulWidget {
  const HandheldInputShell({
    super.key,
    required this.child,
    this.location = '/',
    this.onBack,
  });
  final Widget child;
  final String location;
  final VoidCallback? onBack;
  @override
  State<HandheldInputShell> createState() => _HandheldInputShellState();
}

class _HandheldActivateIntent extends Intent {
  const _HandheldActivateIntent();
}

class _HandheldDirectionIntent extends Intent {
  const _HandheldDirectionIntent(this.direction);
  final TraversalDirection direction;
}

class _HandheldInputShellState extends State<HandheldInputShell>
    with SingleTickerProviderStateMixin {
  final _policy = HandheldFocusTraversalPolicy();
  final _surfaceKey = GlobalKey();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  FocusNode? _tracked;
  HandheldFocusGeometry? _geometry;
  bool _probePending = false;

  static const _shortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowUp): _HandheldDirectionIntent(
      TraversalDirection.up,
    ),
    SingleActivator(LogicalKeyboardKey.arrowDown): _HandheldDirectionIntent(
      TraversalDirection.down,
    ),
    SingleActivator(LogicalKeyboardKey.arrowLeft): _HandheldDirectionIntent(
      TraversalDirection.left,
    ),
    SingleActivator(LogicalKeyboardKey.arrowRight): _HandheldDirectionIntent(
      TraversalDirection.right,
    ),
    SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false):
        _HandheldActivateIntent(),
    SingleActivator(LogicalKeyboardKey.select, includeRepeats: false):
        _HandheldActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space, includeRepeats: false):
        _HandheldActivateIntent(),
    SingleActivator(LogicalKeyboardKey.gameButtonA, includeRepeats: false):
        _HandheldActivateIntent(),
    SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false):
        _HandheldBackIntent(),
    SingleActivator(LogicalKeyboardKey.goBack, includeRepeats: false):
        _HandheldBackIntent(),
    SingleActivator(LogicalKeyboardKey.gameButtonB, includeRepeats: false):
        _HandheldBackIntent(),
  };

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_scheduleProbe);
    FocusManager.instance.addHighlightModeListener(_highlightChanged);
    _scheduleProbe();
  }

  void _highlightChanged(FocusHighlightMode _) => _scheduleProbe();

  void _scheduleProbe() {
    if (!mounted) return;
    WidgetsBinding.instance.ensureVisualUpdate();
    if (_probePending) return;
    _probePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _probe());
  }

  void _probe() {
    _probePending = false;
    if (!mounted) return;
    final node = FocusManager.instance.primaryFocus;
    final next =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional &&
            node != null
        ? HandheldFocusGeometry.of(node)
        : null;
    final visible = next != null && next.isVisible ? next : null;
    if (node != _tracked ||
        visible?.bounds != _geometry?.bounds ||
        visible?.visible != _geometry?.visible ||
        visible?.radius != _geometry?.radius) {
      final changedTarget =
          node != _tracked || (_geometry == null && visible != null);
      setState(() {
        _tracked = node;
        _geometry = visible;
      });
      if (visible != null) {
        _policy.remember(node!, visible.bounds);
        if (changedTarget && !TitoMotion.disabled(context)) {
          _pulse.forward(from: 0);
        }
      }
    }
    // Observe frames produced by scrolling, responsive layout and route/press
    // motion. Do not schedule idle frames just to track an unchanged focus.
    if (node != null && next != null) {
      _probePending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _probe());
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_scheduleProbe);
    FocusManager.instance.removeHighlightModeListener(_highlightChanged);
    _pulse.dispose();
    super.dispose();
  }

  void _back() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null && ModalRoute.of(focusContext) is PopupRoute) {
      Navigator.of(focusContext).pop();
    } else if (widget.onBack != null) {
      widget.onBack!();
    } else {
      TitoBackNavigation.navigateBack(focusContext ?? context, widget.location);
    }
  }

  void _activateVisibleControl() {
    final node = FocusManager.instance.primaryFocus;
    final geometry = node == null ? null : HandheldFocusGeometry.of(node);
    final focusContext = node?.context;
    if (node?.canRequestFocus != true ||
        geometry?.isVisible != true ||
        focusContext == null) {
      return;
    }
    Actions.maybeInvoke(focusContext, const ActivateIntent());
  }

  KeyEventResult _ignoreHeldActivation(FocusNode node, KeyEvent event) {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext?.findAncestorStateOfType<EditableTextState>() != null) {
      return KeyEventResult.ignored;
    }
    if (event is KeyRepeatEvent &&
        const [
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.select,
          LogicalKeyboardKey.space,
          LogicalKeyboardKey.gameButtonA,
          LogicalKeyboardKey.escape,
          LogicalKeyboardKey.goBack,
          LogicalKeyboardKey.gameButtonB,
        ].contains(event.logicalKey)) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final color = appVisualStyle.usesFlatUi
        ? Theme.of(context).colorScheme.primary
        : TitoColors.softYellow;
    final disabled = TitoMotion.disabled(context);
    if (disabled && _pulse.isAnimating) _pulse.stop();
    return _HandheldCueHost(
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: _ignoreHeldActivation,
        child: Shortcuts(
          shortcuts: _shortcuts,
          child: Actions(
            actions: {
              _HandheldDirectionIntent:
                  CallbackAction<_HandheldDirectionIntent>(
                    onInvoke: (intent) {
                      _policy.inDirection(
                        FocusManager.instance.primaryFocus ??
                            FocusManager.instance.rootScope,
                        intent.direction,
                      );
                      _scheduleProbe();
                      return null;
                    },
                  ),
              _HandheldActivateIntent: CallbackAction<_HandheldActivateIntent>(
                onInvoke: (_) {
                  _activateVisibleControl();
                  return null;
                },
              ),
              _HandheldBackIntent: CallbackAction<_HandheldBackIntent>(
                onInvoke: (_) {
                  _back();
                  return null;
                },
              ),
            },
            child: FocusTraversalGroup(
              policy: _policy,
              child: Stack(
                key: _surfaceKey,
                fit: StackFit.passthrough,
                children: [
                  widget.child,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) {
                          final surface = _surfaceKey.currentContext
                              ?.findRenderObject();
                          final origin = surface is RenderBox && surface.hasSize
                              ? surface.localToGlobal(Offset.zero)
                              : Offset.zero;
                          return CustomPaint(
                            key: const ValueKey('handheld-focus-cue'),
                            painter: HandheldFocusCuePainter(
                              bounds: _geometry?.bounds.shift(-origin),
                              clip: _geometry?.visible.shift(-origin),
                              radius:
                                  _geometry?.radius ?? BorderRadius.circular(8),
                              color: color,
                              pulse: disabled ? 1 : _pulse.value,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HandheldCueHost extends InheritedWidget {
  const _HandheldCueHost({required super.child});
  @override
  bool updateShouldNotify(_HandheldCueHost oldWidget) => false;
}

/// A persistent outline plus one short arrival pulse, painted above opaque
/// card surfaces without changing layout or moving between controls.
class HandheldFocusCuePainter extends CustomPainter {
  const HandheldFocusCuePainter({
    required this.bounds,
    required this.clip,
    required this.radius,
    required this.color,
    required this.pulse,
  });
  final Rect? bounds;
  final Rect? clip;
  final BorderRadius radius;
  final Color color;
  final double pulse;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = bounds;
    if (rect == null || clip == null) return;
    canvas.save();
    canvas.clipRect(clip!.inflate(3).intersect(Offset.zero & size));
    final shape = radius.toRRect(rect).inflate(1);
    final arrival = 1 - pulse;
    if (arrival > 0) {
      canvas.drawRRect(
        radius.toRRect(rect),
        Paint()..color = color.withValues(alpha: 0.10 * arrival),
      );
      canvas.drawRRect(
        shape,
        Paint()
          ..color = color.withValues(alpha: 0.25 + 0.35 * arrival)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + 3 * arrival),
      );
    }
    canvas.drawRRect(
      shape,
      Paint()
        ..color = TitoColors.ink.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 + 1.5 * arrival,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(HandheldFocusCuePainter oldDelegate) =>
      bounds != oldDelegate.bounds ||
      clip != oldDelegate.clip ||
      radius != oldDelegate.radius ||
      color != oldDelegate.color ||
      pulse != oldDelegate.pulse;
}

class _HandheldBackIntent extends Intent {
  const _HandheldBackIntent();
}

/// Exposes "the activate key (A / Enter / Space / Select) is currently held"
/// to descendants — [StickerPressable] reads this to keep a sticker sunk
/// for as long as a gamepad button is held, matching touch press physics.
class HandheldPressed extends InheritedWidget {
  const HandheldPressed({
    super.key,
    required this.pressed,
    required super.child,
  });

  final bool pressed;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<HandheldPressed>()
            ?.pressed ??
        false;
  }

  @override
  bool updateShouldNotify(HandheldPressed oldWidget) =>
      pressed != oldWidget.pressed;
}

/// Visible focus ring for D-pad navigation on cream tiles.
class HandheldFocusDecorator extends StatefulWidget {
  const HandheldFocusDecorator({
    super.key,
    required this.child,
    required this.onActivate,
    this.borderRadius = const BorderRadius.all(Radius.circular(TitoRadii.sm)),
  });

  final Widget child;
  final VoidCallback? onActivate;
  final BorderRadius borderRadius;

  @override
  State<HandheldFocusDecorator> createState() => _HandheldFocusDecoratorState();
}

class _HandheldFocusDecoratorState extends State<HandheldFocusDecorator> {
  static final _activateKeys = {
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.gameButtonA,
  };

  bool _focused = false;
  bool _keyHeld = false;

  KeyEventResult _trackActivateKey(FocusNode node, KeyEvent event) {
    if (_activateKeys.contains(event.logicalKey)) {
      final held = event is! KeyUpEvent;
      if (held != _keyHeld) {
        setState(() => _keyHeld = held);
      }
    }
    // Never consume — ActivateIntent and traversal still need the key.
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // Trainer's Journal and Solid Plastic share the soft-yellow ring; Flat UI
    // uses the scheme primary so the ring matches Material focus colour.
    final ringColor = appVisualStyle.usesFlatUi
        ? Theme.of(context).colorScheme.primary
        : TitoColors.softYellow;
    return Focus(
      onKeyEvent: _trackActivateKey,
      // Skip in traversal (this is a passive listener, not a target) or it
      // steals the D-pad hop from the real focusable child.
      canRequestFocus: false,
      child: HandheldFocusTarget(
        radius: widget.borderRadius,
        child: FocusableActionDetector(
          enabled: widget.onActivate != null,
          onFocusChange: (focused) {
            if (!focused && _keyHeld && mounted) {
              setState(() => _keyHeld = false);
            }
          },
          descendantsAreTraversable: false,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onActivate?.call();
                return null;
              },
            ),
          },
          child: HandheldPressed(
            pressed: _keyHeld,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                border:
                    _focused &&
                        context
                                .dependOnInheritedWidgetOfExactType<
                                  _HandheldCueHost
                                >() ==
                            null
                    ? Border.all(color: ringColor, width: TitoBorders.card)
                    : null,
                boxShadow:
                    _focused &&
                        context
                                .dependOnInheritedWidgetOfExactType<
                                  _HandheldCueHost
                                >() ==
                            null
                    ? [
                        BoxShadow(
                          color: ringColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
