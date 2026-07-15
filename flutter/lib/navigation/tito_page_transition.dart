import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PredictiveBackEvent;

import '../theme/tito_colors.dart';

/// Tag for the one intentional home-to-page shared-element transition.
abstract final class TitoHomeActionHero {
  static const dex = 'home-action-dex';

  static String? forRoute(String route, Object? extra) {
    return route == '/dex' && extra == dex ? dex : null;
  }
}

enum TitoSideSlideDirection { fromLeft, fromRight }

/// Android's current forward transition is 450 ms. The Dex shared-element
/// transition intentionally runs at half speed in both directions.
const titoDexTransitionDuration = Duration(milliseconds: 900);
const titoSideSlideTransitionDuration = Duration(milliseconds: 450);

/// A Material page lets Android provide the standard route transition.
///
Page<T> titoMaterialPage<T>({required LocalKey key, required Widget child}) {
  return MaterialPage<T>(key: key, child: child);
}

/// Home keeps the standard Material route so Android's root predictive-back
/// animation remains available, but it opts out of secondary motion while a
/// Home action is entering or leaving.
Page<T> titoHomePage<T>({required LocalKey key, required Widget child}) {
  return _TitoControlledMaterialPage<T>(
    key: key,
    kind: _TitoMaterialPageKind.home,
    child: child,
  );
}

/// The Dex route retains the existing Hero/container animation and Android's
/// predictive-back integration, with a doubled push and pop duration.
Page<T> titoDexPage<T>({
  required LocalKey key,
  required Widget child,
  String? heroTag,
}) {
  if (heroTag == null) {
    return titoMaterialPage<T>(key: key, child: child);
  }

  return _TitoControlledMaterialPage<T>(
    key: key,
    kind: _TitoMaterialPageKind.dex,
    child: Hero(
      tag: heroTag,
      transitionOnUserGestures: true,
      flightShuttleBuilder: _homeActionFlightShuttle,
      child: child,
    ),
  );
}

/// Team and Search deliberately use simple full-screen slides. Their pages do
/// not enter the Hero overlay, so stateful content is never laid out at card
/// size. The route observer keeps the slide driven by Android predictive-back
/// gesture progress.
Page<T> titoSideSlidePage<T>({
  required LocalKey key,
  required Widget child,
  required TitoSideSlideDirection direction,
}) {
  return _TitoSideSlidePage<T>(key: key, direction: direction, child: child);
}

enum _TitoMaterialPageKind { home, dex }

class _TitoControlledMaterialPage<T> extends Page<T> {
  const _TitoControlledMaterialPage({
    required this.kind,
    required this.child,
    super.key,
  });

  final _TitoMaterialPageKind kind;
  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    return _TitoControlledMaterialPageRoute<T>(page: this);
  }
}

class _TitoControlledMaterialPageRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  _TitoControlledMaterialPageRoute({
    required _TitoControlledMaterialPage<T> page,
  }) : super(settings: page);

  _TitoControlledMaterialPage<T> get _page =>
      settings as _TitoControlledMaterialPage<T>;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  bool get maintainState => true;

  @override
  bool get fullscreenDialog => false;

  @override
  Duration get transitionDuration => _page.kind == _TitoMaterialPageKind.dex
      ? titoDexTransitionDuration
      : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      _page.kind == _TitoMaterialPageKind.dex
      ? titoDexTransitionDuration
      : super.reverseTransitionDuration;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    if (_page.kind == _TitoMaterialPageKind.home &&
        (nextRoute is _TitoSideSlidePageRoute ||
            nextRoute is _TitoControlledMaterialPageRoute &&
                nextRoute._page.kind == _TitoMaterialPageKind.dex)) {
      return false;
    }
    return super.canTransitionTo(nextRoute);
  }
}

class _TitoSideSlidePage<T> extends Page<T> {
  const _TitoSideSlidePage({
    required this.direction,
    required this.child,
    super.key,
  });

  final TitoSideSlideDirection direction;
  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    return _TitoSideSlidePageRoute<T>(page: this);
  }
}

class _TitoSideSlidePageRoute<T> extends PageRoute<T> {
  _TitoSideSlidePageRoute({required _TitoSideSlidePage<T> page})
    : super(settings: page);

  _TitoSideSlidePage<T> get _page => settings as _TitoSideSlidePage<T>;

  @override
  Duration get transitionDuration => titoSideSlideTransitionDuration;

  @override
  Duration get reverseTransitionDuration => titoSideSlideTransitionDuration;

  @override
  bool get maintainState => true;

  @override
  bool get fullscreenDialog => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: _page.child,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final begin = switch (_page.direction) {
      TitoSideSlideDirection.fromLeft => const Offset(-1, 0),
      TitoSideSlideDirection.fromRight => const Offset(1, 0),
    };
    final position = Tween<Offset>(begin: begin, end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeInOutCubicEmphasized))
        .animate(animation);

    return _TitoPredictiveBackController(
      route: this,
      child: SlideTransition(
        key: const ValueKey<String>('tito-side-slide-transition'),
        position: position,
        child: child,
      ),
    );
  }
}

class _TitoPredictiveBackController extends StatefulWidget {
  const _TitoPredictiveBackController({
    required this.route,
    required this.child,
  });

  final PageRoute<dynamic> route;
  final Widget child;

  @override
  State<_TitoPredictiveBackController> createState() =>
      _TitoPredictiveBackControllerState();
}

class _TitoPredictiveBackControllerState
    extends State<_TitoPredictiveBackController>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent ||
        !widget.route.isCurrent ||
        !widget.route.popGestureEnabled) {
      return false;
    }
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    widget.route.handleUpdateBackGestureProgress(
      progress: 1 - backEvent.progress,
    );
  }

  @override
  void handleCancelBackGesture() {
    widget.route.handleCancelBackGesture();
  }

  @override
  void handleCommitBackGesture() {
    widget.route.handleCommitBackGesture();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
