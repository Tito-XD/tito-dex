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

  CompanionChoice? _choice;
  bool _loaded = false;

  CompanionChoice? get choice => _choice;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_idKey);
    final name = prefs.getString(_nameKey);
    _loaded = true;
    if (id != null && id > 0) {
      _choice = CompanionChoice(pokemonId: id, nameZh: name ?? '#$id');
      notifyListeners();
    }
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
