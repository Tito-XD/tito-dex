import 'dart:math' as math;

import 'package:flutter/material.dart';

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

enum _TitoMaterialPageKind { home, dex, plain }

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
  Duration get transitionDuration => _page.kind == _TitoMaterialPageKind.dex
      ? titoDexTransitionDuration
      : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      _page.kind == _TitoMaterialPageKind.dex
      ? titoDexReverseTransitionDuration
      : super.reverseTransitionDuration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_page.kind != _TitoMaterialPageKind.dex || _page.overlay == null) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    // The Hero owns the page shell and is the only large moving surface. The
    // list follows on the same route progress with a short rise, rather than
    // receiving Android's second zoom/fade transition on top of the flight.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Animation<double> contentReveal = reduceMotion
        ? CurvedAnimation(
            parent: animation,
            curve: titoDexForwardCurve,
            reverseCurve: Curves.easeInExpo,
          )
        : CurvedAnimation(
            parent: animation,
            curve: const Interval(0.46, 0.86, curve: Curves.easeOutCubic),
            reverseCurve: const Interval(0.55, 1, curve: Curves.easeInCubic),
          );
    final Animation<Offset> contentPosition = reduceMotion
        ? const AlwaysStoppedAnimation<Offset>(Offset.zero)
        : Tween<Offset>(
            begin: const Offset(0, 0.012),
            end: Offset.zero,
          ).animate(contentReveal);
    final pageWithOverlay = Stack(
      fit: StackFit.expand,
      children: [
        child,
        SlideTransition(
          key: const ValueKey<String>('tito-dex-content-slide'),
          position: contentPosition,
          child: FadeTransition(
            key: const ValueKey<String>('tito-dex-content-reveal'),
            opacity: contentReveal,
            child: _page.overlay!,
          ),
        ),
      ],
    );
    if (!_page.usesContainerTransform) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        pageWithOverlay,
      );
    }
    return PredictiveBackPageTransitionsBuilder(
      fallbackColor: Theme.of(context).scaffoldBackgroundColor,
    ).buildTransitions(
      this,
      context,
      animation,
      secondaryAnimation,
      pageWithOverlay,
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
    // The dex list stays static while its detail (a plain controlled page)
    // covers it. Without this the covered list ran the default secondary
    // zoom-out; popping the detail reversed it over the already-settled reveal,
    // which read as a one-frame twitch of the grid. Mirrors the home opt-out.
    if (_page.kind == _TitoMaterialPageKind.dex &&
        nextRoute is _TitoControlledMaterialPageRoute &&
        nextRoute._page.kind == _TitoMaterialPageKind.plain) {
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
    return SlideTransition(
      key: const ValueKey<String>('tito-side-slide-transition'),
      position: _buttonSlidePosition(animation, begin),
      child: child,
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
