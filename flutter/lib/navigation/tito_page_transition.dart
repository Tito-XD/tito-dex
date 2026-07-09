import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tito_colors.dart';

/// TitoDex Motion Guide v0.1 — shared timing tokens.
abstract final class TitoMotion {
  /// M1 route forward (Home → secondary).
  static const routeForwardDuration = Duration(milliseconds: 220);

  /// M2 route back (secondary → Home).
  static const routeBackDuration = Duration(milliseconds: 200);

  /// M3 detail tab cross-fade.
  static const tabFadeDuration = Duration(milliseconds: 180);

  /// M4 skeleton appear delay / minimum visible time.
  static const skeletonDelay = Duration(milliseconds: 120);
  static const skeletonMinVisible = Duration(milliseconds: 200);

  /// M5 companion fade when leaving Home.
  static const companionDuration = Duration(milliseconds: 150);
  static const companionCurve = Curves.easeOut;

  /// cubic-bezier(0.2, 0, 0, 1)
  static const standardCurve = Cubic(0.2, 0, 0, 1);

  /// Home underlay parallax while a secondary route covers it.
  static const homeParallaxOffset = 0.06;
}

/// Home hub — parallax underlay (M1/M2) when covered by secondary routes.
Page<T> titoHomePage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: TitoMotion.routeForwardDuration,
    reverseTransitionDuration: TitoMotion.routeBackDuration,
    transitionsBuilder: titoHomeTransitionBuilder,
  );
}

/// M1/M2: secondary route slide; M2 uses shorter reverse duration via page.
Page<T> titoSlidePage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: TitoMotion.routeForwardDuration,
    reverseTransitionDuration: TitoMotion.routeBackDuration,
    transitionsBuilder: titoSlideTransitionBuilder,
  );
}

/// Home emerges from / shifts to the left when covered (M1/M2 underlay).
Widget titoHomeTransitionBuilder(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: TitoMotion.standardCurve,
    reverseCurve: TitoMotion.standardCurve,
  );
  final offset = Tween<Offset>(
    begin: const Offset(-TitoMotion.homeParallaxOffset, 0),
    end: Offset.zero,
  ).animate(curved);

  return ClipRect(
    child: SlideTransition(position: offset, child: child),
  );
}

/// M1 forward: slide in from right. M2 back: slide out to the right.
Widget titoSlideTransitionBuilder(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: TitoMotion.standardCurve,
    reverseCurve: TitoMotion.standardCurve,
  );
  final offset = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  ).animate(curved);

  return ClipRect(
    child: SlideTransition(position: offset, child: child),
  );
}

/// Bottom sheets — opaque card surface with ink barrier.
Future<T?> showTitoModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: isScrollControlled,
    backgroundColor: TitoColors.card,
    barrierColor: TitoColors.ink.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(TitoRadii.lg)),
      side: BorderSide(color: TitoColors.ink, width: 2),
    ),
    builder: builder,
  );
}
