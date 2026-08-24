import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted surface-depth preference.
///
/// The Flat UI experiment keeps the historical storage key for upgrade
/// compatibility: enabled selects elevated cards, disabled selects outlined
/// cards. Native Material state layers remain active in both modes.
class RetroStyle extends ChangeNotifier {
  static const _enabledKey = 'style.retro';

  bool _enabled = true;
  bool _loaded = false;

  bool get enabled => _enabled;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _loaded = true;
    _enabled = prefs.getBool(_enabledKey) ?? true;
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }
}

final retroStyle = RetroStyle();
