import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'features/app_shortcuts/app_shortcuts.dart';
import 'l10n/app_locale.dart';
import 'licenses/third_party_licenses.dart';
import 'theme/tito_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppLocale.instance.attach();
  AppLocale.instance.addListener(appShortcutPreferences.resyncPlatform);
  GoogleFonts.config.allowRuntimeFetching = false;
  registerThirdPartyLicenses();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      // iOS reads statusBarBrightness (background brightness), not icon
      // brightness: dark background → white status bar text.
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: TitoColors.deepBlue,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const TitoDexApp());
}
