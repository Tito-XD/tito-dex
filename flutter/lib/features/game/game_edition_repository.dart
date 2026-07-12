import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_edition.dart';

const _globalGameEditionKey = 'titodex.global_game_edition';

class GameEditionRepository extends ChangeNotifier {
  GameEdition _edition = defaultGameEdition;
  bool _loaded = false;

  GameEdition get edition => _edition;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final slug = prefs.getString(_globalGameEditionKey);
    _edition = gameEditionFromSlug(slug) ?? defaultGameEdition;
    _loaded = true;
    notifyListeners();
  }

  Future<GameEdition> loadEdition() async {
    if (!_loaded) {
      await load();
    }
    return _edition;
  }

  Future<void> save(GameEdition edition) async {
    _edition = edition;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_globalGameEditionKey, edition.slug);
    notifyListeners();
  }

  Future<void> saveSlug(String slug) async {
    final edition = gameEditionFromSlug(slug) ?? defaultGameEdition;
    await save(edition);
  }
}

final gameEditionRepository = GameEditionRepository();
