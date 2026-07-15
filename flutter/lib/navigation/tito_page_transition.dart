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
/// its matching first-level page. The destination page then expands from that
/// card; nested routes and all other navigation remain platform-standard.
Page<T> titoMaterialPage<T>({
  required LocalKey key,
  required Widget child,
  String? heroTag,
}) {
  return MaterialPage<T>(
    key: key,
    child: heroTag == null ? child : Hero(tag: heroTag, child: child),
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
