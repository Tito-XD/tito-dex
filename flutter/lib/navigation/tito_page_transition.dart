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
/// its matching first-level page. The Hero animates a lightweight page surface,
/// rather than moving the destination page itself into the Hero overlay. This
/// keeps stateful Team and Search content mounted while the card expands and
/// contracts during Android Back.
Page<T> titoMaterialPage<T>({
  required LocalKey key,
  required Widget child,
  String? heroTag,
}) {
  return MaterialPage<T>(
    key: key,
    child: heroTag == null
        ? child
        : Stack(
            fit: StackFit.expand,
            children: [
              child,
              Positioned.fill(
                child: IgnorePointer(
                  child: Hero(
                    tag: heroTag,
                    flightShuttleBuilder: _homeActionFlightShuttle,
                    // The destination anchor is transparent at rest. Its
                    // visual surface exists only while Hero owns the flight.
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ],
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
  return const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [TitoColors.skyBlue, TitoColors.slateBlue],
      ),
    ),
    child: SizedBox.expand(),
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
