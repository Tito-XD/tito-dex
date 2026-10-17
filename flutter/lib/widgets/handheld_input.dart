import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../navigation/back_navigation.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_skin.dart';

/// D-pad / gamepad focus traversal and A·B actions for RG handhelds.
class HandheldInputShell extends StatelessWidget {
  const HandheldInputShell({
    super.key,
    required this.child,
    this.location = '/',
  });

  final Widget child;
  final String location;

  static const _directionalShortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
      TraversalDirection.up,
    ),
    SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
      TraversalDirection.down,
    ),
    SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(
      TraversalDirection.left,
    ),
    SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(
      TraversalDirection.right,
    ),
  };

  static const _activateShortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
  };

  static const _backShortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.escape): _HandheldBackIntent(),
    SingleActivator(LogicalKeyboardKey.goBack): _HandheldBackIntent(),
    SingleActivator(LogicalKeyboardKey.gameButtonB): _HandheldBackIntent(),
  };

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        ..._directionalShortcuts,
        ..._activateShortcuts,
        ..._backShortcuts,
      },
      child: Actions(
        actions: {
          _HandheldBackIntent: CallbackAction<_HandheldBackIntent>(
            onInvoke: (_) {
              _handleBack(context);
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: child,
        ),
      ),
    );
  }

  void _handleBack(BuildContext context) {
    TitoBackNavigation.navigateBack(context, location);
  }
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

/// Theme-aware D-pad focus ring (see [TitoSkin.focusRing]). Use it directly
/// for custom focus visuals that cannot be wrapped by
/// [HandheldFocusDecorator].
class TitoFocusRing extends StatelessWidget {
  const TitoFocusRing({
    super.key,
    required this.child,
    required this.focused,
    this.borderRadius = const BorderRadius.all(Radius.circular(TitoRadii.md)),
  });

  final Widget child;
  final bool focused;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => _HandheldFocusRing(
    focused: focused,
    borderRadius: borderRadius,
    child: child,
  );
}

/// Keeps one stable widget tree whether or not focus is shown, so toggling
/// the ring never remounts (and resets) the focused child.
class _HandheldFocusRing extends StatelessWidget {
  const _HandheldFocusRing({
    required this.focused,
    required this.borderRadius,
    required this.child,
  });

  final bool focused;
  final BorderRadius borderRadius;
  final Widget child;

  static const _none = BoxDecoration();

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    final wash = focused ? skin.focusWash : null;
    return DecoratedBox(
      decoration: focused ? skin.focusRing(borderRadius) : _none,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: wash == null
            ? _none
            : BoxDecoration(color: wash, borderRadius: borderRadius),
        child: child,
      ),
    );
  }
}

/// Visible focus ring for D-pad navigation on cream tiles.
class HandheldFocusDecorator extends StatefulWidget {
  const HandheldFocusDecorator({
    super.key,
    required this.child,
    required this.onActivate,
    this.borderRadius = const BorderRadius.all(Radius.circular(TitoRadii.md)),
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
    return Focus(
      onKeyEvent: _trackActivateKey,
      // Skip in traversal (this is a passive listener, not a target) or it
      // steals the D-pad hop from the real focusable child.
      canRequestFocus: false,
      child: FocusableActionDetector(
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
          child: _HandheldFocusRing(
            focused: _focused,
            borderRadius: widget.borderRadius,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
