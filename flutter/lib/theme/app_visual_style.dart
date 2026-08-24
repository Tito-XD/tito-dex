import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide visual language. This is deliberately independent from motion
/// and surface-depth preferences so a theme switch does not reset either.
enum AppVisualStyle { classic, material }

extension AppVisualStyleLabel on AppVisualStyle {
  String get storageValue => switch (this) {
    AppVisualStyle.classic => 'classic',
    AppVisualStyle.material => 'material',
  };

  String get labelZh => switch (this) {
    AppVisualStyle.classic => 'TitoDex 经典',
    AppVisualStyle.material => 'Material 3',
  };
}

class AppVisualStylePreference extends ChangeNotifier {
  static const _styleKey = 'style.visual';

  // This experimental branch opens in Material while keeping Classic one tap
  // away. A future mainline merge can change this default without migrating
  // users who have already made an explicit choice.
  AppVisualStyle _style = AppVisualStyle.material;
  bool _loaded = false;

  AppVisualStyle get style => _style;
  bool get usesMaterial => _style == AppVisualStyle.material;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_styleKey);
    _style = AppVisualStyle.values.firstWhere(
      (candidate) => candidate.storageValue == saved,
      orElse: () => AppVisualStyle.material,
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
