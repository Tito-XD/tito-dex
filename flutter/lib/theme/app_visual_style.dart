import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stable naming registry shared by the current app and future localization.
enum TitoThemeFamily { trainerJournal, solidPlastic, flatUi }

extension TitoThemeFamilyLabel on TitoThemeFamily {
  String labelFor(Locale locale) {
    final chinese = locale.languageCode.toLowerCase() == 'zh';
    return switch ((this, chinese)) {
      (TitoThemeFamily.trainerJournal, true) => '训练家手帐',
      (TitoThemeFamily.trainerJournal, false) => "Trainer's Journal",
      (TitoThemeFamily.solidPlastic, true) => '固态塑料',
      (TitoThemeFamily.solidPlastic, false) => 'Solid Plastic',
      (TitoThemeFamily.flatUi, true) => '扁平贴纸',
      (TitoThemeFamily.flatUi, false) => 'Flat UI',
    };
  }
}

/// App-wide visual language. This is deliberately independent from motion
/// and surface-depth preferences so a theme switch does not reset either.
enum AppVisualStyle { classic, solidPlastic, flatUi }

extension AppVisualStyleLabel on AppVisualStyle {
  String get storageValue => switch (this) {
    AppVisualStyle.classic => 'classic',
    AppVisualStyle.solidPlastic => 'solid_plastic',
    AppVisualStyle.flatUi => 'flat_ui',
  };

  TitoThemeFamily get family => switch (this) {
    AppVisualStyle.classic => TitoThemeFamily.trainerJournal,
    AppVisualStyle.solidPlastic => TitoThemeFamily.solidPlastic,
    AppVisualStyle.flatUi => TitoThemeFamily.flatUi,
  };

  String labelFor(Locale locale) => family.labelFor(locale);
}

class AppVisualStylePreference extends ChangeNotifier {
  static const _styleKey = 'style.visual';

  // This experimental branch opens in Flat UI while keeping Trainer's Journal
  // one tap away. A future mainline merge can change this default without
  // migrating users who have already made an explicit choice.
  AppVisualStyle _style = AppVisualStyle.flatUi;
  bool _loaded = false;

  AppVisualStyle get style => _style;
  bool get usesTrainerJournal => _style == AppVisualStyle.classic;
  bool get usesSolidPlastic => _style == AppVisualStyle.solidPlastic;
  bool get usesFlatUi => _style == AppVisualStyle.flatUi;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_styleKey);
    // `material` was written by the first preview APK. Keep it as a one-way
    // compatibility alias after the visual language was named Flat UI.
    _style = saved == 'material'
        ? AppVisualStyle.flatUi
        : AppVisualStyle.values.firstWhere(
            (candidate) => candidate.storageValue == saved,
            orElse: () => AppVisualStyle.flatUi,
          );
    _loaded = true;
    notifyListeners();
  }

  Future<void> setStyle(AppVisualStyle style) async {
    if (_style == style) {
      return;
    }
    _style = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_styleKey, style.storageValue);
  }
}

final appVisualStyle = AppVisualStylePreference();
