import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/l10n/app_locale.dart';
import 'package:titodex/l10n/app_zh.dart';

void main() {
  tearDown(() {
    AppLocale.instance.debugOverride(AppUiLanguage.zh);
  });

  test('resolve prefers the first supported language in the OS list', () {
    expect(
      AppLocale.resolve(const [Locale('fr'), Locale('en'), Locale('zh')]),
      AppUiLanguage.en,
    );
    expect(
      AppLocale.resolve(const [Locale('zh', 'CN'), Locale('en')]),
      AppUiLanguage.zh,
    );
    expect(
      AppLocale.resolve(const [Locale('de'), Locale('ja')]),
      AppUiLanguage.zh,
    );
  });

  test('AppZh switches copy when the resolved UI language is English', () {
    expect(AppZh.navDex, '图鉴');
    AppLocale.instance.debugOverride(AppUiLanguage.en);
    expect(AppZh.navDex, 'Dex');
    expect(AppZh.quizScore(3, 10), 'Score 3 / 10');
  });
}
