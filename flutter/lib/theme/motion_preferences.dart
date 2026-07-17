import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global toggle for the small list-reveal animations (Settings → 界面动画).
/// Default on; when off, list items render instantly.
class MotionPreferences extends ChangeNotifier {
  static const _listAnimationsKey = 'motion.listAnimations';

  bool _listAnimationsEnabled = true;
  bool _loaded = false;

  bool get listAnimationsEnabled => _listAnimationsEnabled;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _loaded = true;
    _listAnimationsEnabled = prefs.getBool(_listAnimationsKey) ?? true;
    notifyListeners();
  }

  Future<void> setListAnimationsEnabled(bool enabled) async {
    _listAnimationsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_listAnimationsKey, enabled);
  }
}

final motionPreferences = MotionPreferences();
