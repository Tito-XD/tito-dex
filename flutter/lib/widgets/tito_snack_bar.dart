import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_motion.dart';

/// Shows a short transient message at the bottom of the app.
///
/// Every in-app toast goes through here so they share one look: theme
/// colours from `snackBarTheme`, a close button, an optional action, a
/// slide-up entrance and fade-down exit (instant under reduced motion), and
/// swipe-down to dismiss. A newer message replaces the visible one.
///
/// Falls back to a stock [SnackBar] when no [TitoSnackHost] is above
/// [context] (isolated widget tests).
void showTitoSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final host = context.findAncestorStateOfType<TitoSnackHostState>();
  if (host != null) {
    host.show(
      TitoSnackMessage(
        message,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
    return;
  }
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      showCloseIcon: true,
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ),
  );
}

@immutable
class TitoSnackMessage {
  const TitoSnackMessage(
    this.message, {
    this.duration = const Duration(seconds: 4),
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// Hosts [showTitoSnackBar] messages above [child]. Mount once around the
/// router content (see `app.dart`).
class TitoSnackHost extends StatefulWidget {
  const TitoSnackHost({super.key, required this.child});

  final Widget child;

  @override
  State<TitoSnackHost> createState() => TitoSnackHostState();
}

class TitoSnackHostState extends State<TitoSnackHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  TitoSnackMessage? _current;
  TitoSnackMessage? _pending;
  Timer? _timer;
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  /// The message on screen, for tests and diagnostics.
  TitoSnackMessage? get current => _current;

  void show(TitoSnackMessage message) {
    if (_current == null) {
      _present(message);
    } else {
      _pending = message;
      unawaited(dismiss());
    }
  }

  void _present(TitoSnackMessage message) {
    _timer?.cancel();
    setState(() {
      _current = message;
      _serial++;
    });
    _controller.duration = TitoMotion.duration(context, TitoMotion.emphasized);
    _controller.forward(from: 0);
    // Screen-reader users get unlimited time when there is an action.
    final holdForReader =
        message.actionLabel != null &&
        MediaQuery.accessibleNavigationOf(context);
    if (!holdForReader) {
      _timer = Timer(message.duration, () => unawaited(dismiss()));
    }
  }

  /// Plays the exit and shows a queued replacement, if any.
  Future<void> dismiss({bool animate = true}) async {
    _timer?.cancel();
    if (_current == null) return;
    final serial = _serial;
    if (animate) {
      _controller.reverseDuration = TitoMotion.duration(
        context,
        TitoMotion.standard,
      );
      await _controller.reverse().orCancel.catchError((_) {});
    }
    if (!mounted || serial != _serial) return;
    final next = _pending;
    _pending = null;
    setState(() => _current = null);
    if (next != null) _present(next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _current;
    final media = MediaQuery.of(context);
    final bottom =
        12 +
        (media.viewInsets.bottom > media.viewPadding.bottom
            ? media.viewInsets.bottom
            : media.viewPadding.bottom);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (message != null)
          Positioned(
            left: 12 + media.viewPadding.left,
            right: 12 + media.viewPadding.right,
            bottom: bottom,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _TitoSnackMotion(
                  animation: _controller,
                  child: Dismissible(
                    key: ValueKey(_serial),
                    direction: DismissDirection.down,
                    onDismissed: (_) => unawaited(dismiss(animate: false)),
                    child: _TitoSnackCard(
                      message: message,
                      onClose: () => unawaited(dismiss()),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Rises from below with a slight scale while fading in; reverses on exit.
class _TitoSnackMotion extends StatelessWidget {
  const _TitoSnackMotion({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.6),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

class _TitoSnackCard extends StatelessWidget {
  const _TitoSnackCard({required this.message, required this.onClose});

  final TitoSnackMessage message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snack = theme.snackBarTheme;
    final fill = snack.backgroundColor ?? theme.colorScheme.inverseSurface;
    final textStyle =
        snack.contentTextStyle ??
        SecondaryTypography.onCard.body14.copyWith(
          color: theme.colorScheme.onInverseSurface,
        );
    final ink = textStyle.color ?? theme.colorScheme.onInverseSurface;
    final actionColor = snack.actionTextColor ?? TitoColors.softYellow;
    final action = message.actionLabel;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: fill,
        elevation: 6,
        shape:
            snack.shape ??
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(message.message, style: textStyle),
                ),
              ),
              if (action != null)
                TextButton(
                  onPressed: () {
                    onClose();
                    message.onAction?.call();
                  },
                  style: TextButton.styleFrom(foregroundColor: actionColor),
                  child: Text(action),
                ),
              IconButton(
                key: const ValueKey('tito-snack-close'),
                onPressed: onClose,
                color: ink,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                // No tooltip: the host sits above the navigator's Overlay.
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  semanticLabel: AppZh.close,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
