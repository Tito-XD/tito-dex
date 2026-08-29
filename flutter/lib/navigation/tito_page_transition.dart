import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_visual_style.dart';
import '../theme/tito_colors.dart';

/// Tag for the single home action that expands into its first-level page.
abstract final class TitoHomeActionHero {
  static const dex = 'home-action-dex';

  static String? forRoute(String route, Object? extra) {
    return route == '/dex' && extra == dex ? dex : null;
  }
}

enum TitoSideSlideDirection { fromLeft, fromRight }

/// Dex uses one compact container-transform timeline. Geometry, clipping,
/// surface and content reveal all derive from the route progress instead of
/// stacking a full Material page transition on top of the Hero flight.
const titoDexTransitionDuration = Duration(milliseconds: 340);
const titoDexReverseTransitionDuration = Duration(milliseconds: 300);
const titoDexDetailTransitionDuration = Duration(milliseconds: 360);
const titoDexDetailReverseTransitionDuration = Duration(milliseconds: 300);
const titoSideSlideTransitionDuration = Duration(milliseconds: 450);
const titoSideSlideReverseTransitionDuration = Duration(milliseconds: 350);

/// Controller value the Dex commit rewinds to before playing the collapse
/// (hand-tuned: starting from 85% skips the first, barely-visible stretch
/// of the collapse and reads smoother on release). The predictive-back
/// gesture test asserts against this constant, so tuning it here keeps the
/// test in sync automatically.
const titoDexCollapseRewindFrom = 0.85;

const Curve titoDexForwardCurve = Curves.easeOutQuint;
const Curve titoDexReverseCurve = Curves.easeInQuint;

/// A direct bounds interpolation keeps the home tile attached to the page it
/// becomes. The Hero curve supplies the easing; the rect itself never arcs
/// sideways on wide handheld layouts.
Tween<Rect?> titoDexRectTween(Rect? begin, Rect? end) =>
    RectTween(begin: begin, end: end);

/// A Material page lets Android provide the standard route transition. It
/// still goes through the controlled route so every page shares the same
/// predictive-back fixes (commit-runway clamp, static underlying pages).
Page<T> titoMaterialPage<T>({required LocalKey key, required Widget child}) {
  return _TitoControlledMaterialPage<T>(
    key: key,
    kind: _TitoMaterialPageKind.plain,
    child: child,
  );
}

/// Dex card -> detail may still fly a matching Pokémon sprite independently,
/// but the route surface uses the platform Material transition for its entire
/// lifetime. Predictive back therefore behaves exactly like the rest of the
/// app instead of competing with a second, Dex-only gesture controller.
Page<T> titoDexDetailPage<T>({required LocalKey key, required Widget child}) {
  return _TitoControlledMaterialPage<T>(
    key: key,
    kind: _TitoMaterialPageKind.dexDetail,
    child: child,
  );
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
  // The content layer is not inside [TitoPageContainer], so it needs its own
  // SafeArea now that the shell is edge-to-edge.
  final safeContent = content == null ? null : SafeArea(child: content);

  return _TitoControlledMaterialPage<T>(
    key: key,
    kind: _TitoMaterialPageKind.dex,
    usesContainerTransform: heroTag != null,
    // Keep Dex content in [overlay] for the route's entire lifetime. Nested
    // pushes do not retain the home-card `extra`, so moving content into the
    // normal child when [heroTag] becomes null would reparent and recreate the
    // live list during the detail transition — visibly snapping it to top.
    child: heroTag == null
        ? child
        : Hero(
            tag: heroTag,
            // The shell must not join interactive back-gesture flights.
            // The predictive-back commit rewinds the route controller to
            // 1.0 (see the commit override below), and a flight is a pure
            // function of that controller - an in-flight container
            // transform would snap back to the full-page rect and replay
            // the whole collapse after the finger releases. The drag shows
            // the standard Material preview instead; the commit starts a
            // fresh non-gesture flight that plays the collapse once.
            transitionOnUserGestures: false,
            createRectTween: titoDexRectTween,
            curve: titoDexForwardCurve,
            reverseCurve: titoDexReverseCurve,
            flightShuttleBuilder: _homeActionFlightShuttle,
            child: child,
          ),
    overlay: safeContent,
  );
}

/// Team and Search deliberately use simple full-screen slides. Their pages do
/// not enter the Hero overlay, so stateful content is never laid out at card
/// size. Both routes take part in Android predictive back: the slide itself
/// follows the gesture (Team continues to the left, Search to the right), but
/// clamped to the first 20% of the exit animation - the page keeps at least
/// 80% of itself on screen while dragging, and releasing plays the remaining
/// slide from the release point instead of restarting it.
Page<T> titoSideSlidePage<T>({
  required LocalKey key,
  required Widget child,
  required TitoSideSlideDirection direction,
}) {
  return _TitoSideSlidePage<T>(key: key, direction: direction, child: child);
}

enum _TitoMaterialPageKind { home, dex, dexDetail, plain }

class _TitoControlledMaterialPage<T> extends Page<T> {
  const _TitoControlledMaterialPage({
    required this.kind,
    required this.child,
    this.overlay,
    this.usesContainerTransform = false,
    super.key,
  });

  final _TitoMaterialPageKind kind;
  final Widget child;
  final Widget? overlay;
  final bool usesContainerTransform;

  @override
  Route<T> createRoute(BuildContext context) {
    return _TitoControlledMaterialPageRoute<T>(page: this);
  }
}

/// Dex list content layer with its reveal. It lives inside the page content
/// (see [_TitoControlledMaterialPageRoute.buildContent]) so the grid's Hero
/// widgets stay under [ModalRoute.subtreeContext] and keep working.
///
/// While an interactive back gesture is scrubbing or canceling, the reveal
/// holds fully visible: the standard Material predictive-back preview keeps
/// the page content on screen, and any mid-drag fade would have to snap back
/// when the commit rewinds the controller to 1.0. The reveal fades only while
/// the controller is genuinely reversing - a programmatic pop or the
/// post-commit container collapse - and rises on the forward interval as
/// before.
class _TitoDexContentReveal extends StatefulWidget {
  const _TitoDexContentReveal({required this.child});

  final Widget child;

  @override
  State<_TitoDexContentReveal> createState() => _TitoDexContentRevealState();
}

class _TitoDexContentRevealState extends State<_TitoDexContentReveal> {
  static const Curve _forwardInterval = Interval(
    0.46,
    0.86,
    curve: Curves.easeOutCubic,
  );
  static const Curve _reverseInterval = Interval(
    0.55,
    1,
    curve: Curves.easeInCubic,
  );

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final routeAnimation = route?.animation;
    if (route == null || routeAnimation == null) {
      return widget.child;
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        routeAnimation,
        route.navigator?.userGestureInProgressNotifier,
      ]),
      builder: (context, child) {
        final double reveal;
        if (route.popGestureInProgress &&
            routeAnimation.status != AnimationStatus.reverse) {
          // Gesture scrub or cancel-spring: hold the list fully visible.
          reveal = 1.0;
        } else if (routeAnimation.status == AnimationStatus.reverse) {
          reveal = reduceMotion
              ? Curves.easeInExpo.transform(routeAnimation.value)
              : _reverseInterval.transform(routeAnimation.value);
        } else {
          reveal = reduceMotion
              ? titoDexForwardCurve.transform(routeAnimation.value)
              : _forwardInterval.transform(routeAnimation.value);
        }
        final Offset position = reduceMotion
            ? Offset.zero
            : Offset(0, 0.012 * (1 - reveal));
        return SlideTransition(
          key: const ValueKey<String>('tito-dex-content-slide'),
          position: AlwaysStoppedAnimation<Offset>(position),
          child: FadeTransition(
            key: const ValueKey<String>('tito-dex-content-reveal'),
            opacity: AlwaysStoppedAnimation<double>(reveal),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
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
  Widget buildContent(BuildContext context) {
    final overlay = _page.overlay;
    if (_page.kind != _TitoMaterialPageKind.dex || overlay == null) {
      return _page.child;
    }
    // The overlay (the live Dex list) must be composed INSIDE the page
    // content: HeroController only discovers Heroes under
    // ModalRoute.subtreeContext, which is exactly the buildContent subtree —
    // layers added in buildTransitions sit above it and are invisible to
    // shared-element flights. Keeping the grid in buildTransitions made
    // every dex card -> detail flight silently abort on device (the v0.9.x
    // "canvas expand never flies" bug).
    return Stack(
      fit: StackFit.expand,
      children: [
        _page.child,
        _TitoDexContentReveal(child: overlay),
      ],
    );
  }

  @override
  bool get maintainState => true;

  @override
  bool get fullscreenDialog => false;

  /// Minimum controller value while a predictive-back drag is in progress.
  ///
  /// The framework drives the controller to exactly 0.0 when the finger
  /// reaches the far edge. On commit, [TransitionRoute.didPop] then runs
  /// `reverse()` over zero distance and the "restart from 1.0" commit
  /// animation is skipped - the page vanishes with no fade at all. Clamping
  /// a tiny runway keeps the commit fade (and its full-length restart)
  /// guaranteed to play, with no visible difference during the drag. For the
  /// container-transform Dex route this also keeps `didPop`'s reverse()
  /// animating at a full-edge commit so the commit override below rewinds
  /// to 1.0 and the Hero collapse flies instead of the page vanishing.
  static const double _kBackGestureRunway = 0.02;

  @override
  void handleUpdateBackGestureProgress({required double progress}) {
    super.handleUpdateBackGestureProgress(
      progress: math.max(_kBackGestureRunway, progress),
    );
  }

  /// The container-transform Dex commit ends the gesture before popping so
  /// the home-card collapse flies exactly like a button back.
  ///
  /// [HeroController] only starts pop flights from
  /// [NavigatorObserver.didChangeTop] while no user gesture is in progress,
  /// and the framework's default commit keeps the gesture alive through the
  /// pop - so with the default commit the container transform never flies,
  /// and the controller rewind to 1.0 replays the raw controller-driven
  /// visuals instead (the v0.9.5 "return animation replays after release"
  /// bug). Stopping the gesture first makes this pop indistinguishable from
  /// the back button: `didChangeTop` starts the Hero flight, and rewinding
  /// to 1.0 plays the complete collapse as the post-release animation. The
  /// drag itself showed only the standard Material preview (the page Hero
  /// opts out of interactive flights), so nothing replays mid-gesture.
  @override
  void handleCommitBackGesture() {
    if (_page.kind == _TitoMaterialPageKind.dex &&
        _page.usesContainerTransform &&
        isCurrent) {
      navigator?.didStopUserGesture();
      navigator?.pop();
      if (controller?.isAnimating ?? false) {
        controller!.reverse(from: titoDexCollapseRewindFrom);
      }
      return;
    }
    super.handleCommitBackGesture();
  }

  @override
  Duration get transitionDuration => switch (_page.kind) {
    _TitoMaterialPageKind.dex => titoDexTransitionDuration,
    _TitoMaterialPageKind.dexDetail => titoDexDetailTransitionDuration,
    _ => super.transitionDuration,
  };

  @override
  Duration get reverseTransitionDuration => switch (_page.kind) {
    _TitoMaterialPageKind.dex => titoDexReverseTransitionDuration,
    _TitoMaterialPageKind.dexDetail => titoDexDetailReverseTransitionDuration,
    _ => super.reverseTransitionDuration,
  };

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_page.kind == _TitoMaterialPageKind.dexDetail) {
      // Use the platform Material transition for the entire route lifetime.
      // PredictiveBackPageTransitionsBuilder installs its gesture observer
      // while idle, before Android sends the first edge event. A forward-only
      // custom wrapper cannot safely swap that observer in after pop starts.
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    if (_page.kind == _TitoMaterialPageKind.plain) {
      // Ordinary pages must retain the platform Material transition. Opaque
      // Scaffolds prevent loading-state ghosting; replacing this with a tiny
      // custom scale also replaced Android predictive back and was the v0.9.3
      // regression where forward/back movement was barely perceptible.
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    if (_page.kind != _TitoMaterialPageKind.dex || _page.overlay == null) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    // The list layer and its reveal are composed in buildContent (see the
    // note there) so the grid Heroes stay discoverable; only the page-level
    // container transform remains here.
    if (!_page.usesContainerTransform) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return PredictiveBackPageTransitionsBuilder(
      fallbackColor: Theme.of(context).scaffoldBackgroundColor,
    ).buildTransitions(this, context, animation, secondaryAnimation, child);
  }

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    if (_page.kind == _TitoMaterialPageKind.home &&
        (nextRoute is _TitoSideSlidePageRoute ||
            nextRoute is _TitoControlledMaterialPageRoute &&
                nextRoute._page.kind == _TitoMaterialPageKind.dex)) {
      return false;
    }
    // The dex list stays static while its detail (a plain controlled page)
    // covers it. Without this the covered list ran the default secondary
    // zoom-out; popping the detail reversed it over the already-settled reveal,
    // which read as a one-frame twitch of the grid. Mirrors the home opt-out.
    if (_page.kind == _TitoMaterialPageKind.dex &&
        nextRoute is _TitoControlledMaterialPageRoute &&
        (nextRoute._page.kind == _TitoMaterialPageKind.plain ||
            nextRoute._page.kind == _TitoMaterialPageKind.dexDetail)) {
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

  /// Largest fraction of the exit slide an interactive back drag may play.
  ///
  /// During a predictive-back drag the directed slide follows the finger,
  /// but clamped: even a full-edge swipe only plays the first 20% of the
  /// exit animation (the page keeps at least 80% of itself on screen).
  /// Releasing then plays the remaining slide from the release point.
  static const double _kBackGestureVisualCap = 0.20;

  @override
  void handleStartBackGesture({double progress = 0.0}) {
    super.handleStartBackGesture(progress: _cappedProgress(progress));
  }

  @override
  void handleUpdateBackGestureProgress({required double progress}) {
    super.handleUpdateBackGestureProgress(progress: _cappedProgress(progress));
  }

  /// Maps a raw gesture-driven controller value (1.0 entered -> 0.0 fully
  /// out) to the value that keeps the slide within [_kBackGestureVisualCap].
  ///
  /// The slide visual is `1 - easeInOutCubicEmphasized(controller)`, and
  /// that curve is nearly flat near 1.0 - clamping the *controller* at 0.8
  /// would cap the visible slide at only a few percent, not 20%. The cap
  /// therefore has to be applied in visual space: bisect for the controller
  /// value whose eased output is `1 - 0.20 * gesture` (the curve is
  /// monotonically increasing, so the solution is unique). The mapping is
  /// exact, so the commit hands off seamlessly - `didPop` reverses from the
  /// mapped value and the same curve plays the remaining 80% of the slide
  /// with no jump.
  double _cappedProgress(double progress) {
    final double gesture = (1.0 - progress).clamp(0.0, 1.0);
    final double target = 1.0 - _kBackGestureVisualCap * gesture;
    const Curve curve = Curves.easeInOutCubicEmphasized;
    double lo = 0.0;
    double hi = 1.0;
    for (var i = 0; i < 24; i++) {
      final double mid = (lo + hi) / 2;
      if (curve.transform(mid) < target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  /// A side-slide commit continues the slide from wherever the finger
  /// released instead of restarting it.
  ///
  /// The framework default ([TransitionRoute.handleCommitBackGesture]) pops
  /// and then rewinds the controller to 1.0 so the standard Material
  /// predictive-back settle can play over the full transition. That rewind is
  /// correct for the standard scale-and-fade visual, whose commit tweens
  /// remember the release state, but the side slide is a plain function of
  /// the controller: rewinding would snap the page back to fully entered and
  /// replay the entire slide-out. [TransitionRoute.didPop] already starts
  /// `reverse()` from the gesture-driven value, so popping alone hands off
  /// smoothly; only the user-gesture bookkeeping needs reproducing.
  @override
  void handleCommitBackGesture() {
    if (isCurrent) {
      navigator?.pop();
    }
    if (controller?.isAnimating ?? false) {
      late final AnimationStatusListener stopGestureWhenSettled;
      stopGestureWhenSettled = (AnimationStatus status) {
        if (status == AnimationStatus.dismissed ||
            status == AnimationStatus.completed) {
          navigator?.didStopUserGesture();
          controller!.removeStatusListener(stopGestureWhenSettled);
        }
      };
      controller!.addStatusListener(stopGestureWhenSettled);
    } else {
      // The pop completed inline (the controller was already dismissed) -
      // finish the gesture immediately.
      navigator?.didStopUserGesture();
    }
  }

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
    // The page carries its own opaque surface. A full-screen ColoredBox *behind*
    // the SlideTransition (the v0.9.2 layout) flashed the scaffold background
    // over Home the instant the route was inserted, before any slide was
    // visible - read as a white-screen-then-animation. Sizing the backdrop to
    // the moving page makes the slide carry the surface instead.
    return _SideSlideBackGestureDetector(
      route: this,
      child: ClipRect(
        child: SlideTransition(
          key: const ValueKey<String>('tito-side-slide-transition'),
          position: _buttonSlidePosition(animation, begin),
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: child,
          ),
        ),
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
      reverseCurve: Curves.easeInOutCubicEmphasized,
    );
    return Tween<Offset>(begin: begin, end: Offset.zero).animate(curve);
  }
}

/// Forwards Android predictive-back gesture events to a side-slide route.
///
/// The framework's equivalent (`_PredictiveBackGestureDetector` inside
/// [PredictiveBackPageTransitionsBuilder]) is the only public installer of
/// that plumbing, but it draws the standard scale/shift preview and the
/// FadeForwards fallback itself; a route that wants its own transition to
/// follow the gesture has to install its own observer. Mirrors the
/// framework's gating: only the current route whose [ModalRoute
/// .popGestureEnabled] is true accepts a touch (not button) gesture, and
/// progress is inverted because the controller runs 1.0 -> 0.0 while the
/// gesture runs 0.0 -> 1.0.
class _SideSlideBackGestureDetector extends StatefulWidget {
  const _SideSlideBackGestureDetector({
    required this.route,
    required this.child,
  });

  final PageRoute<dynamic> route;
  final Widget child;

  @override
  State<_SideSlideBackGestureDetector> createState() =>
      _SideSlideBackGestureDetectorState();
}

class _SideSlideBackGestureDetectorState
    extends State<_SideSlideBackGestureDetector>
    with WidgetsBindingObserver {
  bool get _isEnabled =>
      widget.route.isCurrent && widget.route.popGestureEnabled;

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    final bool gestureInProgress = !backEvent.isButtonEvent && _isEnabled;
    if (!gestureInProgress) {
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
  final flightVisual = _DexFlightVisual.resolve(flightContext);
  final timelineAnimation = animation is CurvedAnimation
      ? animation.parent
      : animation;

  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final progress = animation.value.clamp(0.0, 1.0);
      final timelineProgress = timelineAnimation.value.clamp(0.0, 1.0);
      final radius = flightVisual.startRadius * (1 - progress);
      final borderWidth = flightVisual.borderWidth * (1 - progress);
      final shadowProgress = 1 - Curves.easeOutCubic.transform(progress);
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      final cardOpacity = reduceMotion
          ? (timelineProgress < 0.5 ? 1.0 : 0.0)
          : 1 -
                const Interval(
                  0,
                  0.42,
                  curve: Curves.easeOutCubic,
                ).transform(timelineProgress);
      final pageOpacity = reduceMotion
          ? (timelineProgress < 0.5 ? 0.0 : 1.0)
          : const Interval(
              0.24,
              0.82,
              curve: Curves.easeOutCubic,
            ).transform(timelineProgress);
      final borderRadius = BorderRadius.circular(radius);

      return DecoratedBox(
        key: const ValueKey<String>('tito-dex-flight-surface'),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: flightVisual.shadowColor.withValues(
                alpha: flightVisual.shadowOpacity * shadowProgress,
              ),
              blurRadius: flightVisual.shadowBlur * shadowProgress,
              spreadRadius: flightVisual.shadowSpread * shadowProgress,
              offset: flightVisual.shadowOffset * shadowProgress,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: flightVisual.surfaceGradient,
              border: Border.all(
                color: flightVisual.outlineColor.withValues(
                  alpha: flightVisual.outlineColor.a * (1 - progress),
                ),
                width: borderWidth,
              ),
            ),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: FittedBox(
                    key: const ValueKey('tito-dex-flight-source-fit'),
                    // The quick-action artwork is intentionally pixel-like.
                    // Keep it at its natural size while the surrounding
                    // surface expands instead of stretching the icon to the
                    // full-screen destination bounds.
                    fit: BoxFit.scaleDown,
                    child: SizedBox.fromSize(
                      size: cardSize,
                      child: Opacity(
                        key: const ValueKey('tito-dex-flight-source'),
                        opacity: cardOpacity,
                        child: cardHero.child,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox.fromSize(
                      size: pageSize,
                      child: Opacity(
                        key: const ValueKey('tito-dex-flight-target'),
                        opacity: pageOpacity,
                        child: pageHero.child,
                      ),
                    ),
                  ),
                ),
                if (flightVisual.specularColor != null)
                  Positioned(
                    top: 1,
                    left: 12,
                    right: 12,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: (1 - progress) * 0.92,
                        child: Container(
                          height: 1.4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                flightVisual.specularColor!,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _DexFlightVisual {
  const _DexFlightVisual({
    required this.surfaceGradient,
    required this.outlineColor,
    required this.borderWidth,
    required this.startRadius,
    required this.shadowColor,
    required this.shadowOpacity,
    required this.shadowBlur,
    required this.shadowSpread,
    required this.shadowOffset,
    this.specularColor,
  });

  final Gradient surfaceGradient;
  final Color outlineColor;
  final double borderWidth;
  final double startRadius;
  final Color shadowColor;
  final double shadowOpacity;
  final double shadowBlur;
  final double shadowSpread;
  final Offset shadowOffset;
  final Color? specularColor;

  static _DexFlightVisual resolve(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (appVisualStyle.style) {
      AppVisualStyle.classic => const _DexFlightVisual(
        surfaceGradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5D728A), TitoColors.slateBlue],
        ),
        outlineColor: TitoColors.ink,
        borderWidth: TitoBorders.card,
        startRadius: TitoRadii.md,
        shadowColor: TitoColors.deepBlue,
        shadowOpacity: 0.24,
        shadowBlur: 0,
        shadowSpread: 0,
        shadowOffset: Offset(0, 5),
      ),
      AppVisualStyle.solidPlastic => _DexFlightVisual(
        surfaceGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0, 0.52, 1],
          colors: [
            TitoColors.glassBackgroundTop,
            TitoColors.glassBackgroundMid,
            TitoColors.glassBackgroundBottom,
          ],
        ),
        outlineColor: Colors.white.withValues(alpha: 0.72),
        borderWidth: TitoBorders.glass,
        startRadius: TitoRadii.md,
        shadowColor: TitoColors.deepBlue,
        shadowOpacity: 0.22,
        shadowBlur: 18,
        shadowSpread: -4,
        shadowOffset: const Offset(0, 8),
        specularColor: Colors.white.withValues(alpha: 0.82),
      ),
      AppVisualStyle.flatUi => _DexFlightVisual(
        surfaceGradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.surfaceContainerHigh, scheme.surface],
        ),
        outlineColor: scheme.outlineVariant,
        borderWidth: TitoBorders.element,
        startRadius: TitoRadii.md,
        shadowColor: scheme.shadow,
        shadowOpacity: 0.16,
        shadowBlur: 8,
        shadowSpread: -2,
        shadowOffset: const Offset(0, 3),
      ),
    };
  }
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
    // viewInsets keeps content above the system keyboard (iOS/phones — RG
    // handhelds never show one); SafeArea(top: false) clears the iPhone home
    // indicator. Sheets that already wrap themselves in SafeArea are fine:
    // nested SafeAreas consume the padding only once.
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SafeArea(top: false, child: builder(sheetContext)),
    ),
  );
}
