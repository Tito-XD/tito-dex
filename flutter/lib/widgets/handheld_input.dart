import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../navigation/back_navigation.dart';
import '../theme/tito_colors.dart';

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
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onActivate?.call();
            return null;
          },
        ),
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          border: _focused
              ? Border.all(color: TitoColors.softYellow, width: 3)
              : null,
          boxShadow: _focused
              ? const [
                  BoxShadow(
                    color: Color(0x66FFE08A),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
