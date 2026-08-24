import 'dart:async';

import 'package:flutter/material.dart';

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
