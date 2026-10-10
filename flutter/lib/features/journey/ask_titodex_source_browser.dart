import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as browser;
import 'package:url_launcher/url_launcher.dart';

/// Only public HTTPS citations can enter the source browser.
Uri? askTitoDexSourceUri(String raw) {
  if (raw.length > 2048) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.port != 443) {
    return null;
  }
  final host = uri.host.toLowerCase();
  final labels = host.split('.');
  final label = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
  if (host.length > 253 ||
      labels.length < 2 ||
      labels.any((part) => !label.hasMatch(part)) ||
      RegExp(r'^\d+$').hasMatch(labels.last) ||
      const {
        'localhost',
        'local',
        'internal',
        'intranet',
        'localdomain',
        'lan',
        'home',
        'test',
        'invalid',
        'onion',
      }.contains(labels.last)) {
    return null;
  }
  return uri;
}

/// Browser-owned page rendering with TitoDex colours and a return control.
Future<bool> openAskTitoDexSource(Uri uri, {required ThemeData theme}) async {
  if (askTitoDexSourceUri(uri.toString()) == null) return false;
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await browser.launchUrl(
        uri,
        customTabsOptions: browser.CustomTabsOptions(
          colorSchemes: browser.CustomTabsColorSchemes.defaults(
            colorScheme: theme.brightness == Brightness.dark
                ? browser.CustomTabsColorScheme.dark
                : browser.CustomTabsColorScheme.light,
            toolbarColor: theme.colorScheme.surface,
            navigationBarColor: theme.colorScheme.surface,
          ),
          showTitle: true,
          urlBarHidingEnabled: false,
          shareState: browser.CustomTabsShareState.on,
          closeButton: browser.CustomTabsCloseButton(
            icon: browser.CustomTabsCloseButtonIcons.back,
          ),
          browser: const browser.CustomTabsBrowserConfiguration(
            prefersDefaultBrowser: true,
          ),
        ),
        safariVCOptions: browser.SafariViewControllerOptions(
          preferredBarTintColor: theme.colorScheme.surface,
          preferredControlTintColor: theme.colorScheme.onSurface,
          barCollapsingEnabled: false,
          dismissButtonStyle:
              browser.SafariViewControllerDismissButtonStyle.close,
        ),
      );
      return true;
    } on Object {
      // A device without a compatible in-app browser can still open the source.
    }
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}
