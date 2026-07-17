import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-chosen standby companion; falls back to the journey starter when null.
class CompanionChoice {
  const CompanionChoice({required this.pokemonId, required this.nameZh});

  final int pokemonId;
  final String nameZh;
}

/// Persists the standby companion selection (Settings → 同行宝可梦).
/// Only the id and display name are stored — the animated sprite itself is
/// fetched on demand, never bundled.
class CompanionRepository extends ChangeNotifier {
  static const _idKey = 'companion.pokemonId';
  static const _nameKey = 'companion.nameZh';
  static const _enabledKey = 'companion.enabled';
  static const _sizeScaleKey = 'companion.sizeScale';

  /// Slider bounds — 0.75 lets the companion shrink below the default,
  /// 1.5 is a hard ceiling per product decision. Default stays 1.0.
  static const double minSizeScale = 0.75;
  static const double maxSizeScale = 1.5;
  static const double defaultSizeScale = 1.0;

  CompanionChoice? _choice;
  bool _enabled = true;
  double _sizeScale = defaultSizeScale;
  bool _loaded = false;

  CompanionChoice? get choice => _choice;

  /// Whether the standby companion shows on the home dashboard (default on).
  bool get enabled => _enabled;

  /// User size multiplier applied on top of the height-based sprite size.
  double get sizeScale => _sizeScale;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_idKey);
    final name = prefs.getString(_nameKey);
    final enabled = prefs.getBool(_enabledKey) ?? true;
    final sizeScale = prefs.getDouble(_sizeScaleKey) ?? defaultSizeScale;
    _loaded = true;
    _enabled = enabled;
    _sizeScale = sizeScale.clamp(minSizeScale, maxSizeScale);
    if (id != null && id > 0) {
      _choice = CompanionChoice(pokemonId: id, nameZh: name ?? '#$id');
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<void> setSizeScale(double scale) async {
    _sizeScale = scale.clamp(minSizeScale, maxSizeScale);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_sizeScaleKey, _sizeScale);
  }

  Future<void> save(CompanionChoice choice) async {
    _choice = choice;
    _loaded = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_idKey, choice.pokemonId);
    await prefs.setString(_nameKey, choice.nameZh);
  }

  Future<void> clear() async {
    _choice = null;
    _loaded = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_idKey);
    await prefs.remove(_nameKey);
  }
}

final companionRepository = CompanionRepository();
