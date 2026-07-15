import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Shared back handling for Android system back, gesture back, and RG B button.
abstract final class TitoBackNavigation {
  static bool isHome(String path) => path == '/';

  static bool isDexDetail(String path) => RegExp(r'^/dex/\d+$').hasMatch(path);

  static String parentPath(String path) {
    if (isDexDetail(path) || path == '/dex/moves' || path == '/dex/abilities') {
      return '/dex';
    }
    if (path.startsWith('/search/companion/') ||
        path == '/search/reference/json') {
      return '/search';
    }
    if (path == '/team' ||
        path == '/journey' ||
        path == '/dex' ||
        path == '/search' ||
        path == '/settings') {
      return '/';
    }
    return '/';
  }

  /// Whether the platform back gesture/button may pop without custom handling.
  static bool canPopRoute(BuildContext context, String path) {
    if (isHome(path)) {
      // Do not consume Android's root back event: it exits the activity and
      // enables the system back-to-home predictive animation.
      return true;
    }
    return GoRouter.of(context).canPop();
  }

  static void navigateBack(BuildContext context, String path) {
    final router = GoRouter.of(context);

    if (router.canPop()) {
      router.pop();
      return;
    }

    final parent = parentPath(path);
    if (!isHome(path)) {
      context.go(parent);
    }
  }
}
