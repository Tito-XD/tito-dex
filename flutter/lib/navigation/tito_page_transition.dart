import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';

/// Tags for the three intentional home-to-page shared-element transitions.
///
/// Every other route uses the platform Material transition without an
/// application-specific animation.
abstract final class TitoHomeActionHero {
  static const team = 'home-action-team';
  static const dex = 'home-action-dex';
  static const search = 'home-action-search';

  static String? forRoute(String route, Object? extra) {
    final expected = switch (route) {
      '/team' => team,
      '/dex' => dex,
      '/search' => search,
      _ => null,
    };
    return extra == expected ? expected : null;
  }
}

/// A Material page lets Android provide the standard route transition.
///
/// [heroTag] is used only when one of the three home quick-action cards opens
/// its matching first-level page. The fixed-size open and closed children use
/// the same fade-through layout strategy as Flutter's official OpenContainer,
/// while the route itself remains owned by GoRouter for deep links and Android
/// predictive back.
Page<T> titoMaterialPage<T>({
  required LocalKey key,
  required Widget child,
  String? heroTag,
}) {
  return MaterialPage<T>(
    key: key,
    child: heroTag == null
        ? child
        : Hero(
            tag: heroTag,
            transitionOnUserGestures: true,
            flightShuttleBuilder: _homeActionFlightShuttle,
            child: child,
          ),
  );
}

Widget _homeActionFlightShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final cardContext = flightDirection == HeroFlightDirection.push
      ? fromHeroContext
      : toHeroContext;
  final pageContext = flightDirection == HeroFlightDirection.push
      ? toHeroContext
      : fromHeroContext;
  final cardHero = cardContext.widget as Hero;
  final pageHero = pageContext.widget as Hero;
  final cardSize = (cardContext.findRenderObject()! as RenderBox).size;
  final pageSize = (pageContext.findRenderObject()! as RenderBox).size;

  final Animation<double> cardOpacity;
  final Animation<double> pageOpacity;
  if (flightDirection == HeroFlightDirection.push) {
    cardOpacity = animation.drive(
      TweenSequence<double>([
        TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 1),
        TweenSequenceItem(tween: ConstantTween<double>(0), weight: 4),
      ]),
    );
    pageOpacity = animation.drive(
      TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween<double>(0), weight: 1),
        TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1), weight: 4),
      ]),
    );
  } else {
    // The route animation runs from 1 to 0 while popping. Fade the page out
    // first, then reveal the card during the remaining contraction.
    cardOpacity = animation.drive(
      TweenSequence<double>([
        TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 4),
        TweenSequenceItem(tween: ConstantTween<double>(0), weight: 1),
      ]),
    );
    pageOpacity = animation.drive(
      TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween<double>(0), weight: 4),
        TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1), weight: 1),
      ]),
    );
  }

  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final progress = animation.value;
      final radius = 14 * (1 - progress);
      final borderWidth = 3 * (1 - progress);

      return Material(
        animationDuration: Duration.zero,
        clipBehavior: Clip.antiAlias,
        color: Color.lerp(TitoColors.card, TitoColors.slateBlue, progress),
        elevation: 2 * (1 - progress),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: TitoColors.ink, width: borderWidth),
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            FittedBox(
              fit: BoxFit.fitWidth,
              alignment: Alignment.topLeft,
              child: SizedBox.fromSize(
                size: cardSize,
                child: FadeTransition(
                  opacity: cardOpacity,
                  child: cardHero.child,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.fitWidth,
              alignment: Alignment.topLeft,
              child: SizedBox.fromSize(
                size: pageSize,
                child: FadeTransition(
                  opacity: pageOpacity,
                  child: pageHero.child,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Bottom sheets retain Flutter Material's standard Android sheet behavior.
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
