import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PredictiveBackEvent, SwipeEdge;

import '../theme/tito_colors.dart';

/// Tag for the single home action that expands into its first-level page.
abstract final class TitoHomeActionHero {
  static const dex = 'home-action-dex';

  static String? forRoute(String route, Object? extra) {
    return route == '/dex' && extra == dex ? dex : null;
  }
}

enum TitoSideSlideDirection { fromLeft, fromRight }

/// Android's current forward transition is 450 ms. Dex keeps its slightly
/// slower card expansion, while its actual contents reveal afterwards.
const titoDexTransitionDuration = Duration(milliseconds: 600);
const titoSideSlideTransitionDuration = Duration(milliseconds: 450);
const titoSideSlideReverseTransitionDuration = Duration(milliseconds: 350);

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

/// Dex expands the home card into its page shell. [content] is an independent
/// layer which fades in only after that shell is almost fully expanded.
Page<T> titoDexPage<T>({
  required LocalKey key,
  required Widget child,
  String? heroTag,
  Widget? content,
}) {
  final page = content == null
      ? child
      : Stack(fit: StackFit.expand, children: [child, content]);
  if (heroTag == null) {
    return titoMaterialPage<T>(key: key, child: page);
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
    overlay: content,
  );
}

/// Team and Search deliberately use simple full-screen slides. Their pages do
/// not enter the Hero overlay, so stateful content is never laid out at card
/// size. Taps retain the designed slide curve; Android predictive back uses a
/// linear, edge-aware slide which follows the user's finger exactly.
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
    this.overlay,
    super.key,
  });

  final _TitoMaterialPageKind kind;
  final Widget child;
  final Widget? overlay;

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
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final transitioned = super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    );
    if (_page.kind != _TitoMaterialPageKind.dex || _page.overlay == null) {
      return transitioned;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        transitioned,
        FadeTransition(
          key: const ValueKey<String>('tito-dex-content-reveal'),
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0.7, 1, curve: Curves.easeOutCubic),
            reverseCurve: const Interval(0.7, 1, curve: Curves.easeInCubic),
          ),
          child: _page.overlay!,
        ),
      ],
    );
  }

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

  final ValueNotifier<SwipeEdge?> _predictiveBackEdge = ValueNotifier(null);

  void beginPredictiveBack(SwipeEdge edge) {
    _predictiveBackEdge.value = edge;
  }

  void clearPredictiveBackWhenSettled() {
    final routeAnimation = animation;
    if (routeAnimation == null) {
      _predictiveBackEdge.value = null;
      return;
    }
    if (routeAnimation.isCompleted || routeAnimation.isDismissed) {
      _predictiveBackEdge.value = null;
      return;
    }

    late final AnimationStatusListener listener;
    listener = (status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _predictiveBackEdge.value = null;
        routeAnimation.removeStatusListener(listener);
      }
    };
    routeAnimation.addStatusListener(listener);
  }

  @override
  void dispose() {
    _predictiveBackEdge.dispose();
    super.dispose();
  }

  @override
  Duration get transitionDuration => titoSideSlideTransitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      titoSideSlideReverseTransitionDuration;

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
    return _TitoPredictiveBackController(
      route: this,
      child: ValueListenableBuilder<SwipeEdge?>(
        valueListenable: _predictiveBackEdge,
        child: child,
        builder: (context, edge, page) {
          final position = edge == null
              ? _buttonSlidePosition(animation, begin)
              : _predictiveBackSlidePosition(animation, edge);
          return SlideTransition(
            key: const ValueKey<String>('tito-side-slide-transition'),
            position: position,
            child: page,
          );
        },
      ),
    );
  }

  Animation<Offset> _buttonSlidePosition(
    Animation<double> animation,
    Offset begin,
  ) {
    final curve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubicEmphasized,
      reverseCurve: Curves.easeInCubic,
    );
    return Tween<Offset>(begin: begin, end: Offset.zero).animate(curve);
  }

  Animation<Offset> _predictiveBackSlidePosition(
    Animation<double> animation,
    SwipeEdge edge,
  ) {
    final exitOffset = edge == SwipeEdge.left
        ? const Offset(1, 0)
        : const Offset(-1, 0);
    return Tween<Offset>(
      begin: exitOffset,
      end: Offset.zero,
    ).animate(animation);
  }
}

class _TitoPredictiveBackController extends StatefulWidget {
  const _TitoPredictiveBackController({
    required this.route,
    required this.child,
  });

  final _TitoSideSlidePageRoute<dynamic> route;
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
    widget.route.beginPredictiveBack(backEvent.swipeEdge);
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
    widget.route.clearPredictiveBackWhenSettled();
  }

  @override
  void handleCommitBackGesture() {
    widget.route.handleCommitBackGesture();
    widget.route.clearPredictiveBackWhenSettled();
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
    // Swap to the already-empty destination shell in the first moments of
    // the flight. The home card therefore never paints across a full screen.
    cardOpacity = animation.drive(
      TweenSequence<double>([
        TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 1),
        TweenSequenceItem(tween: ConstantTween<double>(0), weight: 11),
      ]),
    );
    pageOpacity = animation.drive(
      TweenSequence<double>([
        TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1), weight: 1),
        TweenSequenceItem(tween: ConstantTween<double>(1), weight: 11),
      ]),
    );
  } else {
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
        // Both Hero children paint their own backgrounds. A transparent
        // flight Material prevents a fallback white or blue compositing frame.
        color: Colors.transparent,
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
