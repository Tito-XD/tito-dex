import 'dart:async';

import 'package:flutter/material.dart';

/// Lets an incoming route paint one opaque shell before beginning repository
/// work, without waiting for the full route animation. This keeps input smooth
/// while allowing local bundle reads and decoding to overlap the short settle.
Future<bool> waitForIncomingRoutePainted(BuildContext context) async {
  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) return false;
  // A dependency callback can subscribe during the first build. Waiting for
  // the next frame keeps that already-composited shell observable before the
  // repository Future starts, while still overlapping almost all route motion.
  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) return false;
  final route = ModalRoute.of(context);
  return route == null ||
      (identical(ModalRoute.of(context), route) && route.isCurrent);
}

/// Lets an incoming page paint its lightweight shell before repositories,
/// decoding, sorting, or large list construction begin.
///
/// Telegram Android exposes the same separation through delayed fragment
/// opening/resume hooks. TitoDex keeps the idea local to Flutter: wait for the
/// first frame and the current route's forward transition, then yield one more
/// frame so the settled chrome is visible before starting work.
Future<bool> waitForIncomingRouteSettled(BuildContext context) async {
  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) return false;

  final route = ModalRoute.of(context);
  if (route != null && !route.isCurrent) return false;
  final animation = route?.animation;
  if (animation != null && animation.status != AnimationStatus.completed) {
    if (animation.status == AnimationStatus.dismissed) return false;
    final completer = Completer<bool>();
    late AnimationStatusListener listener;
    listener = (status) {
      if (status == AnimationStatus.completed) {
        animation.removeStatusListener(listener);
        if (!completer.isCompleted) completer.complete(true);
      } else if (status == AnimationStatus.dismissed) {
        animation.removeStatusListener(listener);
        if (!completer.isCompleted) completer.complete(false);
      }
    };
    animation.addStatusListener(listener);
    final completed = await completer.future;
    if (!completed || !context.mounted) return false;
  }

  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) return false;
  if (route == null) return true;
  return identical(ModalRoute.of(context), route) &&
      route.isCurrent &&
      (animation == null || animation.status == AnimationStatus.completed);
}

/// Prevents a covered text field from reclaiming focus when its route becomes
/// visible again.
///
/// Navigator route focus scopes remember their last focused child. Without
/// clearing that history, returning from a detail page can focus the search
/// field again and immediately reopen the software keyboard. Only editable
/// focus is cleared here so handheld/button focus is left to the existing
/// traversal system. Explicit autofocus on a newly pushed editor still runs
/// after the route is built.
class TitoRouteFocusObserver extends NavigatorObserver {
  void _clearTextInputFocus() {
    final focus = FocusManager.instance.primaryFocus;
    final focusContext = focus?.context;
    if (focus == null || focusContext == null) return;

    final editableFocused =
        focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
    if (!editableFocused) return;

    focus.unfocus(disposition: UnfocusDisposition.scope);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _clearTextInputFocus();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _clearTextInputFocus();
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.isCurrent || (previousRoute?.isCurrent ?? false)) {
      _clearTextInputFocus();
    }
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final replacedCurrentRoute =
        newRoute?.isCurrent ?? oldRoute?.isCurrent ?? false;
    if (replacedCurrentRoute) {
      _clearTextInputFocus();
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
