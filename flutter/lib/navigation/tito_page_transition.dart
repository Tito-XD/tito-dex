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

/// Dex card -> detail keeps the list stationary and lets the Pokémon sprite
/// own the spatial movement. The page surface only fades and settles in place,
/// so Android's default full-screen side slide cannot overpower the Hero.
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
            transitionOnUserGestures: true,
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
/// size. These two routes deliberately opt out of predictive-back progress:
/// Team always enters and exits on the left, while Search does so on the right.
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
/// widgets stay under [ModalRoute.subtreeContext] and keep working; the fade
/// and short rise still follow the route animation exactly as before.
class _TitoDexContentReveal extends StatelessWidget {
  const _TitoDexContentReveal({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (routeAnimation == null) {
      return child;
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Animation<double> reveal = reduceMotion
        ? CurvedAnimation(
            parent: routeAnimation,
            curve: titoDexForwardCurve,
            reverseCurve: Curves.easeInExpo,
          )
        : CurvedAnimation(
            parent: routeAnimation,
            curve: const Interval(0.46, 0.86, curve: Curves.easeOutCubic),
            reverseCurve: const Interval(0.55, 1, curve: Curves.easeInCubic),
          );
    final Animation<Offset> position = reduceMotion
        ? const AlwaysStoppedAnimation<Offset>(Offset.zero)
        : Tween<Offset>(
            begin: const Offset(0, 0.012),
            end: Offset.zero,
          ).animate(reveal);
    return SlideTransition(
      key: const ValueKey<String>('tito-dex-content-slide'),
      position: position,
      child: FadeTransition(
        key: const ValueKey<String>('tito-dex-content-reveal'),
        opacity: reveal,
        child: child,
      ),
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
  /// animation is skipped — the page vanishes with no fade at all. Clamping
  /// a tiny runway keeps the commit fade (and its full-length restart)
  /// guaranteed to play, with no visible difference during the drag.
  static const double _kBackGestureRunway = 0.02;

  @override
  void handleUpdateBackGestureProgress({required double progress}) {
    super.handleUpdateBackGestureProgress(
      progress: math.max(_kBackGestureRunway, progress),
    );
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
      // The Pokemon Hero owns the local sprite -> header geometry. The page
      // surface only fades and settles in place: stacking Android's stock
      // FadeForwards slide (what PredictiveBackPageTransitionsBuilder falls
      // back to outside a gesture) on top of the flight double-exposed the
      // incoming page over the stationary grid — the v0.9.3 "canvas expand"
      // regression. Predictive-back input still scrubs the route directly;
      // while a drag is active the surface scales down with rounding corners
      // so the gesture stays visible instead of the old 0.8% settle scale.
      // The fade starts late on purpose: the sprite visibly travels to the
      // header first, then the skeleton page materialises around the flight.
      // On pop the page clears in the first half so the canvas collapse and
      // the creature's ride back into the grid stay readable instead of
      // dissolving into a whole-page crossfade.
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      final surfaceProgress = reduceMotion
          ? const AlwaysStoppedAnimation<double>(1)
          : CurvedAnimation(
              parent: animation,
              curve: const Interval(0.16, 0.78, curve: Curves.easeOutCubic),
              reverseCurve: const Interval(0.5, 1, curve: Curves.easeInCubic),
            );
      final scaleProgress = reduceMotion
          ? const AlwaysStoppedAnimation<double>(1)
          : Tween<double>(begin: 0.992, end: 1).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            );
      return _TitoBackGestureRouteSurface(
        route: this,
        gestureSurfaceBuilder: (context, startBackEvent) =>
            _TitoDexDetailBackSurface(
              animation: animation,
              startBackEvent: startBackEvent,
              child: child,
            ),
        child: KeyedSubtree(
          key: const ValueKey<String>('tito-dex-detail-predictive-surface'),
          child: FadeTransition(
            key: const ValueKey<String>('tito-dex-detail-fade'),
            opacity: surfaceProgress,
            child: ScaleTransition(
              key: const ValueKey<String>('tito-dex-detail-settle'),
              scale: scaleProgress,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        ),
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

/// Forwards Android predictive-back events to a custom route and swaps the
/// route surface while a drag (or its commit/cancel follow-through) is active.
/// Mirrors the framework's private _PredictiveBackGestureDetector so routes
/// with their own forward motion keep system back-gesture input.
class _TitoBackGestureRouteSurface extends StatefulWidget {
  const _TitoBackGestureRouteSurface({
    required this.route,
    required this.gestureSurfaceBuilder,
    required this.child,
  });

  final PageRoute<dynamic> route;
  final Widget Function(BuildContext context, PredictiveBackEvent? startEvent)
  gestureSurfaceBuilder;
  final Widget child;

  @override
  State<_TitoBackGestureRouteSurface> createState() =>
      _TitoBackGestureRouteSurfaceState();
}

class _TitoBackGestureRouteSurfaceState
    extends State<_TitoBackGestureRouteSurface>
    with WidgetsBindingObserver {
  bool _gestureActive = false;
  bool _settlingFromCancel = false;
  PredictiveBackEvent? _startBackEvent;

  bool get _enabled => widget.route.isCurrent && widget.route.popGestureEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.route.animation?.addStatusListener(_handleAnimationStatus);
  }

  @override
  void dispose() {
    widget.route.animation?.removeStatusListener(_handleAnimationStatus);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (_settlingFromCancel && status == AnimationStatus.completed && mounted) {
      setState(() {
        _settlingFromCancel = false;
        _gestureActive = false;
        _startBackEvent = null;
      });
    }
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || !_enabled) {
      return false;
    }
    setState(() {
      _gestureActive = true;
      _startBackEvent = backEvent;
    });
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (!_gestureActive) {
      return;
    }
    widget.route.handleUpdateBackGestureProgress(
      progress: 1 - backEvent.progress,
    );
  }

  @override
  void handleCancelBackGesture() {
    if (!_gestureActive) {
      return;
    }
    widget.route.handleCancelBackGesture();
    // Keep the gesture surface while the route settles back to full, then
    // return to the normal surface from [_handleAnimationStatus].
    _settlingFromCancel = true;
  }

  @override
  void handleCommitBackGesture() {
    if (!_gestureActive) {
      return;
    }
    widget.route.handleCommitBackGesture();
    // Keep the gesture surface: the route pops and disposes this widget.
  }

  @override
  Widget build(BuildContext context) {
    if (_gestureActive) {
      return widget.gestureSurfaceBuilder(context, _startBackEvent);
    }
    return widget.child;
  }
}

/// Predictive-back drag surface for the Dex detail route: the page visibly
/// shrinks with rounding corners and a slight bias toward the swipe edge,
/// scrubbed directly by the gesture-driven route animation. The final fade
/// only kicks in near the end so the drag itself never washes the page out.
class _TitoDexDetailBackSurface extends StatelessWidget {
  const _TitoDexDetailBackSurface({
    required this.animation,
    required this.startBackEvent,
    required this.child,
  });

  final Animation<double> animation;
  final PredictiveBackEvent? startBackEvent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final settle = animation.value.clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(1 - settle);
        final fromRight = startBackEvent?.swipeEdge == SwipeEdge.right;
        final exitFade = settle < 0.35 ? settle / 0.35 : 1.0;
        return Opacity(
          opacity: (1 - 0.18 * eased) * exitFade,
          child: Transform.translate(
            offset: Offset((fromRight ? -1.0 : 1.0) * 28 * eased, 10 * eased),
            child: Transform.scale(
              scale: 1 - 0.12 * eased,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26 * eased),
                child: child,
              ),
            ),
          ),
        );
      },
    );
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
  bool get popGestureEnabled => false;

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
    // The page carries its own opaque surface. A full-screen ColoredBox *behind*
    // the SlideTransition (the v0.9.2 layout) flashed the scaffold background
    // over Home the instant the route was inserted, before any slide was
    // visible — read as a white-screen-then-animation. Sizing the backdrop to
    // the moving page makes the slide carry the surface instead.
    return ClipRect(
      child: SlideTransition(
        key: const ValueKey<String>('tito-side-slide-transition'),
        position: _buttonSlidePosition(animation, begin),
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: child,
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
