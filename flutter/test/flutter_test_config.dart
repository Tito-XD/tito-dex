import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/l10n/app_locale.dart';

/// Widget tests keep Simplified Chinese so existing copy assertions hold.
/// The running app still follows the OS / Android per-app language.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppLocale.instance.debugOverride(AppUiLanguage.zh);
  await testMain();
}
