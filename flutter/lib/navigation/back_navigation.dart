import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Shared back handling for Android system back, gesture back, and RG B button.
abstract final class TitoBackNavigation {
  static bool isHome(String path) => path == '/';

  static bool isDexDetail(String path) => RegExp(r'^/dex/\d+$').hasMatch(path);

  /// Whether the platform back gesture/button may pop without custom handling.
  static bool canPopRoute(BuildContext context, String path) {
    if (isHome(path)) {
      return false;
    }
    return GoRouter.of(context).canPop();
  }

  static void navigateBack(BuildContext context, String path) {
    final router = GoRouter.of(context);

    if (isHome(path)) {
      return;
    }

    if (router.canPop()) {
      router.pop();
      return;
    }

    if (isDexDetail(path)) {
      context.go('/dex');
      return;
    }

    context.go('/');
  }
}
