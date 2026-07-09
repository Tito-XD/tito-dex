import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tito_colors.dart';

/// Shared route transition timing for TitoDex.
abstract final class TitoMotion {
  static const routeDuration = Duration(milliseconds: 280);
  static const tabFadeDuration = Duration(milliseconds: 220);
  static const curve = Curves.easeOutCubic;
  static const reverseCurve = Curves.easeInCubic;
}

/// Home hub — no route animation (stable dashboard).
Page<T> titoHomePage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return NoTransitionPage<T>(
    key: key,
    child: child,
  );
}

/// Shared slide builder for [titoSlidePage] and [ThemeData.pageTransitionsTheme].
Widget titoSlideTransitionBuilder(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: TitoMotion.curve,
    reverseCurve: TitoMotion.reverseCurve,
  );
  final offset = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  ).animate(curved);

  return ClipRect(
    child: SlideTransition(
      position: offset,
      child: child,
    ),
  );
}

/// Secondary routes — horizontal slide with symmetric reverse.
Page<T> titoSlidePage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: TitoMotion.routeDuration,
    reverseTransitionDuration: TitoMotion.routeDuration,
    transitionsBuilder: titoSlideTransitionBuilder,
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
