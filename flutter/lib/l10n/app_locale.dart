import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// UI language resolved from the OS / Android per-app language list.
///
/// There is no in-app language switch. The first supported language in
/// [PlatformDispatcher.locales] wins; unknown languages fall back to
/// Simplified Chinese (the shipping UI).
class AppLocale extends ChangeNotifier with WidgetsBindingObserver {
  AppLocale._();

  static final AppLocale instance = AppLocale._();

  static const supported = <Locale>[Locale('zh', 'CN'), Locale('en')];

  AppUiLanguage _language = AppUiLanguage.zh;
  bool _observing = false;

  AppUiLanguage get language => _language;

  bool get isEnglish => _language == AppUiLanguage.en;

  bool get isChinese => _language == AppUiLanguage.zh;

  /// Locale handed to [MaterialApp] so widgets and plugins follow the same
  /// choice as [AppZh].
  Locale get materialLocale => isEnglish
      ? const Locale('en')
      : const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');

  /// Locale tag sent to the Journey Assistant Worker.
  String get workerLocale => isEnglish ? 'en' : 'zh-Hans';

  /// Call once from [main] so Android per-app language changes rebuild UI.
  void attach() {
    if (_observing) {
      return;
    }
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
    _syncFromPlatform();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    _syncFromPlatform();
  }

  void _syncFromPlatform() {
    final next = resolve(PlatformDispatcher.instance.locales);
    if (next == _language) {
      return;
    }
    _language = next;
    notifyListeners();
  }

  /// Tests pin Simplified Chinese so existing copy assertions stay stable.
  @visibleForTesting
  void debugOverride(AppUiLanguage language) {
    if (_language == language) {
      return;
    }
    _language = language;
    notifyListeners();
  }

  static AppUiLanguage resolve(List<Locale> locales) {
    for (final locale in locales) {
      final code = locale.languageCode.toLowerCase();
      if (code == 'zh') {
        return AppUiLanguage.zh;
      }
      if (code == 'en') {
        return AppUiLanguage.en;
      }
    }
    return AppUiLanguage.zh;
  }

  static String pick({required String zh, required String en}) =>
      instance.isEnglish ? en : zh;
}

enum AppUiLanguage { zh, en }
