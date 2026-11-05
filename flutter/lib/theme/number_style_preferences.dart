import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Experimental glyph styles for the hero numbers (Settings → 数字样式).
enum TitoNumberStyle { standard, segment, dotMatrix, pixel, splitFlap }

/// App-wide choice of [TitoNumberStyle]. Only `TitoAnimatedNumber(retro: true)`
/// reads it; every other number keeps the normal font.
class NumberStylePreferences extends ChangeNotifier {
  static const _styleKey = 'appearance.numberStyle';

  TitoNumberStyle _style = TitoNumberStyle.standard;
  bool _loaded = false;

  TitoNumberStyle get style => _style;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _loaded = true;
    final saved = prefs.getString(_styleKey);
    _style = TitoNumberStyle.values.firstWhere(
      (candidate) => candidate.name == saved,
      orElse: () => TitoNumberStyle.standard,
    );
    notifyListeners();
  }

  Future<void> setStyle(TitoNumberStyle style) async {
    if (_style == style) {
      return;
    }
    _style = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_styleKey, style.name);
  }

  /// Forgets the loaded state so tests can reload from mock preferences.
  @visibleForTesting
  void debugReset() {
    _style = TitoNumberStyle.standard;
    _loaded = false;
  }
}

final numberStylePreferences = NumberStylePreferences();
